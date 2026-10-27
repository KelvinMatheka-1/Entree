import { machinenovaClient, MachineNovaClient } from './clients/machinenovaClient.js';
import {
  eventRepository,
  EventRepository,
  guestRepository,
  GuestRepository,
  scanLogRepository,
  ScanLogRepository,
  syncQueueRepository,
  SyncQueueRepository,
  userRepository,
  UserRepository,
} from './repositories/index.js';
import {
  AuthService,
  EventService,
  GuestService,
  ScanService,
  SyncService,
  authService,
  eventService,
  guestService,
  scanService,
  syncService,
} from './services/index.js';

export interface AppContainer {
  machinenovaClient: MachineNovaClient;
  eventRepository: EventRepository;
  guestRepository: GuestRepository;
  scanLogRepository: ScanLogRepository;
  syncQueueRepository: SyncQueueRepository;
  userRepository: UserRepository;
  authService: AuthService;
  eventService: EventService;
  guestService: GuestService;
  scanService: ScanService;
  syncService: SyncService;
}

export function createContainer(): AppContainer {
  return {
    machinenovaClient,
    eventRepository,
    guestRepository,
    scanLogRepository,
    syncQueueRepository,
    userRepository,
    authService,
    eventService,
    guestService,
    scanService,
    syncService,
  };
}

export const container: AppContainer = createContainer();
