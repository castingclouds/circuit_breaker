import { useEffect, useCallback, useState } from 'react';
import { MutationTracker } from '../state/mutations/MutationTracker';
import { StateMutation, MutationBatch } from '../state/mutations/types';

export function useStateMutations(path?: string[]) {
  const [mutations, setMutations] = useState<StateMutation[]>([]);
  const tracker = MutationTracker.getInstance();

  useEffect(() => {
    // Subscribe to mutations
    const subscriberId = tracker.subscribe(
      (mutation) => {
        setMutations(prev => [...prev, mutation]);
      },
      path ? (mutation) =>
        path.every((segment, index) => mutation.path[index] === segment)
      : undefined
    );

    // Load initial mutations if path is provided
    if (path) {
      const initialMutations = tracker.getMutationsForPath(path);
      setMutations(initialMutations);
    } else {
      const allMutations = tracker.getMutationHistory()
        .flatMap(batch => batch.mutations);
      setMutations(allMutations);
    }

    return () => {
      tracker.unsubscribe(subscriberId);
    };
  }, [path]);

  const clearMutations = useCallback(() => {
    tracker.clear();
    setMutations([]);
  }, []);

  return {
    mutations,
    clearMutations,
  };
}
