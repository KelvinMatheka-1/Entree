import { z } from 'zod';

export const EventStatusSchema = z.enum(['upcoming', 'live', 'past', 'draft']);

export const CreateEventSchema = z.object({
  name: z.string().min(1, 'Event name is required').max(255).trim(),
  venue: z.string().max(255).optional().default('Main Venue'),
  venueAddress: z.string().max(255).optional().default(''),
  collection: z.string().max(128).optional().default('GENERAL EVENT'),
  description: z.string().max(2000).optional().default(''),
  date: z.string().min(1, 'Event date is required').max(32).trim(),
  startTime: z.string().max(32).optional().default('18:00'),
  endTime: z.string().max(32).optional().default('22:00'),
  doorsOpenTime: z.string().max(32).optional().default('17:30'),
  tables: z.number().int().min(1).max(500).optional().default(10),
  seatsPerTable: z.number().int().min(1).max(100).optional().default(10),
  totalCapacity: z.number().int().min(1).max(50000).optional(),
  passesIssued: z.number().int().min(0).optional().default(0),
  status: EventStatusSchema.optional().default('upcoming'),
  imageUrl: z.string().url().max(1000).optional().nullable(),
  isPaid: z.boolean().optional().default(true),
  priceBadge: z.string().max(64).optional(),
  city: z.string().max(128).optional().default(''),
  restrictToJurisdiction: z.boolean().optional().default(false),
  restrictToRoster: z.boolean().optional().default(false),
  geoNode: z.string().max(128).optional().nullable(),
});

export const UpdateEventSchema = CreateEventSchema.partial().and(
  z.object({
    checkedIn: z.number().int().min(0).optional(),
  })
);

export const ListEventsQuerySchema = z.object({
  status: z.string().optional(),
  search: z.string().optional(),
  refresh: z
    .string()
    .optional()
    .transform((val) => val === 'true'),
});

export const EventIdParamSchema = z.object({
  id: z.string().min(1, 'Event ID is required'),
});
