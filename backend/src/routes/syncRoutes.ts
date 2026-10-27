import { Router } from 'express';
import { syncController } from '../controllers/syncController.js';
import { authenticate, requirePermission } from '../middleware/auth.js';

const router = Router();

router.get(
  '/status',
  authenticate,
  requirePermission('sync:read'),
  syncController.getStatus
);

router.post(
  '/trigger',
  authenticate,
  requirePermission('sync:trigger'),
  syncController.triggerSync
);

export default router;
