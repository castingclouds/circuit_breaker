import { useState, useCallback, useEffect } from 'react';
import ReactFlow, {
  Controls,
  Background,
  useNodesState,
  useEdgesState,
  Node,
  Edge,
  Connection,
  addEdge,
  ReactFlowProvider,
  MiniMap,
  useKeyPress,
  updateEdge
} from 'reactflow';
import 'reactflow/dist/style.css';

import { initialNodes, initialEdges, nodeStyles, selectedNodeStyles, edgeStyles } from './config/flowConfig';
import { NodeDetails } from './components/NodeDetails';
import { EdgeDetails } from './components/EdgeDetails';
import { ResizablePanel } from './components/ResizablePanel';
import { SaveButton } from './components/SaveButton';
import { AddNodeButton } from './components/AddNodeButton';
import { saveWorkflow } from './utils/saveWorkflow';

interface FlowProps {
  onNodeSelect: (node: Node | null) => void;
  onEdgeSelect: (edge: Edge | null) => void;
}

function Flow({ onNodeSelect, onEdgeSelect }: FlowProps) {
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);
  const deletePressed = useKeyPress(['Backspace', 'Delete']);
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [selectedEdge, setSelectedEdge] = useState<Edge | null>(null);

  const onConnect = useCallback(
    (params: Connection) => setEdges((eds) => addEdge(params, eds)),
    [setEdges],
  );

  const handleSave = useCallback(async () => {
    return await saveWorkflow(nodes, edges, { node: nodeStyles, edge: edgeStyles });
  }, [nodes, edges]);

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
    setNodes((nds) => [...nds, { ...newNode, type: 'default' } as Node]);
  }, [setNodes]);

  const onEdgeUpdate = useCallback(
    (oldEdge: Edge, newConnection: Connection) => {
      setEdges((els) => updateEdge(oldEdge, newConnection, els));
    },
    [setEdges]
  );

  const onEdgeChange = useCallback((changes: any[]) => {
    const change = changes[0]; // We only handle one change at a time
    if (!change || !change.id) return;

    setEdges((eds) => {
      const newEdges = eds.map((edge) => {
        if (edge.id === change.id) {
          const updatedEdge = {
            ...edge,
            label: change.label,
            data: {
              ...edge.data,
              label: change.label
            }
          };
          // Update selected edge if this is the one being edited
          if (selectedEdge?.id === change.id) {
            setSelectedEdge(updatedEdge);
          }
          return updatedEdge;
        }
        return edge;
      });
      return newEdges;
    });

    // Save after edge change
    handleSave();
  }, [selectedEdge, handleSave]);

  // Handle node/edge deletion
  useEffect(() => {
    if (deletePressed) {
      if (selectedNodeId) {
        setNodes((nds) => nds.filter((node) => node.id !== selectedNodeId));
        // Also remove connected edges
        setEdges((eds) => eds.filter(
          (edge) => edge.source !== selectedNodeId && edge.target !== selectedNodeId
        ));
        setSelectedNodeId(null);
        setSelectedNode(null);
        onNodeSelect(null);
      } else if (selectedEdge) {
        setEdges((eds) => eds.filter((edge) => edge.id !== selectedEdge.id));
        setSelectedEdge(null);
        onEdgeSelect(null);
      }
    }
  }, [deletePressed, selectedNodeId, selectedEdge, setNodes, setEdges, onNodeSelect, onEdgeSelect]);

  // Update node styles when selection changes
  useEffect(() => {
    setNodes((nds) =>
      nds.map((node) => ({
        ...node,
        style: node.id === selectedNodeId
          ? { ...selectedNodeStyles }
          : { ...nodeStyles, ...(node.customStyle || {}) }
      }))
    );
  }, [selectedNodeId, setNodes]);

  return (
    <div className="flex-1 relative">
      <div className="absolute top-4 right-4 z-50">
        <SaveButton onSave={handleSave} />
      </div>
      <div className="absolute top-4 left-4 z-50">
        <AddNodeButton onAdd={onAddNode} />
      </div>
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        onNodeClick={onNodeClick}
        onEdgeClick={onEdgeClick}
        onPaneClick={onPaneClick}
        onEdgeUpdate={onEdgeUpdate}
        edgeUpdaterRadius={10}
        edgesFocusable={true}
        edgesUpdatable={true}
        fitView
        style={{ background: '#f8fafc' }}
      >
        <Background />
        <Controls />
        <MiniMap />
      </ReactFlow>
      <div className="h-full bg-white border-l border-gray-200">
        {selectedNode && <NodeDetails node={selectedNode} onChange={() => {}} />}
        {selectedEdge && <EdgeDetails edge={selectedEdge} onChange={onEdgeChange} />}
      </div>
    </div>
  );
}

function App() {
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [selectedEdge, setSelectedEdge] = useState<Edge | null>(null);

  return (
    <div className="h-screen w-screen flex" style={{ backgroundColor: '#f8fafc' }}>
      <ReactFlowProvider>
        <Flow 
          onNodeSelect={setSelectedNode}
          onEdgeSelect={setSelectedEdge}
        />
        <ResizablePanel defaultWidth={400} minWidth={350} maxWidth={800}>
          <div className="h-full bg-white border-l border-gray-200">
            {selectedNode && <NodeDetails node={selectedNode} onChange={() => {}} />}
            {selectedEdge && <EdgeDetails edge={selectedEdge} onChange={() => {}} />}
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
