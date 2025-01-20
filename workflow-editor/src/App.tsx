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
  applyEdgeChanges,
  MarkerType
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
import { initialNodes, initialEdges, nodeStyles, edgeStyles, selectedNodeStyles, defaultViewport, nodeTypes, edgeTypes, defaultEdgeOptions } from './config/flowConfig';
import React from 'react';
import { StateProvider } from './state/StateContext';
import { DebugToggle } from './components/debug/DebugToggle';

interface FlowProps {
  onNodeSelect: (node: Node | null) => void;
  onEdgeSelect: (edge: Edge | null) => void;
  nodes: Node[];
  edges: Edge[];
  onNodesChange: (changes: NodeChange[]) => void;
  onEdgesChange: (changes: EdgeChange[]) => void;
  onSave: () => Promise<void>;
}

function Flow({ onNodeSelect, onEdgeSelect, nodes, edges, onNodesChange, onEdgesChange, onSave }: FlowProps) {
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
        data: { label: 'New Transition' },
        startLabel: 'New Transition',
        style: edgeStyles,
        markerEnd: {
          type: MarkerType.ArrowClosed,
          width: 20,
          height: 20,
          color: '#b1b1b7'
        }
      };
      onEdgesChange([addEdge(newEdge)]);
    },
    [onEdgesChange]
  );

  return (
    <div style={{ width: '100%', height: '100vh' }}>
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        onNodeClick={(_, node) => {
          setSelectedNodeId(node.id);
          setSelectedNode(node);
          onNodeSelect(node);
        }}
        onEdgeClick={(_, edge) => {
          onEdgeSelect(edge);
        }}
        fitView
        defaultViewport={defaultViewport}
        nodeTypes={nodeTypes}
        edgeTypes={edgeTypes}
        defaultEdgeOptions={defaultEdgeOptions}
      >
        <div className="absolute top-4 right-4 z-10">
          <SaveButton onSave={onSave} />
        </div>
        <Background />
        <Controls />
        <MiniMap />
      </ReactFlow>
    </div>
  );
}

function App() {
  const [nodes, setNodes] = useState<Node[]>(initialNodes);
  const [edges, setEdges] = useState<Edge[]>(initialEdges);
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [selectedEdge, setSelectedEdge] = useState<Edge | null>(null);

  const onNodesChange = useCallback(
    (changes: NodeChange[]) => {
      setNodes((nds) => applyNodeChanges(changes, nds));
    },
    []
  );

  const onEdgesChange = useCallback(
    (changes: EdgeChange[]) => {
      setEdges((eds) => applyEdgeChanges(changes, eds));
    },
    []
  );

  const handleSave = useCallback(async () => {
    try {
      await saveWorkflow(nodes, edges);
      console.log('Workflow saved successfully');
    } catch (error) {
      console.error('Error saving workflow:', error);
    }
  }, [nodes, edges]);

  const onNodeChange = useCallback((updatedNode: Node) => {
    setNodes(nds => nds.map(node => 
      node.id === updatedNode.id ? updatedNode : node
    ));
  }, []);

  const onEdgeChange = useCallback((updatedEdge: Edge) => {
    setEdges(eds => eds.map(edge => 
      edge.id === updatedEdge.id ? updatedEdge : edge
    ));
  }, []);

  return (
    <StateProvider>
      <ReactFlowProvider>
        <div className="h-screen flex">
          <div className="flex-grow relative">
            <Flow 
              onNodeSelect={setSelectedNode}
              onEdgeSelect={setSelectedEdge}
              nodes={nodes}
              edges={edges}
              onNodesChange={onNodesChange}
              onEdgesChange={onEdgesChange}
              onSave={handleSave}
            />
          </div>

          <div className="flex flex-col w-[400px] min-w-[350px] max-w-[800px] border-l border-gray-200 bg-white">
            <div className="flex-grow overflow-y-auto">
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
          </div>
          <DebugToggle />
        </div>
      </ReactFlowProvider>
    </StateProvider>
  );
}

export default App;
