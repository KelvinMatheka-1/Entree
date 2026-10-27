import { Router } from 'express';
import { scanController } from '../controllers/scanController.js';
import { validateRequest } from '../middleware/validate.js';
import { authenticate, requirePermission } from '../middleware/auth.js';
import { scanLimiter } from '../middleware/rateLimiter.js';
import {
  VerifyScanQuerySchema,
  CheckInBodySchema,
  UndoCheckInBodySchema,
} from '../validators/scanValidators.js';

const router = Router({ mergeParams: true });

router.get(
  '/scan',
  scanLimiter,
  authenticate,
  requirePermission('scan:verify'),
  validateRequest({ query: VerifyScanQuerySchema }),
  scanController.verifyScan
);

router.post(
  '/checkin',
  scanLimiter,
  authenticate,
  requirePermission('scan:checkin'),
  validateRequest({ body: CheckInBodySchema }),
  scanController.checkIn
);

router.post(
  '/undo-checkin',
  scanLimiter,
  authenticate,
  requirePermission('scan:checkin'),
  validateRequest({ body: UndoCheckInBodySchema }),
  scanController.undoCheckIn
);

export default router;
