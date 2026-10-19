import { Router } from 'express';
import { guestController } from '../controllers/guestController.js';

const router = Router({ mergeParams: true });

router.get('/', (req, res) => guestController.listGuests(req, res));
router.post('/', (req, res) => guestController.addGuest(req, res));
router.get('/stats', (req, res) => guestController.getGuestStats(req, res));

export default router;
