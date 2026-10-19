import { Request, Response } from 'express';
import { syncService } from '../services/syncService.js';
import { machinenovaClient } from '../clients/machinenovaClient.js';

export class SyncController {
  public async getStatus(req: Request, res: Response): Promise<void> {
    try {
      const queueStatus = await syncService.getQueueStatus();
      res.json({
        success: true,
        upstreamConfigured: machinenovaClient.isConfigured(),
        queue: queueStatus,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }

  public async triggerSync(req: Request, res: Response): Promise<void> {
    try {
      const result = await syncService.processQueue();
      res.json({
        success: true,
        message: 'Sync process completed',
        result,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }
}

export const syncController = new SyncController();
