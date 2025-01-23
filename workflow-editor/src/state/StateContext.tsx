import React, { createContext, useReducer, useContext, useCallback } from 'react';
import { 
  StateContextType, 
  WorkflowState, 
  StateAction, 
  ValidationResult, 
  TransitionDefinition 
} from './types';
import { MutationTracker } from './mutations/MutationTracker';

const StateContext = createContext<StateContextType | null>(null);

const initialState: WorkflowState = {
  id: '',
  state: '',
  history: [],
  metadata: {},
  validations: [],
  transitions: [],
};

function stateReducer(state: WorkflowState, action: StateAction): WorkflowState {
  const tracker = MutationTracker.getInstance();
  
  switch (action.type) {
    case 'SET_STATE':
      tracker.track(
        'STATE_CHANGE',
        ['state'],
        state,
        { ...state, ...action.payload },
        { action: 'SET_STATE' }
      );
      return { ...state, ...action.payload };
    
    case 'TRANSITION':
      tracker.track(
        'TRANSITION',
        ['state', 'history'],
        { currentState: state.state, history: state.history },
        { 
          currentState: action.payload.to,
          history: [...state.history, {
            from: state.state,
            to: action.payload.to,
            transition: action.payload.transition,
            timestamp: new Date().toISOString(),
            metadata: action.payload.metadata,
          }]
        },
        { action: 'TRANSITION', metadata: action.payload.metadata }
      );
      
      const newHistory = [...state.history, {
        from: state.state,
        to: action.payload.to,
        transition: action.payload.transition,
        timestamp: new Date().toISOString(),
        metadata: action.payload.metadata,
      }];
      
      return {
        ...state,
        state: action.payload.to,
        history: newHistory,
      };
    
    case 'ADD_VALIDATION':
      tracker.track(
        'VALIDATION_ADDED',
        ['validations'],
        state.validations,
        [...state.validations, action.payload],
        { action: 'ADD_VALIDATION' }
      );
      return {
        ...state,
        validations: [...state.validations, action.payload],
      };
    
    case 'CLEAR_VALIDATIONS':
      tracker.track(
        'VALIDATION_CLEARED',
        ['validations'],
        state.validations,
        [],
        { action: 'CLEAR_VALIDATIONS' }
      );
      return {
        ...state,
        validations: [],
      };
    
    case 'ADD_TRANSITION':
      tracker.track(
        'TRANSITION_ADDED',
        ['transitions'],
        state.transitions,
        [...state.transitions, action.payload],
        { action: 'ADD_TRANSITION' }
      );
      return {
        ...state,
        transitions: [...state.transitions, action.payload],
      };
    
    case 'REMOVE_TRANSITION':
      tracker.track(
        'TRANSITION_REMOVED',
        ['transitions'],
        state.transitions,
        state.transitions.filter(t => t.name !== action.payload),
        { action: 'REMOVE_TRANSITION', transitionName: action.payload }
      );
      return {
        ...state,
        transitions: state.transitions.filter(t => t.name !== action.payload),
      };
    
    default:
      return state;
  }
}

export function StateProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(stateReducer, initialState);

  const value = {
    state,
    dispatch,
    transitions: state.transitions,
    validations: state.validations,
    history: state.history,
  };

  return (
    <StateContext.Provider value={value}>
      {children}
    </StateContext.Provider>
  );
}

export function useStateContext() {
  const context = useContext(StateContext);
  if (!context) {
    throw new Error('useStateContext must be used within a StateProvider');
  }
  return context;
}
