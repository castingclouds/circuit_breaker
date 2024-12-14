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
  console.log('saveWorkflow called with edges:', edges);

  // Ensure edges have labels
  const processedEdges = edges.map(edge => {
    console.log('Processing edge:', edge);
    return {
      id: edge.id,
      source: edge.source,
      target: edge.target,
      label: edge.label || '',  // Always include label, even if empty
      ...(edge.sourceHandle && { sourceHandle: edge.sourceHandle }),
      ...(edge.targetHandle && { targetHandle: edge.targetHandle })
    };
  });

  console.log('Processed edges:', processedEdges);

  const workflowData: WorkflowData = {
    nodes: nodes.map(node => ({
      id: node.id,
      type: node.type,
      data: node.data,
      position: node.position,
      ...(node.customStyle && { customStyle: node.customStyle })
    })),
    edges: processedEdges,
    styles
  };

  console.log('Sending workflow data to server:', JSON.stringify(workflowData, null, 2));

  try {
    console.log('Making POST request to save workflow...');
    const response = await fetch('http://localhost:3001/api/save-workflow', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(workflowData),
    });

    console.log('Server response status:', response.status);
    const data = await response.json();
    console.log('Server response data:', data);
    return data.success;
  } catch (error) {
    console.error('Error saving workflow:', error);
    return false;
  }
};
