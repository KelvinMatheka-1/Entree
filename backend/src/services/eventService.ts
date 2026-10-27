import { v4 as uuidv4 } from 'uuid';
import { eventRepository, EventRepository, EventFilterOptions } from '../repositories/eventRepository.js';
import { syncQueueRepository, SyncQueueRepository } from '../repositories/syncQueueRepository.js';
import { machinenovaClient, MachineNovaClient } from '../clients/machinenovaClient.js';
import { EntreeEvent, CreateEventInput, UpdateEventInput } from '../types/event.js';
import { NotFoundError } from '../errors/index.js';

export class EventService {
  constructor(
    private eventRepo: EventRepository = eventRepository,
    private queueRepo: SyncQueueRepository = syncQueueRepository,
    private client: MachineNovaClient = machinenovaClient
  ) {}

  public async listEvents(options?: EventFilterOptions & { refreshFromMachineNova?: boolean }): Promise<EntreeEvent[]> {
    if (options?.refreshFromMachineNova && this.client.isConfigured()) {
      try {
        await this.syncEventsFromMachineNova();
      } catch (err: any) {
        console.warn('[EVENT_SERVICE] MachineNova event sync skipped or failed:', err.message);
      }
    }

    return this.eventRepo.findAll(options);
  }

  public async getEventById(id: string): Promise<EntreeEvent | null> {
    return this.eventRepo.findByIdOrMachineNovaId(id);
  }

  public async createEvent(input: CreateEventInput): Promise<EntreeEvent> {
    const id = `evt-${uuidv4().substring(0, 8)}`;
    let machinenovaEventId: string | undefined;
    let syncStatus: 'synced' | 'pending_create' | 'local_only' = 'local_only';

    if (this.client.isConfigured()) {
      try {
        const mnEvent = await this.client.createEvent({
          eventName: input.name,
          geoNode: input.geoNode,
          eventStartDate: input.date,
          restrictToJurisdiction: input.restrictToJurisdiction,
          restrictToRoster: input.restrictToRoster,
        });
        machinenovaEventId = mnEvent.name;
        syncStatus = 'synced';
      } catch (err: any) {
        console.warn('[EVENT_SERVICE] Failed to create event upstream, queuing for offline sync:', err.message);
        syncStatus = 'pending_create';
        await this.queueRepo.enqueue('CREATE_EVENT', { id, input });
      }
    }

    return this.eventRepo.create(id, input, machinenovaEventId, syncStatus);
  }

  public async updateEvent(id: string, input: UpdateEventInput): Promise<EntreeEvent | null> {
    const existing = await this.eventRepo.findByIdOrMachineNovaId(id);
    if (!existing) {
      throw new NotFoundError(`Event with id '${id}' not found`);
    }

    let syncStatus = existing.syncStatus;
    if (existing.machinenovaEventId && this.client.isConfigured()) {
      try {
        await this.client.updateEvent({
          eventId: existing.machinenovaEventId,
          eventName: input.name,
          isActive: input.status ? input.status !== 'past' : undefined,
          restrictToJurisdiction: input.restrictToJurisdiction,
          restrictToRoster: input.restrictToRoster,
        });
        syncStatus = 'synced';
      } catch (err: any) {
        console.warn('[EVENT_SERVICE] MachineNova update event failed, queuing:', err.message);
        syncStatus = 'pending_update';
        await this.queueRepo.enqueue('UPDATE_EVENT', {
          id: existing.id,
          machinenovaEventId: existing.machinenovaEventId,
          input,
        });
      }
    }

    return this.eventRepo.update(existing.id, input, syncStatus);
  }

  public async deleteEvent(id: string): Promise<boolean> {
    const existing = await this.eventRepo.findByIdOrMachineNovaId(id);
    if (!existing) {
      throw new NotFoundError(`Event with id '${id}' not found`);
    }

    if (existing.machinenovaEventId && this.client.isConfigured()) {
      try {
        await this.client.deleteEvent(existing.machinenovaEventId);
      } catch (err: any) {
        console.warn('[EVENT_SERVICE] MachineNova delete event failed, queuing:', err.message);
        await this.queueRepo.enqueue('DELETE_EVENT', {
          id: existing.id,
          machinenovaEventId: existing.machinenovaEventId,
        });
      }
    }

    return this.eventRepo.delete(existing.id);
  }

  public async syncEventsFromMachineNova(): Promise<number> {
    const { events } = await this.client.listEvents({ limit: 200 });
    return this.eventRepo.upsertMachineNovaBatch(events);
  }
}

export const eventService = new EventService();
