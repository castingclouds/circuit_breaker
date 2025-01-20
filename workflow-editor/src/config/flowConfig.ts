import { Edge, Node, MarkerType } from 'reactflow';
import CustomNode from '../components/nodes/CustomNode';
import CustomEdge from '../components/edges/CustomEdge';
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

// Node types
export const nodeTypes = {
  custom: CustomNode,
};

// Edge types
export const edgeTypes = {
  custom: CustomEdge,
};

// Default edge options
export const defaultEdgeOptions = {
  type: 'custom',
  animated: false,
  style: {
    stroke: '#000000',
    strokeWidth: 1,
    radius: 20,
  },
  markerEnd: {
    type: MarkerType.ArrowClosed,
    width: 16,
    height: 16,
    color: '#000000',
  },
};

// Default edge options for new connections
export const newEdgeOptions = {
  type: 'custom',
  style: {
    stroke: '#000000',
    strokeWidth: 1,
    radius: 20,
  },
  markerEnd: {
    type: MarkerType.ArrowClosed,
    width: 16,
    height: 16,
    color: '#000000',
  },
};

// Default styles
export const nodeStyles = {

  border: '1px solid #ddd',
  backgroundColor: '#fff',
  width: 150,
  fontSize: 14,
  color: '#333',
  fontWeight: 500,
  transition: '0.2s',
  boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
};

// Selected node styles
export const selectedNodeStyles = {
  ...nodeStyles,
  border: '2px solid #3b82f6',
  boxShadow: '0 0 0 2px rgba(59, 130, 246, 0.5)'
};

// Edge styles
export const edgeStyles = {
  stroke: '#000000',
  strokeWidth: 1,
  radius: 20,
  labelStyle: {
    fontSize: 14,
    fill: '#000000',
    fontWeight: 500,
  },
  markerEnd: {
    type: MarkerType.ArrowClosed,
    width: 16,
    height: 16,
    color: '#000000',
  },
};

// Node spacing configuration
export const nodeSpacing = {
  rankdir: 'TB',
  nodesep: 100,
  ranksep: 150,
};

// Helper function to capitalize and format state names
const formatLabel = (state: string) => {
  return state.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
};

// Generate nodes from states
const states = [...(config.places.states || []), ...(config.places.special_states || [])];
const nodes: Node[] = states.map((state, index) => ({
  id: state.replace(/\s+/g, '_'), // Replace all whitespace with underscores
  type: 'custom',
  position: { x: 0, y: index * 100 }, // Give initial positions before dagre layout
  data: { 
    label: formatLabel(state),
    description: `${formatLabel(state)} state`
  },
  style: nodeStyles
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
  style: edgeStyles,
  data: {
    requirements: transition.requires || []
  },
}));

// Create a new dagre graph
const g = new dagre.graphlib.Graph();
g.setGraph({ 
  rankdir: nodeSpacing.rankdir,
  nodesep: nodeSpacing.nodesep,
  ranksep: nodeSpacing.ranksep
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
