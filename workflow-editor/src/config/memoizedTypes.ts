import CustomNode from '../components/nodes/CustomNode';
import CustomEdge from '../components/edges/CustomEdge';
import { MarkerType } from 'reactflow';

// Define node types as a constant
export const nodeTypes = {
  custom: CustomNode,
};

// Define edge types as a constant
export const edgeTypes = {
  custom: CustomEdge,
};

// Define default edge options as a constant
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
