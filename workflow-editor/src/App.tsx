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
import { initialNodes, initialEdges, defaultViewport } from './config/flowConfig';
import { nodeTypes, edgeTypes, defaultEdgeOptions } from './config/memoizedTypes';
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
  onSave: () => Promise<boolean>;
}

function Flow({ onNodeSelect, onEdgeSelect, nodes, edges, onNodesChange, onEdgesChange, onSave }: FlowProps) {
  const deletePressed = useKeyPress(['Backspace', 'Delete']);
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [selectedEdge, setSelectedEdge] = useState<Edge | null>(null);
  const { fitView } = useReactFlow();

  // Update selected node when nodes change
  useEffect(() => {
    if (selectedNodeId) {
      const updatedNode = nodes.find(n => n.id === selectedNodeId);
      if (updatedNode && JSON.stringify(updatedNode) !== JSON.stringify(selectedNode)) {
        setSelectedNode(updatedNode);
        onNodeSelect(updatedNode);
      }
    }
  }, [nodes, selectedNodeId, selectedNode, onNodeSelect]);

  useEffect(() => {
    fitView({ duration: 200 });
  }, [fitView]);

  const onConnect = useCallback(
    (params: Connection) => {
      onEdgesChange([
        addEdge(
          {
            ...params,
            type: 'custom',
            style: {
              stroke: '#000000',
              strokeWidth: 2,
            },
            markerEnd: {
              type: MarkerType.ArrowClosed,
              width: 16,
              height: 16,
              color: '#000000',
            },
          },
          edges
        ),
      ]);
    },
    [edges, onEdgesChange]
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
      // If this is an update to the selected edge, update the selected edge state
      const updateChange = changes.find(change => change.type === 'select' || change.type === 'remove');
      if (updateChange?.type === 'remove') {
        setSelectedEdge(null);
      }
    },
    []
  );

  const onEdgeChange = useCallback((updatedEdge: Edge) => {
    // Create a change object that ReactFlow understands
    const change: EdgeChange = {
      id: updatedEdge.id,
      type: 'update',
      item: updatedEdge,
    };
    onEdgesChange([change]);
    setSelectedEdge(updatedEdge);
  }, [onEdgesChange]);

  const handleSave = useCallback(async (): Promise<boolean> => {
    try {
      const success = await saveWorkflow(nodes, edges);
      if (success) {
        console.log('Workflow saved successfully');
      } else {
        console.error('Failed to save workflow');
      }
      return success;
    } catch (error) {
      console.error('Error saving workflow:', error);
      return false;
    }
  }, [nodes, edges]);

  const onNodeChange = useCallback((changes: NodeChange[]) => {
    setNodes(nds => {
      const newNodes = nds.map(node => {
        const change = changes.find(c => c.id === node.id);
        if (change && change.type === 'update') {
          return {
            ...node,
            data: {
              ...node.data,
              ...change.data
            }
          };
        }
        return node;
      });
      return newNodes;
    });
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
