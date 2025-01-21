import { Edge, Node, MarkerType } from 'reactflow';
import dagre from 'dagre';
import { loadWorkflowFromServer } from '../services/api';

// Define types for our configuration
interface NodeStyle {
  padding: number;
  borderRadius: number;
  border: string;
  backgroundColor: string;
  width: number;
  fontSize: number;
  color: string;
  fontWeight: number;
  transition: string;
  boxShadow: string;
}

interface EdgeStyle {
  stroke: string;
  strokeWidth: number;
  labelBgPadding: number[];
  labelBgStyle: {
    fill: string;
    stroke: string;
    strokeWidth: number;
    borderRadius: number;
  };
  labelStyle: {
    fontSize: number;
    fill: string;
    fontWeight: number;
  };
  selected: {
    stroke: string;
    strokeWidth: number;
    markerEnd?: {
      type: string;
      width: number;
      height: number;
      color: string;
    };
  };
  markerEnd?: {
    type: string;
    width: number;
    height: number;
    color: string;
  };
}

// Default styles
export const nodeStyles: NodeStyle = {
  padding: 10,
  borderRadius: 5,
  border: '1px solid #222',
  backgroundColor: '#ffffff',
  width: 150,
  fontSize: 12,
  color: '#222',
  fontWeight: 500,
  transition: 'all 250ms cubic-bezier(0.4, 0, 0.2, 1) 0ms',
  boxShadow: '0 1px 4px rgba(0, 0, 0, 0.16)',
};

export const edgeStyles: EdgeStyle = {
  stroke: '#222',
  strokeWidth: 2,
  labelBgPadding: [8, 4],
  labelBgStyle: {
    fill: '#fff',
    stroke: '#222',
    strokeWidth: 1,
    borderRadius: 4,
  },
  labelStyle: {
    fontSize: 12,
    fill: '#222',
    fontWeight: 500,
  },
  selected: {
    stroke: '#00ff00',
    strokeWidth: 3,
    markerEnd: {
      type: 'arrowclosed',
      width: 16,
      height: 16,
      color: '#00ff00',
    },
  },
  markerEnd: {
    type: 'arrowclosed',
    width: 16,
    height: 16,
    color: '#222',
  },
};

// Helper function to capitalize and format state names
function formatLabel(state: string) {
  return state
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

// Default viewport
export const defaultViewport = { x: 0, y: 0, zoom: 1.5 };

// Function to generate flow config from workflow data
export const generateFlowConfig = async (workflowPath: string) => {
  const config = await loadWorkflowFromServer(workflowPath);
  console.log('Loaded workflow config:', config);

  // Generate nodes from states
  const states = [...(config.places.states || []), ...(config.places.special_states || [])];
  const nodes: Node[] = states.map((state, index) => ({
    id: state.name.replace(/\s+/g, '_'),
    type: 'custom',
    position: { x: 0, y: index * 100 }, // Initial positions will be adjusted by dagre
    data: {
      label: state.name,
      description: '',
    },
  }));

  // Generate edges from transitions
  const allTransitions = [
    ...(config.transitions.regular || []),
    ...(config.transitions.special || [])
  ];

  const edges: Edge[] = allTransitions.map((transition, index) => ({
    id: `e${index}`,
    source: transition.from.replace(/\s+/g, '_'),
    target: transition.to.replace(/\s+/g, '_'),
    label: formatLabel(transition.name),
    type: 'custom',
    data: {
      requirements: transition.requires || []
    },
  }));

  // Create a new dagre graph
  const g = new dagre.graphlib.Graph();
  g.setGraph({ 
    rankdir: 'TB',
    nodesep: 100,
    ranksep: 150
  });
  g.setDefaultEdgeLabel(() => ({}));

  // Add nodes and edges to dagre graph
  nodes.forEach(node => {
    g.setNode(node.id, { width: 150, height: 50 });
  });

  edges.forEach(edge => {
    g.setEdge(edge.source, edge.target);
  });

  // Calculate layout
  dagre.layout(g);

  // Apply layout to nodes
  nodes.forEach(node => {
    const nodeWithPosition = g.node(node.id);
    node.position = {
      x: nodeWithPosition.x - 75, // Subtract half the width
      y: nodeWithPosition.y - 25  // Subtract half the height
    };
  });

  return { nodes, edges };
};

// Export empty initial states that will be populated by App.tsx
export const initialNodes: Node[] = [];
export const initialEdges: Edge[] = [];
