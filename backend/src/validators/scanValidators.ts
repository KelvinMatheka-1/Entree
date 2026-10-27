import { z } from 'zod';

export const VerifyScanQuerySchema = z.object({
  passId: z.string().optional(),
  id_number: z.string().optional(),
}).refine((data) => Boolean(data.passId || data.id_number), {
  message: 'Query parameter passId (or id_number) is required',
  path: ['passId'],
});

export const CheckInBodySchema = z.object({
  passId: z.string().min(1, 'Pass ID is required to execute check-in').trim(),
  operatorId: z.string().max(128).optional().default('mobile-app'),
  fullName: z.string().max(255).optional(),
  phone: z.string().max(64).optional(),
  tableNumber: z.string().max(32).optional(),
  tableName: z.string().max(128).optional(),
  county: z.string().max(128).optional(),
  constituency: z.string().max(128).optional(),
  ward: z.string().max(128).optional(),
  pollingCenter: z.string().max(128).optional(),
});

export const UndoCheckInBodySchema = z.object({
  passId: z.string().min(1, 'Pass ID is required to undo check-in').trim(),
});
