import { Router } from 'express';
import authRoutes from './authRoutes.js';
import eventRoutes from './eventRoutes.js';
import guestRoutes from './guestRoutes.js';
import scanRoutes from './scanRoutes.js';
import syncRoutes from './syncRoutes.js';

const apiRouter = Router();

apiRouter.use('/auth', authRoutes);
apiRouter.use('/events', eventRoutes);
apiRouter.use('/events/:eventId/guests', guestRoutes);
apiRouter.use('/events/:eventId', scanRoutes);
apiRouter.use('/sync', syncRoutes);

export default apiRouter;
