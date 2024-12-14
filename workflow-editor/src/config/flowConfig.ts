import { Edge } from 'reactflow';
import { WORKFLOW_FILE } from './constants';
import workflowConfig from './workflow.yaml';
import dagre from 'dagre';

// Load and parse the YAML file
const config = workflowConfig;

// Default styles
const defaultNodeStyle: NodeStyle = {
  padding: 10,
  borderRadius: 8,
  border: '1px solid #ddd',
  backgroundColor: '#fff',
  width: 150,
  fontSize: 14,
  color: '#333',
  fontWeight: 500,
  transition: '0.2s',
  boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
};

const defaultEdgeStyle: EdgeStyle = {
  stroke: '#b1b1b7',
  strokeWidth: 2,
  labelBgPadding: [8, 4],
  labelBgStyle: {
    fill: '#fff',
    stroke: '#e2e2e2',
    strokeWidth: 1,
    borderRadius: 4
  },
  labelStyle: {
    fontSize: 12,
    fill: '#777',
    fontWeight: 500
  },
  selected: {
    stroke: '#3b82f6',
    strokeWidth: 3
  }
};

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
  };
}

// Export the styles
export const nodeStyles = defaultNodeStyle;
export const edgeStyles = defaultEdgeStyle;

// Add selected node styles
export const selectedNodeStyles = {
  ...nodeStyles,
  border: '2px solid #4a9eff',
  boxShadow: '0 4px 12px rgba(74, 158, 255, 0.2)'
};

// Helper function to capitalize and format state names
const formatLabel = (state: string) => {
  return state.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
};

// Generate nodes from states
const states = [...(config.places.states || []), ...(config.places.special_states || [])];
const nodes = states.map((state) => ({
  id: state.replace(' ', '_'), // Update state ID to replace spaces with underscores
  type: state === 'backlog' ? 'input' : state === 'done' ? 'output' : 'default',
  data: { 
    label: formatLabel(state),
    description: `${formatLabel(state)} state`
  },
  position: { x: 0, y: 0 }, // Initial position will be set by dagre
  style: nodeStyles
}));

// Generate edges from transitions
const allTransitions = [
  ...(config.transitions.regular || []),
  ...(config.transitions.special || [])
];

const edges: Edge[] = allTransitions.map((transition, index) => ({
  id: `e${index}`,
  source: transition.from.replace(' ', '_'), // Update source state ID to replace spaces with underscores
  target: transition.to.replace(' ', '_'), // Update target state ID to replace spaces with underscores
  label: formatLabel(transition.name),
  style: edgeStyles,
  labelStyle: edgeStyles.labelStyle,
  data: {
    requirements: transition.requires || []
  }
}));

// Create a new dagre graph
const g = new dagre.graphlib.Graph();
g.setGraph({ 
  rankdir: 'TB',  // Top to Bottom direction
  nodesep: 100,   // Horizontal separation between nodes
  ranksep: 150    // Vertical separation between ranks
});
g.setDefaultEdgeLabel(() => ({}));

// Add nodes to dagre
nodes.forEach((node) => {
  g.setNode(node.id, { width: 150, height: 50 });
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
  node.position = {
    x: nodeWithPosition.x - 75, // Center node by subtracting half the width
    y: nodeWithPosition.y - 25  // Center node by subtracting half the height
  };
});

export const initialNodes = nodes;
export const initialEdges = edges;
export const defaultViewport = { x: 0, y: 0, zoom: 1.5 }; // 150% zoom
