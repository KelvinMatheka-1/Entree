import { Request, Response } from 'express';
import { eventService as defaultEventService, EventService } from '../services/eventService.js';
import { guestService as defaultGuestService, GuestService } from '../services/guestService.js';
import { machinenovaClient, MachineNovaClient } from '../clients/machinenovaClient.js';
import { asyncHandler } from '../common/asyncHandler.js';
import { ApiResponse } from '../common/apiResponse.js';
import { NotFoundError } from '../errors/index.js';

export class EventController {
  constructor(
    private eventService: EventService = defaultEventService,
    private guestService: GuestService = defaultGuestService,
    private client: MachineNovaClient = machinenovaClient
  ) {}

  public listEvents = asyncHandler(async (req: Request, res: Response) => {
    const status = req.query.status as string | undefined;
    const search = req.query.search as string | undefined;
    const refresh = req.query.refresh === 'true';

    const events = await this.eventService.listEvents({
      status,
      search,
      refreshFromMachineNova: refresh,
    });

    ApiResponse.success(res, { events }, { count: events.length });
  });

  public getEventById = asyncHandler(async (req: Request, res: Response) => {
    const id = String(req.params.id);
    const event = await this.eventService.getEventById(id);

    if (!event) {
      throw new NotFoundError(`Event with id '${id}' not found`);
    }

    ApiResponse.success(res, { event });
  });

  public createEvent = asyncHandler(async (req: Request, res: Response) => {
    const created = await this.eventService.createEvent(req.body);
    ApiResponse.created(res, { event: created });
  });

  public updateEvent = asyncHandler(async (req: Request, res: Response) => {
    const id = String(req.params.id);
    const updated = await this.eventService.updateEvent(id, req.body);

    if (!updated) {
      throw new NotFoundError(`Event with id '${id}' not found`);
    }

    ApiResponse.success(res, { event: updated });
  });

  public deleteEvent = asyncHandler(async (req: Request, res: Response) => {
    const id = String(req.params.id);
    const success = await this.eventService.deleteEvent(id);

    if (!success) {
      throw new NotFoundError(`Event with id '${id}' not found or already deleted`);
    }

    ApiResponse.success(res, {}, { message: 'Event deleted successfully' });
  });

  public getEventStats = asyncHandler(async (req: Request, res: Response) => {
    const id = String(req.params.id);
    const event = await this.eventService.getEventById(id);
    if (!event) {
      throw new NotFoundError(`Event with id '${id}' not found`);
    }

    const localStats = await this.guestService.getEventGuestStats(event.id);

    let upstreamStats: any = null;
    if (event.machinenovaEventId && this.client.isConfigured()) {
      try {
        upstreamStats = await this.client.getEventStatistics(event.machinenovaEventId);
      } catch (e: any) {
        console.warn('[EVENT_CONTROLLER] MachineNova event stats call failed:', e.message);
      }
    }

    ApiResponse.success(res, {
      event: {
        id: event.id,
        name: event.name,
        passesIssued: event.passesIssued,
        checkedIn: event.checkedIn,
        totalCapacity: event.totalCapacity,
      },
      stats: {
        ...localStats,
        upstream: upstreamStats,
      },
    });
  });
}

export const eventController = new EventController();
