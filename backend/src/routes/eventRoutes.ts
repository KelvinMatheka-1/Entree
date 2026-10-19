import { Router } from 'express';
import { eventController } from '../controllers/eventController.js';

const router = Router();

router.get('/', (req, res) => eventController.listEvents(req, res));
router.post('/', (req, res) => eventController.createEvent(req, res));
router.get('/:id', (req, res) => eventController.getEventById(req, res));
router.put('/:id', (req, res) => eventController.updateEvent(req, res));
router.delete('/:id', (req, res) => eventController.deleteEvent(req, res));
router.get('/:id/stats', (req, res) => eventController.getEventStats(req, res));

export default router;
