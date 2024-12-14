import { Node, Edge } from 'reactflow';

interface WorkflowData {
  object_type: string;
  places: {
    states: string[];
    special_states: string[];
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
}

export const saveWorkflow = async (nodes: Node[], edges: Edge[]) => {
  console.log('saveWorkflow called with nodes:', nodes);

  // Create a map of node IDs to their current labels
  const nodeIdToLabel = new Map(nodes.map(node => [
    node.id,
    node.data.label.toLowerCase().replace(/\s+/g, '_')
  ]));

  // Get regular states (just the IDs)
  const states = nodes
    .filter(node => node.type !== 'special' && node.id !== 'blocked')
    .map(node => node.data.label.toLowerCase().replace(/\s+/g, '_'));

  // Get special states (just the IDs)
  const specialStates = nodes
    .filter(node => node.type === 'special' || node.id === 'blocked')
    .map(node => node.data.label.toLowerCase().replace(/\s+/g, '_'));

  // Convert edges to transitions, using the current node labels
  const transitions = edges.map(edge => ({
    name: (edge.label || 'transition').toLowerCase().replace(/\s+/g, '_'),
    from: nodeIdToLabel.get(edge.source) || edge.source,
    to: nodeIdToLabel.get(edge.target) || edge.target,
    requires: edge.data?.requirements || []
  }));

  const workflowData: WorkflowData = {
    object_type: 'Issue',
    places: {
      states,
      special_states: specialStates
    },
    transitions: {
      regular: transitions
    }
  };

  try {
    const response = await fetch('http://localhost:3001/api/save-workflow', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(workflowData),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const result = await response.json();
    console.log('Save successful:', result);
    return result.success;
  } catch (error) {
    console.error('Error saving workflow:', error);
    throw error;
  }
};
