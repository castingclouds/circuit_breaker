import { Edge, Node, MarkerType } from 'reactflow';
import { WORKFLOW_FILE } from './constants';
import workflowConfig from './document_workflow.yaml';
import dagre from 'dagre';

// Load and parse the YAML file
const config = workflowConfig;

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
  border: '1px solid #ddd',
  backgroundColor: '#ffffff',
  width: 180,
  fontSize: 12,
  color: '#222',
  fontWeight: 500,
  transition: 'all 0.2s ease',
  boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
};

export const selectedNodeStyles: NodeStyle = {
  ...nodeStyles,
  border: '2px solid #1a192b',
  boxShadow: '0 2px 6px rgba(0,0,0,0.2)',
};

export const edgeStyles: EdgeStyle = {
  stroke: '#222',
  strokeWidth: 1,
  labelBgPadding: [8, 4],
  labelBgStyle: {
    fill: '#fff',
    stroke: '#ddd',
    strokeWidth: 1,
    borderRadius: 4,
  },
  labelStyle: {
    fontSize: 12,
    fill: '#222',
    fontWeight: 500,
  },
  selected: {
    stroke: '#1a192b',
    strokeWidth: 2,
    markerEnd: {
      type: 'arrowclosed',
      width: 16,
      height: 16,
      color: '#1a192b',
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

// Generate nodes from states
const states = [...(config.places.states || []), ...(config.places.special_states || [])];
const nodes: Node[] = states.map((state, index) => ({
  id: state.replace(/\s+/g, '_'), // Replace all whitespace with underscores
  type: 'custom',
  position: { x: 0, y: index * 100 }, // Initial positions will be adjusted by dagre
  data: {
    label: formatLabel(state),
    description: '', // You can add descriptions from your config if available
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

// Add nodes to dagre
nodes.forEach((node) => {
  g.setNode(node.id, { width: 180, height: 60 });
});

// Add edges to dagre
edges.forEach((edge) => {
  g.setEdge(edge.source, edge.target);
});

// Calculate layout
dagre.layout(g);

// Apply layout to nodes
nodes.forEach((node) => {
  const nodeWithPosition = g.node(node.id);
  if (nodeWithPosition && typeof nodeWithPosition.x === 'number' && typeof nodeWithPosition.y === 'number') {
    node.position = {
      x: nodeWithPosition.x - 90,  // Center node horizontally (180/2)
      y: nodeWithPosition.y - 30   // Center node vertically (60/2)
    };
  }
});

// Initial nodes and edges for testing
export const initialNodes = nodes;
export const initialEdges = edges;

// Default viewport
export const defaultViewport = { x: 0, y: 0, zoom: 1.5 }; // 150% zoom
