import { v4 as uuidv4 } from 'uuid';
import { query } from '../db/database.js';
import { machinenovaClient } from '../clients/machinenovaClient.js';
import { guestService } from './guestService.js';
import { eventService } from './eventService.js';
import { CheckInRequest, ScanVerificationResult, EntreeGuest } from '../types/guest.js';

export class ScanService {
  public async verifyScan(eventId: string, passId: string): Promise<ScanVerificationResult> {
    const event = await eventService.getEventById(eventId);
    if (!event) {
      return {
        canCheckIn: false,
        status: 'invalid_pass',
        message: 'Event not found',
      };
    }

    if (event.machinenovaEventId && machinenovaClient.isConfigured()) {
      try {
        const mnResult = await machinenovaClient.scanForCheckin(event.machinenovaEventId, passId);

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

    const localGuest = await guestService.getGuestByPassId(event.id, passId);

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
    const event = await eventService.getEventById(request.eventId);
    if (!event) {
      throw new Error('Event not found');
    }

    let guest = await guestService.getGuestByPassId(request.eventId, request.passId);

    const now = new Date();
    const timeFormatted = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;

    if (!guest) {
      guest = await guestService.addGuest(request.eventId, {
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
    }

    if (guest.status === 'checkedIn') {
      return {
        success: false,
        guest,
        message: `Already checked in at ${guest.checkInTime}`,
      };
    }

    let syncStatus = 'synced';

    if (event.machinenovaEventId && machinenovaClient.isConfigured()) {
      try {
        await machinenovaClient.checkin({
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
        await this.queueSyncAction('CHECKIN', {
          machinenovaEventId: event.machinenovaEventId,
          passId: request.passId,
          fullName: guest.fullName,
          phone: guest.phone,
          checkInTime: timeFormatted,
        });
      }
    }

    await query(
      `UPDATE guests SET
        status = 'checkedIn',
        check_in_time = $1,
        sync_status = $2,
        last_synced_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $3`,
      [timeFormatted, syncStatus, guest.id]
    );

    await query(
      `UPDATE events SET
        checked_in = checked_in + 1,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $1`,
      [request.eventId]
    );

    await query(
      `INSERT INTO scan_logs (id, event_id, pass_id, status, operator_id, details)
       VALUES ($1, $2, $3, 'CHECKED_IN', $4, $5)`,
      [
        uuidv4(),
        request.eventId,
        request.passId,
        request.operatorId || 'default-operator',
        `Checked in at ${timeFormatted}`,
      ]
    );

    const updatedGuest = (await guestService.getGuestByPassId(request.eventId, request.passId))!;

    return {
      success: true,
      guest: updatedGuest,
      message: `Successfully checked in ${updatedGuest.fullName}`,
    };
  }

  public async undoCheckIn(eventId: string, passId: string): Promise<boolean> {
    const guest = await guestService.getGuestByPassId(eventId, passId);
    if (!guest || guest.status !== 'checkedIn') {
      return false;
    }

    await query(
      `UPDATE guests SET
        status = 'notArrived',
        check_in_time = NULL,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $1`,
      [guest.id]
    );

    await query(
      `UPDATE events SET
        checked_in = GREATEST(0, checked_in - 1),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $1`,
      [eventId]
    );

    await query(
      `INSERT INTO scan_logs (id, event_id, pass_id, status, details)
       VALUES ($1, $2, $3, 'CHECKIN_CANCELLED', 'Check-in reverted')`,
      [uuidv4(), eventId, passId]
    );

    return true;
  }

  private async queueSyncAction(action: string, payload: any): Promise<void> {
    await query(
      `INSERT INTO sync_queue (id, action, payload, status)
       VALUES ($1, $2, $3, 'pending')`,
      [uuidv4(), action, payload]
    );
  }
}

export const scanService = new ScanService();
