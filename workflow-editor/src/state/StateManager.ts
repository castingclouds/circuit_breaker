import { WorkflowState, TransitionDefinition, ValidationResult } from './types';

export class StateManager {
  private static instance: StateManager;
  private currentState: WorkflowState | null = null;

  private constructor() {}

  static getInstance(): StateManager {
    if (!StateManager.instance) {
      StateManager.instance = new StateManager();
    }
    return StateManager.instance;
  }

  async loadState(id: string): Promise<WorkflowState> {
    try {
      const response = await fetch(`/api/workflow/${id}/state`);
      if (!response.ok) throw new Error('Failed to load state');
      
      const state = await response.json();
      this.currentState = state;
      return state;
    } catch (error) {
      console.error('Error loading state:', error);
      throw error;
    }
  }

  async saveState(state: WorkflowState): Promise<void> {
    try {
      const response = await fetch(`/api/workflow/${state.id}/state`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(state),
      });
      
      if (!response.ok) throw new Error('Failed to save state');
      
      this.currentState = state;
    } catch (error) {
      console.error('Error saving state:', error);
      throw error;
    }
  }

  async validateTransition(
    from: string,
    to: string,
    transition: string
  ): Promise<ValidationResult[]> {
    try {
      const response = await fetch('/api/workflow/validate-transition', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ from, to, transition }),
      });
      
      if (!response.ok) throw new Error('Failed to validate transition');
      
      return await response.json();
    } catch (error) {
      console.error('Error validating transition:', error);
      throw error;
    }
  }

  async executeTransition(
    from: string,
    to: string,
    transition: string,
    metadata?: Record<string, any>
  ): Promise<WorkflowState> {
    try {
      const response = await fetch('/api/workflow/execute-transition', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ from, to, transition, metadata }),
      });
      
      if (!response.ok) throw new Error('Failed to execute transition');
      
      const newState = await response.json();
      this.currentState = newState;
      return newState;
    } catch (error) {
      console.error('Error executing transition:', error);
      throw error;
    }
  }

  async getAvailableTransitions(state: string): Promise<TransitionDefinition[]> {
    try {
      const response = await fetch(`/api/workflow/transitions/${state}`);
      if (!response.ok) throw new Error('Failed to get available transitions');
      
      return await response.json();
    } catch (error) {
      console.error('Error getting available transitions:', error);
      throw error;
    }
  }

  getCurrentState(): WorkflowState | null {
    return this.currentState;
  }
}
