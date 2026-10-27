import { syncQueueRepository, SyncQueueRepository, SyncQueueStatus } from '../repositories/syncQueueRepository.js';
import { eventRepository, EventRepository } from '../repositories/eventRepository.js';
import { guestRepository, GuestRepository } from '../repositories/guestRepository.js';
import { machinenovaClient, MachineNovaClient } from '../clients/machinenovaClient.js';
import { config } from '../config/env.js';

export interface ProcessQueueResult {
  processed: number;
  succeeded: number;
  failed: number;
}

export class SyncService {
  private timer: NodeJS.Timeout | null = null;
  private isProcessing = false;

  constructor(
    private queueRepo: SyncQueueRepository = syncQueueRepository,
    private eventRepo: EventRepository = eventRepository,
    private guestRepo: GuestRepository = guestRepository,
    private client: MachineNovaClient = machinenovaClient
  ) {}

  public startBackgroundSync(): void {
    if (!config.enableAutoSync) return;
    if (this.timer) return;

    this.timer = setInterval(async () => {
      await this.processQueue();
    }, config.syncIntervalMs);

    console.log(`[SYNC] Offline sync worker started (Interval: ${config.syncIntervalMs}ms)`);
  }

  public stopBackgroundSync(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  public async getQueueStatus(): Promise<SyncQueueStatus> {
    return this.queueRepo.getQueueStatus();
  }

  public async processQueue(): Promise<ProcessQueueResult> {
    if (this.isProcessing) return { processed: 0, succeeded: 0, failed: 0 };
    if (!this.client.isConfigured()) return { processed: 0, succeeded: 0, failed: 0 };

    this.isProcessing = true;
    let processed = 0;
    let succeeded = 0;
    let failed = 0;

    try {
      const items = await this.queueRepo.findPendingAndRetriable(20);

      for (const item of items) {
        processed++;
        await this.queueRepo.markProcessing(item.id);

        try {
          const payload = typeof item.payload === 'string' ? JSON.parse(item.payload) : item.payload;
          await this.executeAction(item.action, payload);
          await this.queueRepo.markCompleted(item.id);
          succeeded++;
        } catch (err: any) {
          failed++;
          console.error(`[SYNC] Job ${item.id} execution failed:`, err.message);
          await this.queueRepo.markFailed(item.id, err.message);
        }
      }
    } finally {
      this.isProcessing = false;
    }

    return { processed, succeeded, failed };
  }

  private async executeAction(action: string, payload: any): Promise<void> {
    switch (action) {
      case 'CREATE_EVENT': {
        const mnEvent = await this.client.createEvent({
          eventName: payload.input.name,
          geoNode: payload.input.geoNode,
          eventStartDate: payload.input.date,
          restrictToJurisdiction: payload.input.restrictToJurisdiction,
          restrictToRoster: payload.input.restrictToRoster,
        });

        await this.eventRepo.update(payload.id, { machinenovaEventId: mnEvent.name } as any, 'synced');
        break;
      }

      case 'UPDATE_EVENT': {
        await this.client.updateEvent({
          eventId: payload.machinenovaEventId,
          eventName: payload.input.name,
          isActive: payload.input.status ? payload.input.status !== 'past' : undefined,
          restrictToJurisdiction: payload.input.restrictToJurisdiction,
          restrictToRoster: payload.input.restrictToRoster,
        });

        await this.eventRepo.update(payload.id, {}, 'synced');
        break;
      }

      case 'DELETE_EVENT': {
        await this.client.deleteEvent(payload.machinenovaEventId);
        break;
      }

      case 'CHECKIN': {
        await this.client.checkin({
          event: payload.machinenovaEventId,
          idNumber: payload.passId,
          fullName: payload.fullName,
          phone: payload.phone,
        });

        await this.guestRepo.updateSyncStatusByPassId(payload.passId, 'synced');
        break;
      }

      default:
        console.warn(`[SYNC] Unknown sync action: ${action}`);
    }
  }
}

export const syncService = new SyncService();
