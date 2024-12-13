import { Edge, useNodes } from 'reactflow';
import { Card } from 'flowbite-react';

interface EdgeDetailsProps {
  edge: Edge;
  onChange: (changes: any[]) => void;
}

export const EdgeDetails = ({ edge, onChange }: EdgeDetailsProps) => {
  const nodes = useNodes();

  if (!edge) {
    return (
      <div className="p-6 text-center text-gray-500">
        <p className="text-sm">Select a transition to view details</p>
      </div>
    );
  }

  const sourceNode = nodes.find(n => n.id === edge.source);
  const targetNode = nodes.find(n => n.id === edge.target);

  return (
    <div className="p-6 space-y-4">
      <div className="bg-gray-100 p-4 rounded-lg border border-gray-200">
        <h3 className="text-lg font-bold text-gray-900 m-0">
          {edge.label || 'Transition'}
        </h3>
      </div>

      <Card className="shadow-sm">
        <div className="space-y-4">
          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Source</h4>
            <p className="text-sm text-gray-600">{sourceNode?.data.label}</p>
          </div>
          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Target</h4>
            <p className="text-sm text-gray-600">{targetNode?.data.label}</p>
          </div>
          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Label</h4>
            <input
              type="text"
              defaultValue={edge.label || ''}
              onBlur={(e) => {
                onChange([{
                  id: edge.id,
                  label: e.target.value
                }]);
              }}
              className="w-full p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Enter transition label"
            />
          </div>
        </div>
      </Card>
    </div>
  );
};
