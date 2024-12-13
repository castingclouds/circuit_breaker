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
  MiniMap
} from 'reactflow';
import 'reactflow/dist/style.css';

import { initialNodes, initialEdges, nodeStyles, selectedNodeStyles } from './config/flowConfig';
import { NodeDetails } from './components/NodeDetails';
import { EdgeDetails } from './components/EdgeDetails';
import { ResizablePanel } from './components/ResizablePanel';

function App() {
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [selectedEdge, setSelectedEdge] = useState<Edge | null>(null);

  const onConnect = useCallback(
    (params: Connection) => setEdges((eds) => addEdge(params, eds)),
    [setEdges],
  );

  const onNodeClick = useCallback((_: React.MouseEvent, node: Node) => {
    setSelectedNode(node);
    setSelectedEdge(null);
  }, []);

  const onEdgeClick = useCallback((_: React.MouseEvent, edge: Edge) => {
    setSelectedEdge(edge);
    setSelectedNode(null);
  }, []);

  useEffect(() => {
    setNodes((nds) =>
      nds.map((node) => ({
        ...node,
        style: node.id === selectedNode?.id 
          ? { ...selectedNodeStyles }
          : { ...nodeStyles, ...(node.id === '8' ? { backgroundColor: '#fff1f0' } : {}) }
      }))
    );
  }, [selectedNode, setNodes]);

  return (
    <div className="h-screen w-screen flex" style={{ backgroundColor: '#f8fafc' }}>
      <ReactFlowProvider>
        <div className="flex-1" style={{ position: 'relative' }}>
          <ReactFlow
            nodes={nodes}
            edges={edges}
            onNodesChange={onNodesChange}
            onEdgesChange={onEdgesChange}
            onConnect={onConnect}
            onNodeClick={onNodeClick}
            onEdgeClick={onEdgeClick}
            fitView
            style={{ background: '#f8fafc' }}
          >
            <Background color="#e2e8f0" gap={16} />
            <Controls />
            <MiniMap />
          </ReactFlow>
        </div>

        <ResizablePanel defaultWidth={400} minWidth={350} maxWidth={800}>
          <div style={{
            height: '100%',
            backgroundColor: '#f8fafc',
            overflowY: 'auto',
            borderLeft: '1px solid #e1e4e8'
          }}>
            {selectedNode && <NodeDetails node={selectedNode} edges={edges} />}
            {selectedEdge && <EdgeDetails edge={selectedEdge} nodes={nodes} />}
            {!selectedNode && !selectedEdge && (
              <div style={{ padding: '24px', textAlign: 'center', color: '#666' }}>
                <p style={{ fontSize: '14px' }}>Select a node or transition to view details</p>
              </div>
            )}
          </div>
        </ResizablePanel>
      </ReactFlowProvider>
    </div>
  );
}

export default App;
