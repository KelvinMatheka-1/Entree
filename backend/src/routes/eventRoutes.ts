import { Router } from 'express';
import { eventController } from '../controllers/eventController.js';
import { validateRequest } from '../middleware/validate.js';
import { authenticate, requirePermission } from '../middleware/auth.js';
import {
  CreateEventSchema,
  UpdateEventSchema,
  ListEventsQuerySchema,
  EventIdParamSchema,
} from '../validators/eventValidators.js';

const router = Router();

router.get(
  '/',
  authenticate,
  requirePermission('events:read'),
  validateRequest({ query: ListEventsQuerySchema }),
  eventController.listEvents
);

router.post(
  '/',
  authenticate,
  requirePermission('events:write'),
  validateRequest({ body: CreateEventSchema }),
  eventController.createEvent
);

router.get(
  '/:id',
  authenticate,
  requirePermission('events:read'),
  validateRequest({ params: EventIdParamSchema }),
  eventController.getEventById
);

router.put(
  '/:id',
  authenticate,
  requirePermission('events:write'),
  validateRequest({ params: EventIdParamSchema, body: UpdateEventSchema }),
  eventController.updateEvent
);

router.delete(
  '/:id',
  authenticate,
  requirePermission('events:delete'),
  validateRequest({ params: EventIdParamSchema }),
  eventController.deleteEvent
);

router.get(
  '/:id/stats',
  authenticate,
  requirePermission('events:read'),
  validateRequest({ params: EventIdParamSchema }),
  eventController.getEventStats
);

export default router;
