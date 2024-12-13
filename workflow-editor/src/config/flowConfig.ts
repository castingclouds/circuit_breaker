import { Edge } from 'reactflow';
import workflowConfig from './workflow.yaml';

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
  transition: string;
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
}

// Export the styles from the YAML config
export const nodeStyles: NodeStyle = config.styles.node;
export const edgeStyles: EdgeStyle = config.styles.edge;

// Add selected node styles
export const selectedNodeStyles = {
  ...nodeStyles,
  border: '2px solid #4a9eff',
  boxShadow: '0 4px 12px rgba(74, 158, 255, 0.2)'
};

// Transform the nodes to include the default styles
export const initialNodes = config.nodes.map((node: any) => ({
  ...node,
  style: {
    ...nodeStyles,
    ...(node.customStyle || {})
  }
}));

// Transform the edges to include the default styles
export const initialEdges: Edge[] = config.edges.map((edge: any) => ({
  ...edge,
  style: edgeStyles,
  labelStyle: edgeStyles.labelStyle
}));
