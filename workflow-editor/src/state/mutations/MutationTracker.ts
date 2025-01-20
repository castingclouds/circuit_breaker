import { v4 as uuidv4 } from 'uuid';
import { 
  StateMutation, 
  MutationBatch, 
  MutationTrackerOptions, 
  MutationSubscriber,
  MutationType 
} from './types';

export class MutationTracker {
  private static instance: MutationTracker;
  private currentBatch: MutationBatch | null = null;
  private batchTimeout: NodeJS.Timeout | null = null;
  private subscribers: Map<string, MutationSubscriber> = new Map();
  private mutationHistory: MutationBatch[] = [];
  private options: Required<MutationTrackerOptions>;

  private defaultOptions: Required<MutationTrackerOptions> = {
    batchDelayMs: 1000,
    maxBatchSize: 100,
    persistToStorage: true,
    storageKey: 'workflow_mutations'
  };

  private constructor(options?: MutationTrackerOptions) {
    this.options = { ...this.defaultOptions, ...options };
    this.loadFromStorage();
  }

  static getInstance(options?: MutationTrackerOptions): MutationTracker {
    if (!MutationTracker.instance) {
      MutationTracker.instance = new MutationTracker(options);
    }
    return MutationTracker.instance;
  }

  track(
    type: MutationType,
    path: string[],
    previousValue: any,
    newValue: any,
    metadata?: Record<string, any>
  ): void {
    const mutation: StateMutation = {
      id: uuidv4(),
      type,
      timestamp: new Date().toISOString(),
      path,
      previousValue,
      newValue,
      metadata
    };

    this.addToBatch(mutation);
    this.notifySubscribers(mutation);
  }

  private addToBatch(mutation: StateMutation): void {
    if (!this.currentBatch) {
      this.currentBatch = {
        id: uuidv4(),
        mutations: [],
        timestamp: new Date().toISOString()
      };
    }

    this.currentBatch.mutations.push(mutation);

    if (this.currentBatch.mutations.length >= this.options.maxBatchSize) {
      this.flushBatch();
    } else {
      this.scheduleBatchFlush();
    }
  }

  private scheduleBatchFlush(): void {
    if (this.batchTimeout) {
      clearTimeout(this.batchTimeout);
    }

    this.batchTimeout = setTimeout(() => {
      this.flushBatch();
    }, this.options.batchDelayMs);
  }

  private flushBatch(): void {
    if (this.currentBatch && this.currentBatch.mutations.length > 0) {
      this.mutationHistory.push(this.currentBatch);
      
      if (this.options.persistToStorage) {
        this.saveToStorage();
      }

      this.currentBatch = null;
    }

    if (this.batchTimeout) {
      clearTimeout(this.batchTimeout);
      this.batchTimeout = null;
    }
  }

  subscribe(
    callback: (mutation: StateMutation) => void,
    filter?: (mutation: StateMutation) => boolean
  ): string {
    const id = uuidv4();
    this.subscribers.set(id, { id, callback, filter });
    return id;
  }

  unsubscribe(id: string): void {
    this.subscribers.delete(id);
  }

  private notifySubscribers(mutation: StateMutation): void {
    this.subscribers.forEach(subscriber => {
      if (!subscriber.filter || subscriber.filter(mutation)) {
        subscriber.callback(mutation);
      }
    });
  }

  getMutationHistory(): MutationBatch[] {
    return [...this.mutationHistory];
  }

  getMutationsForPath(path: string[]): StateMutation[] {
    return this.mutationHistory
      .flatMap(batch => batch.mutations)
      .filter(mutation => 
        path.every((segment, index) => mutation.path[index] === segment)
      );
  }

  private saveToStorage(): void {
    if (typeof window !== 'undefined' && this.options.persistToStorage) {
      try {
        localStorage.setItem(
          this.options.storageKey,
          JSON.stringify(this.mutationHistory)
        );
      } catch (error) {
        console.error('Failed to save mutations to storage:', error);
      }
    }
  }

  private loadFromStorage(): void {
    if (typeof window !== 'undefined' && this.options.persistToStorage) {
      try {
        const stored = localStorage.getItem(this.options.storageKey);
        if (stored) {
          this.mutationHistory = JSON.parse(stored);
        }
      } catch (error) {
        console.error('Failed to load mutations from storage:', error);
      }
    }
  }

  clear(): void {
    this.mutationHistory = [];
    if (this.options.persistToStorage) {
      localStorage.removeItem(this.options.storageKey);
    }
  }
}
