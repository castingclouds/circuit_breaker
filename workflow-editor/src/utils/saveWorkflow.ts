import { Node, Edge } from 'reactflow';
import { saveWorkflowToServer } from '../services/api';

interface WorkflowData {
  object_type: string;
  places: {
    states: string[];
    special_states?: string[];
  };
  transitions: {
    regular: {
      name: string;
      from: string;
      to: string;
      requires?: string[];
    }[];
    special?: {
      name: string;
      from: string;
      to: string;
      requires?: string[];
    }[];
  };
  metadata?: {
    rules?: {
      id: string;
      description: string;
    }[];
  };
}

export const saveWorkflow = async (nodes: Node[], edges: Edge[]): Promise<boolean> => {
  try {
    // Create a map of node IDs to their current labels
    const nodeIdToLabel = new Map(nodes.map(node => [
      node.id,
      node.data.label.toLowerCase().replace(/\s+/g, '_')
    ]));

    // Get regular states
    const states = nodes
      .filter(node => node.type !== 'special' && node.id !== 'blocked')
      .map(node => node.data.label.toLowerCase().replace(/\s+/g, '_'));

    // Get special states
    const specialStates = nodes
      .filter(node => node.type === 'special' || node.id === 'blocked')
      .map(node => node.data.label.toLowerCase().replace(/\s+/g, '_'));

    // Convert edges to transitions
    const transitions = edges.map(edge => ({
      name: (edge.label || edge.startLabel || 'transition').toLowerCase().replace(/\s+/g, '_'),
      from: nodeIdToLabel.get(edge.source) || edge.source,
      to: nodeIdToLabel.get(edge.target) || edge.target,
      requires: edge.data?.requirements || []
    }));

    // Create the workflow data structure
    const workflowData: WorkflowData = {
      object_type: 'Document',
      places: {
        states,
        special_states: specialStates.length > 0 ? specialStates : undefined
      },
      transitions: {
        regular: transitions
      },
      metadata: {
        rules: nodes.flatMap(node => 
          node.data.requirements?.map(req => ({
            id: req,
            description: node.data.requirementDescriptions?.[req] || ''
          })) || []
        )
      }
    };

    console.log('Saving workflow data:', workflowData);
    
    // Save to server
    const response = await saveWorkflowToServer(workflowData);
    console.log('Save response:', response);
    
    return response;
  } catch (error) {
    console.error('Error in saveWorkflow:', error);
    return false;
  }
};
