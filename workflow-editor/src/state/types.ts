export interface WorkflowState {
  id: string;
  state: string;
  history: StateHistoryEntry[];
  metadata: Record<string, any>;
  validations: ValidationResult[];
  transitions: TransitionDefinition[];
}

export interface StateHistoryEntry {
  from: string;
  to: string;
  timestamp: string;
  transition: string;
  metadata?: Record<string, any>;
}

export interface ValidationResult {
  field?: string;
  rule: string;
  message: string;
  level: 'error' | 'warning' | 'info';
}

export interface TransitionDefinition {
  name: string;
  from: string;
  to: string;
  requires?: string[];
  conditions?: TransitionCondition[];
}

export interface TransitionCondition {
  type: 'rule' | 'custom';
  rule?: string;
  customFn?: (state: WorkflowState) => boolean;
  message?: string;
}

export interface StateContextType {
  state: WorkflowState | null;
  dispatch: React.Dispatch<StateAction>;
  transitions: TransitionDefinition[];
  validations: ValidationResult[];
  history: StateHistoryEntry[];
}

export type StateAction =
  | { type: 'SET_STATE'; payload: Partial<WorkflowState> }
  | { type: 'TRANSITION'; payload: { to: string; transition: string; metadata?: Record<string, any> } }
  | { type: 'ADD_VALIDATION'; payload: ValidationResult }
  | { type: 'CLEAR_VALIDATIONS' }
  | { type: 'ADD_TRANSITION'; payload: TransitionDefinition }
  | { type: 'REMOVE_TRANSITION'; payload: string };
