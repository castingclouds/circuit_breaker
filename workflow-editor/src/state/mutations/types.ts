export type MutationType = 
  | 'STATE_CHANGE'
  | 'TRANSITION'
  | 'VALIDATION_ADDED'
  | 'VALIDATION_CLEARED'
  | 'TRANSITION_ADDED'
  | 'TRANSITION_REMOVED'
  | 'METADATA_UPDATED';

export interface StateMutation {
  id: string;
  type: MutationType;
  timestamp: string;
  path: string[];
  previousValue: any;
  newValue: any;
  metadata?: Record<string, any>;
}

export interface MutationBatch {
  id: string;
  mutations: StateMutation[];
  timestamp: string;
  source?: string;
  metadata?: Record<string, any>;
}

export interface MutationTrackerOptions {
  batchDelayMs?: number;
  maxBatchSize?: number;
  persistToStorage?: boolean;
  storageKey?: string;
}

export interface MutationSubscriber {
  id: string;
  callback: (mutation: StateMutation) => void;
  filter?: (mutation: StateMutation) => boolean;
}
