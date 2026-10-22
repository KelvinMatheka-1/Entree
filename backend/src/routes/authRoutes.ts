import { Router } from 'express';
import { authController } from '../controllers/authController.js';

const router = Router();

router.post('/login', (req, res) => authController.login(req, res));
router.get('/me', (req, res) => authController.getMe(req, res));
router.get('/status', (req, res) => authController.getStatus(req, res));
router.get('/profile', (req, res) => authController.getProfile(req, res));
router.put('/profile', (req, res) => authController.updateProfile(req, res));

export default router;
