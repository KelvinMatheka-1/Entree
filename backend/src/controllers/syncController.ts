import { Request, Response } from 'express';
import { syncService as defaultSyncService, SyncService } from '../services/syncService.js';
import { machinenovaClient, MachineNovaClient } from '../clients/machinenovaClient.js';
import { asyncHandler } from '../common/asyncHandler.js';
import { ApiResponse } from '../common/apiResponse.js';

export class SyncController {
  constructor(
    private syncService: SyncService = defaultSyncService,
    private client: MachineNovaClient = machinenovaClient
  ) {}

  public getStatus = asyncHandler(async (req: Request, res: Response) => {
    const queueStatus = await this.syncService.getQueueStatus();
    ApiResponse.success(res, {
      upstreamConfigured: this.client.isConfigured(),
      queue: queueStatus,
    });
  });

  public triggerSync = asyncHandler(async (req: Request, res: Response) => {
    const result = await this.syncService.processQueue();
    ApiResponse.success(
      res,
      { result },
      { message: 'Sync process completed' }
    );
  });
}

export const syncController = new SyncController();
