import { supabaseAdmin } from '../config/supabase.js';
import { AppError, asyncHandler } from '../utils/AppError.js';

// Verifies the Supabase access token sent as "Authorization: Bearer <jwt>"
export const requireAuth = asyncHandler(async (req, _res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) throw new AppError('Authentication required', 401);

  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data?.user) throw new AppError('Invalid or expired session', 401);

  const { data: profile } = await supabaseAdmin
    .from('profiles').select('id, full_name, phone, role').eq('id', data.user.id).single();

  req.user = { id: data.user.id, email: data.user.email, ...profile };
  next();
});

export const requireAdmin = (req, _res, next) => {
  if (req.user?.role !== 'admin') return next(new AppError('Admin access required', 403));
  next();
};
