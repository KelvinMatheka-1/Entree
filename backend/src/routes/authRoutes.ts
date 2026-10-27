import { Router } from 'express';
import { authController } from '../controllers/authController.js';
import { validateRequest } from '../middleware/validate.js';
import { authenticate } from '../middleware/auth.js';
import { authLimiter } from '../middleware/rateLimiter.js';
import {
  LoginBodySchema,
  UpdateProfileBodySchema,
} from '../validators/authValidators.js';

const router = Router();

router.post(
  '/login',
  authLimiter,
  validateRequest({ body: LoginBodySchema }),
  authController.login
);

router.get('/me', authController.getMe);
router.get('/status', authController.getStatus);

router.get(
  '/profile',
  authenticate,
  authController.getProfile
);

router.put(
  '/profile',
  authenticate,
  validateRequest({ body: UpdateProfileBodySchema }),
  authController.updateProfile
);

export default router;
