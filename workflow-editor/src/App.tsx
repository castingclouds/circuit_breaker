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
import { saveWorkflowToServer } from './services/api';
import { initialNodes, initialEdges, defaultViewport, generateFlowConfig } from './config/flowConfig';
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
          setSelectedEdge(null); // Clear edge selection when node is clicked
          onNodeSelect(node);
        }}
        onEdgeClick={(_, edge) => {
          setSelectedNode(null); // Clear node selection when edge is clicked
          setSelectedNodeId(null);
          onNodeSelect(null);
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
  const [workflowPath, setWorkflowPath] = useState<string>('/config/document_workflow.yaml');

  useEffect(() => {
    // Get workflow path from URL parameters or use default from config directory
    const params = new URLSearchParams(window.location.search);
    const path = params.get('workflow');
    if (path) {
      // If path doesn't start with /config/, add it
      const fullPath = path.startsWith('/config/') ? path : `/config/${path}`;
      setWorkflowPath(fullPath);
    }
  }, []);

  useEffect(() => {
    // Load workflow when path changes
    if (workflowPath) {
      console.log('Loading workflow from:', workflowPath);
      generateFlowConfig(workflowPath).then(({ nodes: newNodes, edges: newEdges }) => {
        console.log('Loaded workflow with nodes:', newNodes.length, 'edges:', newEdges.length);
        setNodes(newNodes);
        setEdges(newEdges);
      }).catch(error => {
        console.error('Error loading workflow:', error);
      });
    }
  }, [workflowPath]);

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

  const onNodeChange = useCallback((node: Node) => {
    setNodes((nds) =>
      nds.map((n) => {
        if (n.id === node.id) {
          return node;
        }
        return n;
      })
    );
  }, []);

  const onEdgeChange = useCallback((edge: Edge) => {
    setEdges((eds) =>
      eds.map((e) => {
        if (e.id === edge.id) {
          return edge;
        }
        return e;
      })
    );
  }, []);

  const handleSave = useCallback(async (): Promise<boolean> => {
    if (!workflowPath) return false;
    try {
      const success = await saveWorkflowToServer(workflowPath, {
        object_type: 'document',
        places: {
          states: nodes.map(node => ({
            name: node.data?.label || ''
          }))
        },
        transitions: {
          regular: edges.map(edge => ({
            name: edge.label || '',
            from: nodes.find(n => n.id === edge.source)?.data?.label || '',
            to: nodes.find(n => n.id === edge.target)?.data?.label || '',
            policy: edge.data?.policy || {},
            actions: edge.data?.actions || []
          }))
        },
        metadata: {
          rules: []
        }
      });

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
  }, [nodes, edges, workflowPath]);

  const handleNodeSelect = useCallback((node: Node | null) => {
    setSelectedNode(node);
    setSelectedEdge(null); // Clear edge selection when node is selected
  }, []);

  const handleEdgeSelect = useCallback((edge: Edge | null) => {
    setSelectedEdge(edge);
    setSelectedNode(null); // Clear node selection when edge is selected
  }, []);

  return (
    <StateProvider>
      <ReactFlowProvider>
        <div className="h-screen flex">
          <div className="flex-grow relative">
            <Flow 
              onNodeSelect={handleNodeSelect}
              onEdgeSelect={handleEdgeSelect}
              nodes={nodes}
              edges={edges}
              onNodesChange={onNodesChange}
              onEdgesChange={onEdgesChange}
              onSave={handleSave}
            />
          </div>
          {(selectedNode || selectedEdge) && (
            <ResizablePanel>
              {selectedNode && (
                <NodeDetails 
                  node={selectedNode} 
                  onChange={onNodeChange}
                  onSave={handleSave}
                />
              )}
              {selectedEdge && (
                <EdgeDetails 
                  edge={selectedEdge}
                  onChange={onEdgeChange}
                  onSave={handleSave}
                />
              )}
            </ResizablePanel>
          )}
        </div>
      </ReactFlowProvider>
    </StateProvider>
  );
}

export default App;
