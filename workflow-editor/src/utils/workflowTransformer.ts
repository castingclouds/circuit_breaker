import { Node, Edge } from 'reactflow';
import { createNodesFromStates, createEdgesFromTransitions } from '../config/uiConfig';

export interface WorkflowDSL {
  object_type: string;
  places: {
    states: string[];
    special_states?: string[];
  };
  transitions: {
    regular: Array<{
      name: string;
      from: string;
      to: string;
      requires?: string[];
    }>;
    blocking?: Array<{
      name: string;
      from: string | string[];
      to: string | string[];
      requires?: string[];
    }>;
  };
  validations?: Array<{
    state: string;
    conditions: Array<{
      field: string;
      required: boolean;
    }>;
  }>;
}

export interface UIWorkflow {
  nodes: Node[];
  edges: Edge[];
}

export const transformDSLToUI = (dsl: WorkflowDSL): UIWorkflow => {
  const nodes = createNodesFromStates(
    dsl.places.states,
    dsl.places.special_states || []
  );

  const allTransitions = [
    ...dsl.transitions.regular,
    ...(dsl.transitions.blocking || []).map(blocking => {
      const fromStates = Array.isArray(blocking.from) ? blocking.from : [blocking.from];
      const toStates = Array.isArray(blocking.to) ? blocking.to : [blocking.to];
      
      return fromStates.flatMap(from => 
        toStates.map(to => ({
          name: blocking.name,
          from,
          to,
          requires: blocking.requires
        }))
      );
    }).flat()
  ];

  const edges = createEdgesFromTransitions(allTransitions);

  return { nodes, edges };
};

export const transformUIToDSL = (ui: UIWorkflow): WorkflowDSL => {
  const states = ui.nodes
    .filter(node => node.type !== 'special')
    .map(node => node.id);

  const special_states = ui.nodes
    .filter(node => node.type === 'special')
    .map(node => node.id);

  const transitions = ui.edges.map(edge => ({
    name: edge.label?.toLowerCase().replace(/\s+/g, '_') || '',
    from: edge.source,
    to: edge.target,
  }));

  return {
    object_type: 'Issue',
    places: {
      states,
      special_states: special_states.length > 0 ? special_states : undefined,
    },
    transitions: {
      regular: transitions,
    },
  };
};
