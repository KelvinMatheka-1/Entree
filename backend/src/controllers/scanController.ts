import { Request, Response } from 'express';
import { scanService } from '../services/scanService.js';

export class ScanController {
  public async verifyScan(req: Request, res: Response): Promise<void> {
    try {
      const eventId = String(req.params.eventId);
      const passId = (req.query.passId as string) || (req.query.id_number as string);

      if (!passId) {
        res.status(400).json({
          success: false,
          message: 'passId (or id_number) query parameter is required',
        });
        return;
      }

      const result = await scanService.verifyScan(eventId, passId.trim());

      res.json({
        success: true,
        verification: result,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }

  public async checkIn(req: Request, res: Response): Promise<void> {
    try {
      const eventId = String(req.params.eventId);
      const {
        passId,
        operatorId,
        fullName,
        phone,
        tableNumber,
        tableName,
        county,
        constituency,
        ward,
        pollingCenter,
      } = req.body;

      if (!passId) {
        res.status(400).json({
          success: false,
          message: 'passId is required to execute check-in',
        });
        return;
      }

      const result = await scanService.checkIn({
        eventId,
        passId: passId.trim(),
        operatorId,
        fullName,
        phone,
        tableNumber,
        tableName,
        county,
        constituency,
        ward,
        pollingCenter,
      });

      res.json({
        success: result.success,
        message: result.message,
        guest: result.guest,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }

  public async undoCheckIn(req: Request, res: Response): Promise<void> {
    try {
      const eventId = String(req.params.eventId);
      const { passId } = req.body;

      if (!passId) {
        res.status(400).json({
          success: false,
          message: 'passId is required to undo check-in',
        });
        return;
      }

      const success = await scanService.undoCheckIn(eventId, passId.trim());

      res.json({
        success,
        message: success ? 'Check-in reverted successfully' : 'Could not revert check-in',
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }
}

export const scanController = new ScanController();
