import { Router } from 'express';
import { scanController } from '../controllers/scanController.js';

const router = Router({ mergeParams: true });

router.get('/scan', (req, res) => scanController.verifyScan(req, res));
router.post('/checkin', (req, res) => scanController.checkIn(req, res));
router.post('/undo-checkin', (req, res) => scanController.undoCheckIn(req, res));

export default router;
