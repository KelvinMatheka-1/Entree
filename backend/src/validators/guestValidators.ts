import { z } from 'zod';

export const AddGuestSchema = z.object({
  fullName: z.string().min(1, 'Full name is required').max(255).trim(),
  email: z.string().email().max(255).optional().or(z.literal('')),
  phone: z.string().max(64).optional().default(''),
  passId: z.string().max(128).optional(),
  tableNumber: z.string().max(32).optional().default('01'),
  tableName: z.string().max(128).optional().default('General'),
  admission: z.string().max(64).optional().default('Standard Pass'),
  county: z.string().max(128).optional().nullable(),
  constituency: z.string().max(128).optional().nullable(),
  ward: z.string().max(128).optional().nullable(),
  pollingCenter: z.string().max(128).optional().nullable(),
});

export const ListGuestsQuerySchema = z.object({
  status: z.string().optional(),
  search: z.string().optional(),
});

export const EventIdAndGuestIdParamSchema = z.object({
  eventId: z.string().min(1, 'Event ID is required'),
  guestId: z.string().optional(),
});
