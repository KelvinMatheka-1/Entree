import { eventRepository, EventRepository } from '../repositories/eventRepository.js';
import { guestRepository, GuestRepository } from '../repositories/guestRepository.js';
import { scanLogRepository, ScanLogRepository } from '../repositories/scanLogRepository.js';
import { syncQueueRepository, SyncQueueRepository } from '../repositories/syncQueueRepository.js';
import { machinenovaClient, MachineNovaClient } from '../clients/machinenovaClient.js';
import { CheckInRequest, ScanVerificationResult, EntreeGuest } from '../types/guest.js';
import { NotFoundError } from '../errors/index.js';

export class ScanService {
  constructor(
    private eventRepo: EventRepository = eventRepository,
    private guestRepo: GuestRepository = guestRepository,
    private scanLogRepo: ScanLogRepository = scanLogRepository,
    private queueRepo: SyncQueueRepository = syncQueueRepository,
    private client: MachineNovaClient = machinenovaClient
  ) {}

  public async verifyScan(eventId: string, passId: string): Promise<ScanVerificationResult> {
    const event = await this.eventRepo.findByIdOrMachineNovaId(eventId);
    if (!event) {
      return {
        canCheckIn: false,
        status: 'invalid_pass',
        message: 'Event not found',
      };
    }

    if (event.machinenovaEventId && this.client.isConfigured()) {
      try {
        const mnResult = await this.client.scanForCheckin(event.machinenovaEventId, passId);

        if (mnResult.status === 'already_checked_in') {
          return {
            canCheckIn: false,
            status: 'already_checked_in',
            message: mnResult.message || 'Participant already checked in today.',
            serverCheckinTime: mnResult.participant?.checkin_time,
          };
        }

        if (mnResult.status === 'not_on_roster') {
          return {
            canCheckIn: false,
            status: 'not_on_roster',
            message: mnResult.message || 'This ID is not on the participant list for this event.',
          };
        }

        if (mnResult.status === 'ready') {
          return {
            canCheckIn: true,
            status: 'ready',
            message: mnResult.outside_jurisdiction
              ? 'Ready to check in (Outside event jurisdiction)'
              : 'Ready to check in',
            outsideJurisdiction: Boolean(mnResult.outside_jurisdiction),
            guest: mnResult.participant
              ? {
                  id: `mn-${mnResult.participant.id_number}`,
                  eventId: event.id,
                  passId: mnResult.participant.id_number,
                  fullName: mnResult.participant.full_name,
                  email: '',
                  tableNumber: '01',
                  tableName: 'MachineNova Hall',
                  status: 'notArrived',
                  admission: 'Voter Pass',
                  guestCount: 1,
                  county: mnResult.participant.county,
                  constituency: mnResult.participant.constituency,
                  ward: mnResult.participant.ward,
                  pollingCenter: mnResult.participant.polling_center,
                  isOutsideJurisdiction: mnResult.outside_jurisdiction,
                }
              : undefined,
          };
        }
      } catch (err: any) {
        console.warn('[SCAN_SERVICE] MachineNova scan endpoint unavailable, falling back to local database:', err.message);
      }
    }

    const localGuest = await this.guestRepo.findByPassId(event.id, passId);

    if (localGuest) {
      if (localGuest.status === 'checkedIn') {
        return {
          canCheckIn: false,
          status: 'already_checked_in',
          message: `Already checked in at ${localGuest.checkInTime || 'an earlier time'}.`,
          guest: localGuest,
        };
      }

      return {
        canCheckIn: true,
        status: 'ready',
        message: 'Valid Pass. Ready for Check-in',
        guest: localGuest,
      };
    }

    if (event.restrictToRoster) {
      return {
        canCheckIn: false,
        status: 'not_on_roster',
        message: 'Pass ID is not on the invited guest roster for this event.',
      };
    }

    return {
      canCheckIn: true,
      status: 'ready',
      message: 'Unregistered pass allowed. Ready to check-in as attendee.',
    };
  }

  public async checkIn(request: CheckInRequest): Promise<{
    success: boolean;
    guest: EntreeGuest;
    message: string;
  }> {
    const event = await this.eventRepo.findByIdOrMachineNovaId(request.eventId);
    if (!event) {
      throw new NotFoundError(`Event with id '${request.eventId}' not found`);
    }

    let guest = await this.guestRepo.findByPassId(event.id, request.passId);

    const now = new Date();
    const timeFormatted = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;

    if (!guest) {
      guest = await this.guestRepo.create(event.id, {
        passId: request.passId,
        fullName: request.fullName || `Attendee #${request.passId}`,
        tableNumber: request.tableNumber || '01',
        tableName: request.tableName || 'Open Seating',
        phone: request.phone,
        county: request.county,
        constituency: request.constituency,
        ward: request.ward,
        pollingCenter: request.pollingCenter,
      });
      await this.eventRepo.incrementPassesIssued(event.id, 1);
    }

    if (guest.status === 'checkedIn') {
      return {
        success: false,
        guest,
        message: `Already checked in at ${guest.checkInTime}`,
      };
    }

    let syncStatus = 'synced';

    if (event.machinenovaEventId && this.client.isConfigured()) {
      try {
        await this.client.checkin({
          event: event.machinenovaEventId,
          idNumber: request.passId,
          fullName: guest.fullName,
          phone: guest.phone,
          county: guest.county || request.county,
          constituency: guest.constituency || request.constituency,
          ward: guest.ward || request.ward,
          pollingCenter: guest.pollingCenter || request.pollingCenter,
        });
      } catch (err: any) {
        console.warn('[SCAN_SERVICE] Failed to push check-in upstream, queuing for sync:', err.message);
        syncStatus = 'pending_checkin';
        await this.queueRepo.enqueue('CHECKIN', {
          machinenovaEventId: event.machinenovaEventId,
          passId: request.passId,
          fullName: guest.fullName,
          phone: guest.phone,
          checkInTime: timeFormatted,
        });
      }
    }

    await this.guestRepo.updateCheckInStatus(guest.id, timeFormatted, syncStatus);
    await this.eventRepo.incrementCheckedIn(event.id, 1);

    await this.scanLogRepo.createLog({
      eventId: event.id,
      passId: request.passId,
      status: 'CHECKED_IN',
      operatorId: request.operatorId || 'default-operator',
      details: `Checked in at ${timeFormatted}`,
    });

    const updatedGuest = (await this.guestRepo.findByPassId(event.id, request.passId))!;

    return {
      success: true,
      guest: updatedGuest,
      message: `Successfully checked in ${updatedGuest.fullName}`,
    };
  }

  public async undoCheckIn(eventId: string, passId: string): Promise<boolean> {
    const event = await this.eventRepo.findByIdOrMachineNovaId(eventId);
    if (!event) {
      throw new NotFoundError(`Event with id '${eventId}' not found`);
    }

    const guest = await this.guestRepo.findByPassId(event.id, passId);
    if (!guest || guest.status !== 'checkedIn') {
      return false;
    }

    await this.guestRepo.updateCheckInStatus(guest.id, null, 'synced');
    await this.eventRepo.decrementCheckedIn(event.id, 1);

    await this.scanLogRepo.createLog({
      eventId: event.id,
      passId,
      status: 'CHECKIN_CANCELLED',
      details: 'Check-in reverted',
    });

    return true;
  }
}

export const scanService = new ScanService();
