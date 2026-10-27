import { Request, Response } from 'express';
import { scanService as defaultScanService, ScanService } from '../services/scanService.js';
import { asyncHandler } from '../common/asyncHandler.js';
import { ApiResponse } from '../common/apiResponse.js';
import { BadRequestError } from '../errors/index.js';

export class ScanController {
  constructor(private scanService: ScanService = defaultScanService) {}

  public verifyScan = asyncHandler(async (req: Request, res: Response) => {
    const eventId = String(req.params.eventId);
    const passId = (req.query.passId as string) || (req.query.id_number as string);

    if (!passId) {
      throw new BadRequestError('passId (or id_number) query parameter is required');
    }

    const result = await this.scanService.verifyScan(eventId, passId.trim());
    ApiResponse.success(res, { verification: result });
  });

  public checkIn = asyncHandler(async (req: Request, res: Response) => {
    const eventId = String(req.params.eventId);
    const passId = req.body.passId;

    if (!passId) {
      throw new BadRequestError('passId is required to execute check-in');
    }

    const result = await this.scanService.checkIn({
      ...req.body,
      eventId,
      passId: passId.trim(),
    });

    ApiResponse.success(
      res,
      {
        success: result.success,
        guest: result.guest,
      },
      { message: result.message }
    );
  });

  public undoCheckIn = asyncHandler(async (req: Request, res: Response) => {
    const eventId = String(req.params.eventId);
    const passId = req.body.passId;

    if (!passId) {
      throw new BadRequestError('passId is required to undo check-in');
    }

    const success = await this.scanService.undoCheckIn(eventId, passId.trim());

    ApiResponse.success(
      res,
      {},
      { message: success ? 'Check-in reverted successfully' : 'Could not revert check-in' }
    );
  });
}

export const scanController = new ScanController();
