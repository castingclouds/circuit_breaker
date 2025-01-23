import { useCallback } from 'react';
import { useStateContext } from '../state/StateContext';
import { StateManager } from '../state/StateManager';
import { WorkflowState, TransitionDefinition, ValidationResult } from '../state/types';

export function useWorkflowState() {
  const { state, dispatch } = useStateContext();
  const stateManager = StateManager.getInstance();

  const loadState = useCallback(async (id: string) => {
    try {
      const loadedState = await stateManager.loadState(id);
      dispatch({ type: 'SET_STATE', payload: loadedState });
      return loadedState;
    } catch (error) {
      console.error('Error loading state:', error);
      throw error;
    }
  }, [dispatch]);

  const saveState = useCallback(async () => {
    if (!state) throw new Error('No state to save');
    try {
      await stateManager.saveState(state);
    } catch (error) {
      console.error('Error saving state:', error);
      throw error;
    }
  }, [state]);

  const transition = useCallback(async (
    to: string,
    transitionName: string,
    metadata?: Record<string, any>
  ) => {
    if (!state) throw new Error('No current state');
    
    try {
      // First validate the transition
      const validations = await stateManager.validateTransition(
        state.state,
        to,
        transitionName
      );

      if (validations.some(v => v.level === 'error')) {
        throw new Error('Invalid transition');
      }

      // Execute the transition
      const newState = await stateManager.executeTransition(
        state.state,
        to,
        transitionName,
        metadata
      );

      // Update local state
      dispatch({
        type: 'TRANSITION',
        payload: { to, transition: transitionName, metadata }
      });

      return newState;
    } catch (error) {
      console.error('Error during transition:', error);
      throw error;
    }
  }, [state, dispatch]);

  const getAvailableTransitions = useCallback(async (): Promise<TransitionDefinition[]> => {
    if (!state) throw new Error('No current state');
    try {
      return await stateManager.getAvailableTransitions(state.state);
    } catch (error) {
      console.error('Error getting available transitions:', error);
      throw error;
    }
  }, [state]);

  const validateTransition = useCallback(async (
    to: string,
    transitionName: string
  ): Promise<ValidationResult[]> => {
    if (!state) throw new Error('No current state');
    try {
      return await stateManager.validateTransition(
        state.state,
        to,
        transitionName
      );
    } catch (error) {
      console.error('Error validating transition:', error);
      throw error;
    }
  }, [state]);

  return {
    state,
    loadState,
    saveState,
    transition,
    getAvailableTransitions,
    validateTransition,
  };
}
