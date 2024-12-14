import { useState, useCallback, useEffect } from 'react';
import ReactFlow, {
  Controls,
  Background,
  Node,
  Edge,
  Connection,
  addEdge,
  updateEdge,
  MiniMap,
  useReactFlow,
  NodeChange,
  EdgeChange,
  applyNodeChanges,
  applyEdgeChanges
} from 'reactflow';
import { ReactFlowProvider } from 'reactflow';
import 'reactflow/dist/style.css';

import { SaveButton } from './components/SaveButton';
import { AddNodeButton } from './components/AddNodeButton';
import { NodeDetails } from './components/NodeDetails';
import { EdgeDetails } from './components/EdgeDetails';
import { ResizablePanel } from './components/ResizablePanel';
import { useKeyPress } from './hooks/useKeyPress';
import { saveWorkflow } from './utils/saveWorkflow';
import { initialNodes, initialEdges, nodeStyles, edgeStyles, selectedNodeStyles, defaultViewport } from './config/flowConfig';

interface FlowProps {
  onNodeSelect: (node: Node | null) => void;
  onEdgeSelect: (edge: Edge | null) => void;
  nodes: Node[];
  edges: Edge[];
  onNodesChange: (nodes: Node[]) => void;
  onEdgesChange: (edges: Edge[]) => void;
}

function Flow({ onNodeSelect, onEdgeSelect, nodes, edges, onNodesChange, onEdgesChange }: FlowProps) {
  const deletePressed = useKeyPress(['Backspace', 'Delete']);
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [selectedEdge, setSelectedEdge] = useState<Edge | null>(null);
  const { fitView } = useReactFlow();

  useEffect(() => {
    fitView({ duration: 200 });
  }, [fitView]);

  const onConnect = useCallback(
    (params: Connection) => {
      const newEdge = {
        ...params,
        id: `reactflow__edge-${params.source}-${params.target}`,
        label: 'New Transition',
        data: { label: 'New Transition' }
      };
      onEdgesChange([...edges, newEdge]);
    },
    [edges, onEdgesChange]
  );

  const onNodeClick = useCallback((_: React.MouseEvent, node: Node) => {
    setSelectedNodeId(node.id);
    setSelectedNode(node);
    setSelectedEdge(null);
    onNodeSelect(node);
    onEdgeSelect(null);
  }, [onNodeSelect, onEdgeSelect]);

  const onEdgeClick = useCallback((_: React.MouseEvent, edge: Edge) => {
    setSelectedNodeId(null);
    setSelectedNode(null);
    setSelectedEdge(edge);
    onEdgeSelect(edge);
    onNodeSelect(null);
  }, [onNodeSelect, onEdgeSelect]);

  const onPaneClick = useCallback(() => {
    setSelectedNodeId(null);
    setSelectedNode(null);
    setSelectedEdge(null);
    onNodeSelect(null);
    onEdgeSelect(null);
  }, [onNodeSelect, onEdgeSelect]);

  const onAddNode = useCallback((newNode: Partial<Node>) => {
    const node = { ...newNode, type: 'default' } as Node;
    onNodesChange([...nodes, node]);
  }, [nodes, onNodesChange]);

  const onNodesChangeHandler = useCallback(
    (changes: NodeChange[]) => {
      const updatedNodes = applyNodeChanges(changes, nodes);
      onNodesChange(updatedNodes);
    },
    [nodes, onNodesChange]
  );

  const onEdgesChangeHandler = useCallback(
    (changes: EdgeChange[]) => {
      const updatedEdges = applyEdgeChanges(changes, edges);
      onEdgesChange(updatedEdges);
    },
    [edges, onEdgesChange]
  );

  useEffect(() => {
    if (deletePressed) {
      if (selectedNodeId) {
        const updatedNodes = nodes.filter(node => node.id !== selectedNodeId);
        const updatedEdges = edges.filter(
          edge => edge.source !== selectedNodeId && edge.target !== selectedNodeId
        );
        onNodesChange(updatedNodes);
        onEdgesChange(updatedEdges);
        setSelectedNodeId(null);
        setSelectedNode(null);
        onNodeSelect(null);
      } else if (selectedEdge) {
        const updatedEdges = edges.filter(edge => edge.id !== selectedEdge.id);
        onEdgesChange(updatedEdges);
        setSelectedEdge(null);
        onEdgeSelect(null);
      }
    }
  }, [deletePressed, selectedNodeId, selectedEdge, nodes, edges, onNodeSelect, onEdgeSelect, onNodesChange, onEdgesChange]);

  useEffect(() => {
    const updatedNodes = nodes.map(node => ({
      ...node,
      style: node.id === selectedNodeId
        ? { ...selectedNodeStyles }
        : { ...nodeStyles, ...(node.customStyle || {}) }
    }));
    onNodesChange(updatedNodes);
  }, [selectedNodeId, nodes, onNodesChange]);

  return (
    <div className="flex-1 relative">
      <div className="absolute top-4 right-4 z-50">
        <SaveButton onSave={() => saveWorkflow(nodes, edges, { node: nodeStyles, edge: edgeStyles })} />
      </div>
      <div className="absolute top-4 left-4 z-50">
        <AddNodeButton onAdd={onAddNode} />
      </div>
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChangeHandler}
        onEdgesChange={onEdgesChangeHandler}
        onConnect={onConnect}
        onNodeClick={onNodeClick}
        onEdgeClick={onEdgeClick}
        onPaneClick={onPaneClick}
        edgeUpdaterRadius={10}
        edgesFocusable={true}
        edgesUpdatable={true}
        fitView
        defaultViewport={defaultViewport}
        style={{ background: '#f8fafc' }}
      >
        <Background />
        <Controls />
        <MiniMap />
      </ReactFlow>
    </div>
  );
}

function App() {
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [selectedEdge, setSelectedEdge] = useState<Edge | null>(null);
  const [nodes, setNodes] = useState<Node[]>(() => initialNodes.map(node => ({
    ...node,
    style: { ...nodeStyles, ...(node.customStyle || {}) }
  })));
  const [edges, setEdges] = useState<Edge[]>(() => initialEdges.map(edge => ({
    ...edge,
    style: { ...edgeStyles }
  })));

  const handleSave = useCallback(async () => {
    console.log('Saving workflow with nodes:', nodes);
    console.log('Saving workflow with edges:', edges);
    return await saveWorkflow(nodes, edges);
  }, [nodes, edges]);

  const onNodeChange = useCallback((changes: any[]) => {
    const change = changes[0];
    if (!change || !change.id) return;

    setNodes(nds => {
      return nds.map(node => {
        if (node.id === change.id) {
          return {
            ...node,
            data: {
              ...(node.data || {}),
              ...change.data
            }
          };
        }
        return node;
      });
    });
  }, []);

  const onEdgeChange = useCallback((changes: any[]) => {
    const change = changes[0];
    if (!change || !change.id) return;

    setEdges(eds => {
      return eds.map(edge => {
        if (edge.id === change.id) {
          return {
            ...edge,
            label: change.label,
            data: {
              ...(edge.data || {}),
              label: change.label
            }
          };
        }
        return edge;
      });
    });
  }, []);

  return (
    <div className="h-screen w-screen flex" style={{ backgroundColor: '#f8fafc' }}>
      <ReactFlowProvider>
        <Flow 
          onNodeSelect={setSelectedNode}
          onEdgeSelect={setSelectedEdge}
          nodes={nodes}
          edges={edges}
          onNodesChange={setNodes}
          onEdgesChange={setEdges}
        />
        <ResizablePanel defaultWidth={400} minWidth={350} maxWidth={800}>
          <div className="h-full bg-white border-l border-gray-200">
            {selectedNode && <NodeDetails 
              node={selectedNode} 
              onChange={onNodeChange}
              onSave={handleSave}
            />}
            {selectedEdge && <EdgeDetails 
              edge={selectedEdge} 
              onChange={onEdgeChange} 
              onSave={handleSave}
            />}
            {!selectedNode && !selectedEdge && (
              <div className="p-6 text-center text-gray-500">
                <p className="text-sm">Select a node or transition to view details</p>
              </div>
            )}
          </div>
        </ResizablePanel>
      </ReactFlowProvider>
    </div>
  );
}

export default App;
