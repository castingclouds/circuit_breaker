import { Edge } from 'reactflow';
import { Card } from 'flowbite-react';
import { initialNodes } from '../config/flowConfig';

interface EdgeDetailsProps {
  edge: Edge | null;
}

export const EdgeDetails = ({ edge }: EdgeDetailsProps) => {
  if (!edge) {
    return (
      <div className="p-6 text-center text-gray-500">
        <p className="text-sm">Select an edge to view details</p>
      </div>
    );
  }

  const sourceNode = initialNodes.find(n => n.id === edge.source);
  const targetNode = initialNodes.find(n => n.id === edge.target);

  return (
    <div className="p-6">
      <div className="bg-gray-100 p-4 rounded-lg border border-gray-200 mb-4">
        <h3 className="text-lg font-bold text-gray-900 m-0">
          Transition Details
        </h3>
      </div>

      <Card className="shadow-sm">
        <div className="space-y-6">
          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-3">
              Transition Path
            </h4>
            <div className="flex items-center text-sm bg-gray-50 p-3 rounded-md">
              <div className="flex items-center flex-1 min-w-0">
                <span className="text-gray-600 truncate">{sourceNode?.data.label}</span>
                <svg className="w-4 h-4 mx-2 text-gray-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                </svg>
                <span className="text-blue-600 font-medium truncate">{edge.label}</span>
                <svg className="w-4 h-4 mx-2 text-gray-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                </svg>
                <span className="text-gray-600 truncate">{targetNode?.data.label}</span>
              </div>
            </div>
          </div>

          <div className="space-y-4">
            <div>
              <h4 className="text-sm font-semibold text-gray-700 mb-2">Source State</h4>
              <div className="bg-gray-50 p-3 rounded-md">
                <p className="text-sm text-gray-600 mb-1">
                  <span className="font-medium">Name:</span> {sourceNode?.data.label}
                </p>
                <p className="text-sm text-gray-600 m-0">
                  <span className="font-medium">Description:</span> {sourceNode?.data.description}
                </p>
              </div>
            </div>

            <div>
              <h4 className="text-sm font-semibold text-gray-700 mb-2">Target State</h4>
              <div className="bg-gray-50 p-3 rounded-md">
                <p className="text-sm text-gray-600 mb-1">
                  <span className="font-medium">Name:</span> {targetNode?.data.label}
                </p>
                <p className="text-sm text-gray-600 m-0">
                  <span className="font-medium">Description:</span> {targetNode?.data.description}
                </p>
              </div>
            </div>
          </div>

          {edge.data && Object.keys(edge.data).length > 0 && (
            <div>
              <h4 className="text-sm font-semibold text-gray-700 mb-2">Additional Properties</h4>
              <div className="bg-gray-50 p-3 rounded-md">
                <pre className="text-sm text-gray-600 whitespace-pre-wrap">
                  {JSON.stringify(edge.data, null, 2)}
                </pre>
              </div>
            </div>
          )}
        </div>
      </Card>
    </div>
  );
};
