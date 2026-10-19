import { Router } from 'express';
import { syncController } from '../controllers/syncController.js';

const router = Router();

router.get('/status', (req, res) => syncController.getStatus(req, res));
router.post('/trigger', (req, res) => syncController.triggerSync(req, res));

export default router;
