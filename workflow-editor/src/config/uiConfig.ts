import { Node, Edge } from 'reactflow';

export const defaultNodeStyle = {
  padding: 20,
  borderRadius: 8,
  border: '1px solid #e1e4e8',
  backgroundColor: '#ffffff',
  width: 180,
  fontSize: 14,
};

export const defaultNodePosition = {
  x: 250,
  y: 100,
};

export const getNodePosition = (index: number) => ({
  x: defaultNodePosition.x,
  y: index * defaultNodePosition.y,
});

export interface WorkflowUIConfig {
  nodeSpacing: number;
  defaultLayout: 'vertical' | 'horizontal';
  stateStyles: {
    [key: string]: {
      backgroundColor?: string;
      borderColor?: string;
      textColor?: string;
    };
  };
}

export const defaultUIConfig: WorkflowUIConfig = {
  nodeSpacing: 100,
  defaultLayout: 'vertical',
  stateStyles: {
    backlog: {
      backgroundColor: '#f3f4f6',
    },
    blocked: {
      backgroundColor: '#fee2e2',
      borderColor: '#ef4444',
    },
    done: {
      backgroundColor: '#dcfce7',
    },
  },
};

export const createNodesFromStates = (states: string[], specialStates: string[] = []): Node[] => {
  const allStates = [...states, ...specialStates];
  return allStates.map((state, index) => ({
    id: state,
    type: index === 0 ? 'input' : index === states.length - 1 ? 'output' : 'default',
    data: { 
      label: state.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' '),
      description: '',
    },
    position: getNodePosition(index),
    style: {
      ...defaultNodeStyle,
      ...(defaultUIConfig.stateStyles[state] || {}),
    },
  }));
};

export const createEdgesFromTransitions = (transitions: any[]): Edge[] => {
  return transitions.map((transition, index) => ({
    id: `edge-${transition.from}-${transition.to}`,
    source: transition.from,
    target: transition.to,
    label: transition.name.split('_').map(word => 
      word.charAt(0).toUpperCase() + word.slice(1)
    ).join(' '),
  }));
};
