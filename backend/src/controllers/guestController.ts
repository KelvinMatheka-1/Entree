import { Request, Response } from 'express';
import { guestService } from '../services/guestService.js';
import { eventService } from '../services/eventService.js';

export class GuestController {
  public async listGuests(req: Request, res: Response): Promise<void> {
    try {
      const eventId = String(req.params.eventId);
      const status = req.query.status as string | undefined;
      const search = req.query.search as string | undefined;

      const guests = await guestService.listGuestsByEvent(eventId, {
        status,
        search,
      });

      res.json({
        success: true,
        count: guests.length,
        guests,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }

  public async addGuest(req: Request, res: Response): Promise<void> {
    try {
      const eventId = String(req.params.eventId);
      const {
        fullName,
        email,
        phone,
        passId,
        tableNumber,
        tableName,
        admission,
        county,
        constituency,
        ward,
        pollingCenter,
      } = req.body;

      if (!fullName) {
        res.status(400).json({
          success: false,
          message: 'Full name is required.',
        });
        return;
      }

      const event = await eventService.getEventById(eventId);
      if (!event) {
        res.status(404).json({
          success: false,
          message: 'Event not found',
        });
        return;
      }

      const guest = await guestService.addGuest(eventId, {
        fullName,
        email,
        phone,
        passId,
        tableNumber,
        tableName,
        admission,
        county,
        constituency,
        ward,
        pollingCenter,
      });

      res.status(201).json({
        success: true,
        guest,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }

  public async getGuestStats(req: Request, res: Response): Promise<void> {
    try {
      const eventId = String(req.params.eventId);
      const stats = await guestService.getEventGuestStats(eventId);

      res.json({
        success: true,
        stats,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }
}

export const guestController = new GuestController();
