import { Router } from 'express';
import { guestController } from '../controllers/guestController.js';
import { validateRequest } from '../middleware/validate.js';
import { authenticate, requirePermission } from '../middleware/auth.js';
import {
  AddGuestSchema,
  ListGuestsQuerySchema,
} from '../validators/guestValidators.js';

const router = Router({ mergeParams: true });

router.get(
  '/',
  authenticate,
  requirePermission('guests:read'),
  validateRequest({ query: ListGuestsQuerySchema }),
  guestController.listGuests
);

router.post(
  '/',
  authenticate,
  requirePermission('guests:write'),
  validateRequest({ body: AddGuestSchema }),
  guestController.addGuest
);

router.get(
  '/stats',
  authenticate,
  requirePermission('guests:read'),
  guestController.getGuestStats
);

export default router;
