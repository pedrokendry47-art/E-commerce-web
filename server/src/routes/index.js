import { Router } from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { asyncHandler } from '../utils/AppError.js';

const router = Router();

// Health check + database connectivity (also used by Railway)
router.get('/health', asyncHandler(async (_req, res) => {
  const { error } = await supabaseAdmin.from('categories').select('id').limit(1);
  if (error) return res.status(503).json({ success: false, status: 'degraded', database: 'down' });
  res.json({ success: true, status: 'ok', database: 'up', time: new Date().toISOString() });
}));

// Current user + role (used by the client to gate the admin area)
router.get('/me', requireAuth, (req, res) => res.json({ success: true, data: req.user }));

// Feature routers get mounted here in later phases:
// router.use('/products', productRoutes); router.use('/cart', cartRoutes); ...

export default router;
