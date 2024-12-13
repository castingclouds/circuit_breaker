import { Edge, Node, useEdges } from 'reactflow';
import { Card } from 'flowbite-react';
import { initialNodes } from '../config/flowConfig';

interface NodeDetailsProps {
  node: Node | null;
  onChange: (changes: any) => void;
}

export const NodeDetails = ({ node, onChange }: NodeDetailsProps) => {
  const edges = useEdges();

  if (!node) {
    return (
      <div className="p-6 text-center text-gray-500">
        <p className="text-sm">Select a node to view details</p>
      </div>
    );
  }

  const incomingEdges = edges.filter(edge => edge.target === node.id);
  const outgoingEdges = edges.filter(edge => edge.source === node.id);

  return (
    <div className="p-6 space-y-4">
      <div className="bg-gray-100 p-4 rounded-lg border border-gray-200">
        <h3 className="text-lg font-bold text-gray-900 m-0">
          {node.data.label}
        </h3>
        <p className="text-sm text-gray-600 mt-1 mb-0">
          {node.data.description}
        </p>
      </div>

      <Card className="shadow-sm">
        <div className="space-y-6">
          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-3">
              Incoming Transitions
            </h4>
            {incomingEdges.length > 0 ? (
              <div className="space-y-2">
                {incomingEdges.map(edge => {
                  const sourceNode = initialNodes.find(n => n.id === edge.source);
                  return (
                    <div 
                      key={edge.id} 
                      className="flex items-center text-sm bg-gray-50 p-3 rounded-md hover:bg-gray-100 transition-colors"
                    >
                      <div className="flex items-center flex-1 min-w-0">
                        <span className="text-gray-600 truncate">{sourceNode?.data.label}</span>
                        <svg className="w-4 h-4 mx-2 text-gray-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                        </svg>
                        <span className="text-gray-900 font-medium truncate">{edge.label || 'Transition'}</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <p className="text-sm text-gray-500">No incoming transitions</p>
            )}
          </div>

          {incomingEdges.length > 0 && outgoingEdges.length > 0 && (
            <hr className="border-gray-200" />
          )}

          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-3">
              Outgoing Transitions
            </h4>
            {outgoingEdges.length > 0 ? (
              <div className="space-y-2">
                {outgoingEdges.map(edge => {
                  const targetNode = initialNodes.find(n => n.id === edge.target);
                  return (
                    <div 
                      key={edge.id} 
                      className="flex items-center text-sm bg-gray-50 p-3 rounded-md hover:bg-gray-100 transition-colors"
                    >
                      <div className="flex items-center flex-1 min-w-0">
                        <span className="text-gray-900 font-medium truncate">{edge.label || 'Transition'}</span>
                        <svg className="w-4 h-4 mx-2 text-gray-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                        </svg>
                        <span className="text-gray-600 truncate">{targetNode?.data.label}</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <p className="text-sm text-gray-500">No outgoing transitions</p>
            )}
          </div>
        </div>
      </Card>
    </div>
  );
};
