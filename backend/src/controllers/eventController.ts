import { Request, Response } from 'express';
import { eventService } from '../services/eventService.js';
import { guestService } from '../services/guestService.js';
import { machinenovaClient } from '../clients/machinenovaClient.js';

export class EventController {
  public async listEvents(req: Request, res: Response): Promise<void> {
    try {
      const status = req.query.status as string | undefined;
      const search = req.query.search as string | undefined;
      const refresh = req.query.refresh === 'true';

      const events = await eventService.listEvents({
        status,
        search,
        refreshFromMachineNova: refresh,
      });

      res.json({
        success: true,
        count: events.length,
        events,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }

  public async getEventById(req: Request, res: Response): Promise<void> {
    try {
      const id = String(req.params.id);
      const event = await eventService.getEventById(id);

      if (!event) {
        res.status(404).json({
          success: false,
          message: 'Event not found',
        });
        return;
      }

      res.json({
        success: true,
        event,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }

  public async createEvent(req: Request, res: Response): Promise<void> {
    try {
      const {
        name,
        venue,
        venueAddress,
        collection,
        description,
        date,
        startTime,
        endTime,
        doorsOpenTime,
        tables,
        seatsPerTable,
        totalCapacity,
        passesIssued,
        status,
        imageUrl,
        isPaid,
        priceBadge,
        city,
        restrictToJurisdiction,
        restrictToRoster,
        geoNode,
      } = req.body;

      if (!name || !date) {
        res.status(400).json({
          success: false,
          message: 'Event name and date are required.',
        });
        return;
      }

      const created = await eventService.createEvent({
        name,
        venue,
        venueAddress,
        collection,
        description,
        date,
        startTime,
        endTime,
        doorsOpenTime,
        tables,
        seatsPerTable,
        totalCapacity,
        passesIssued,
        status,
        imageUrl,
        isPaid,
        priceBadge,
        city,
        restrictToJurisdiction,
        restrictToRoster,
        geoNode,
      });

      res.status(201).json({
        success: true,
        event: created,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }

  public async updateEvent(req: Request, res: Response): Promise<void> {
    try {
      const id = String(req.params.id);
      const updated = await eventService.updateEvent(id, req.body);

      if (!updated) {
        res.status(404).json({
          success: false,
          message: 'Event not found',
        });
        return;
      }

      res.json({
        success: true,
        event: updated,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }

  public async deleteEvent(req: Request, res: Response): Promise<void> {
    try {
      const id = String(req.params.id);
      const success = await eventService.deleteEvent(id);

      if (!success) {
        res.status(404).json({
          success: false,
          message: 'Event not found or already deleted',
        });
        return;
      }

      res.json({
        success: true,
        message: 'Event deleted successfully',
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }

  public async getEventStats(req: Request, res: Response): Promise<void> {
    try {
      const id = String(req.params.id);
      const event = await eventService.getEventById(id);
      if (!event) {
        res.status(404).json({ success: false, message: 'Event not found' });
        return;
      }

      const localStats = await guestService.getEventGuestStats(event.id);

      let upstreamStats: any = null;
      if (event.machinenovaEventId && machinenovaClient.isConfigured()) {
        try {
          upstreamStats = await machinenovaClient.getEventStatistics(event.machinenovaEventId);
        } catch (e: any) {
          console.warn('MachineNova event stats call failed:', e.message);
        }
      }

      res.json({
        success: true,
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
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }
}

export const eventController = new EventController();
