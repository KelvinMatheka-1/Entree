import { Request, Response } from 'express';
import { guestService as defaultGuestService, GuestService } from '../services/guestService.js';
import { asyncHandler } from '../common/asyncHandler.js';
import { ApiResponse } from '../common/apiResponse.js';

export class GuestController {
  constructor(private guestService: GuestService = defaultGuestService) {}

  public listGuests = asyncHandler(async (req: Request, res: Response) => {
    const eventId = String(req.params.eventId);
    const status = req.query.status as string | undefined;
    const search = req.query.search as string | undefined;

    const guests = await this.guestService.listGuestsByEvent(eventId, {
      status,
      search,
    });

    ApiResponse.success(res, { guests }, { count: guests.length });
  });

  public addGuest = asyncHandler(async (req: Request, res: Response) => {
    const eventId = String(req.params.eventId);
    const guest = await this.guestService.addGuest(eventId, req.body);
    ApiResponse.created(res, { guest });
  });

  public getGuestStats = asyncHandler(async (req: Request, res: Response) => {
    const eventId = String(req.params.eventId);
    const stats = await this.guestService.getEventGuestStats(eventId);
    ApiResponse.success(res, { stats });
  });
}

export const guestController = new GuestController();
