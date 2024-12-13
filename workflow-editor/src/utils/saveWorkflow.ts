import { Node, Edge } from 'reactflow';

interface WorkflowData {
  nodes: Node[];
  edges: Edge[];
  styles: {
    node: Record<string, any>;
    edge: Record<string, any>;
  };
}

export const saveWorkflow = async (nodes: Node[], edges: Edge[], styles: WorkflowData['styles']) => {
  const workflowData: WorkflowData = {
    nodes: nodes.map(node => ({
      id: node.id,
      type: node.type,
      data: node.data,
      position: node.position,
      ...(node.customStyle && { customStyle: node.customStyle })
    })),
    edges: edges.map(edge => ({
      id: edge.id,
      source: edge.source,
      target: edge.target,
      label: edge.label,
      ...(edge.sourceHandle && { sourceHandle: edge.sourceHandle }),
      ...(edge.targetHandle && { targetHandle: edge.targetHandle })
    })),
    styles
  };

  try {
    const response = await fetch('http://localhost:3001/api/save-workflow', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(workflowData),
    });

    const data = await response.json();
    return data.success;
  } catch (error) {
    console.error('Error saving workflow:', error);
    return false;
  }
};
