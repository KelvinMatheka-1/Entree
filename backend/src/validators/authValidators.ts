import { z } from 'zod';

export const LoginBodySchema = z.object({
  username: z.string().min(1, 'Username is required').trim(),
  password: z.string().min(1, 'Password is required'),
});

export const UpdateProfileBodySchema = z.object({
  fullName: z.string().max(255).optional(),
  email: z.string().email().max(255).optional(),
  role: z.string().max(128).optional(),
  organization: z.string().max(128).optional(),
  phone: z.string().max(64).optional(),
  scannerSpeed: z.string().max(32).optional(),
  hapticFeedback: z.boolean().optional(),
});
