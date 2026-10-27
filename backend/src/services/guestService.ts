import { guestRepository, GuestRepository, GuestFilterOptions, AddGuestParams, GuestStats } from '../repositories/guestRepository.js';
import { eventRepository, EventRepository } from '../repositories/eventRepository.js';
import { EntreeGuest } from '../types/guest.js';
import { NotFoundError } from '../errors/index.js';

export class GuestService {
  constructor(
    private guestRepo: GuestRepository = guestRepository,
    private eventRepo: EventRepository = eventRepository
  ) {}

  public async listGuestsByEvent(
    eventId: string,
    options?: GuestFilterOptions
  ): Promise<EntreeGuest[]> {
    return this.guestRepo.findByEventId(eventId, options);
  }

  public async getGuestByPassId(eventId: string, passId: string): Promise<EntreeGuest | null> {
    return this.guestRepo.findByPassId(eventId, passId);
  }

  public async addGuest(eventId: string, guest: AddGuestParams): Promise<EntreeGuest> {
    const event = await this.eventRepo.findById(eventId);
    if (!event) {
      throw new NotFoundError(`Event with id '${eventId}' not found`);
    }

    const created = await this.guestRepo.create(eventId, guest);
    await this.eventRepo.incrementPassesIssued(eventId, 1);
    return created;
  }

  public async getEventGuestStats(eventId: string): Promise<GuestStats> {
    const event = await this.eventRepo.findById(eventId);
    if (!event) {
      throw new NotFoundError(`Event with id '${eventId}' not found`);
    }
    return this.guestRepo.getEventGuestStats(eventId);
  }
}

export const guestService = new GuestService();
