import { Edge, Node, useEdges } from 'reactflow';
import { Card } from 'flowbite-react';
import { initialNodes } from '../config/flowConfig';
import { useState, useEffect } from 'react';

interface NodeDetailsProps {
  node: Node;
  onChange: (changes: any[]) => void;
  onSave: () => Promise<boolean>;
}

export const NodeDetails = ({ node, onChange, onSave }: NodeDetailsProps) => {
  const edges = useEdges();
  const [label, setLabel] = useState(node?.data?.label || '');
  const [description, setDescription] = useState(node?.data?.description || '');
  const [isSaving, setIsSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState('');

  useEffect(() => {
    setLabel(node?.data?.label || '');
    setDescription(node?.data?.description || '');
  }, [node]);

  if (!node) {
    return (
      <div className="p-6 text-center text-gray-500">
        <p className="text-sm">Select a node to view details</p>
      </div>
    );
  }

  const incomingEdges = edges.filter(edge => edge.target === node.id);
  const outgoingEdges = edges.filter(edge => edge.source === node.id);

  const handleChange = (field: string, value: string) => {
    if (field === 'label') setLabel(value);
    if (field === 'description') setDescription(value);

    onChange([{
      id: node.id,
      data: {
        ...node.data,
        [field]: value
      }
    }]);
  };

  const handleSave = async () => {
    setIsSaving(true);
    setSaveMessage('');
    try {
      const success = await onSave();
      setSaveMessage(success ? 'Changes saved!' : 'Failed to save changes');
      setTimeout(() => setSaveMessage(''), 3000);
    } catch (error) {
      setSaveMessage('Error saving changes');
      setTimeout(() => setSaveMessage(''), 3000);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="p-6 space-y-4">
      <div className="bg-gray-100 p-4 rounded-lg border border-gray-200">
        <h3 className="text-lg font-bold text-gray-900 m-0">
          {label}
        </h3>
        <p className="text-sm text-gray-600 mt-1 mb-0">
          {description}
        </p>
      </div>

      <Card className="shadow-sm">
        <div className="space-y-6">
          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Name</h4>
            <input
              type="text"
              value={label}
              onChange={(e) => handleChange('label', e.target.value)}
              className="w-full p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Enter node name"
            />
          </div>
          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Description</h4>
            <textarea
              value={description}
              onChange={(e) => handleChange('description', e.target.value)}
              className="w-full p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Enter node description"
              rows={3}
            />
          </div>

          <div className="flex items-center justify-between pt-4">
            <button
              onClick={handleSave}
              disabled={isSaving}
              className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded disabled:opacity-50"
            >
              {isSaving ? 'Saving...' : 'Save Details'}
            </button>
            {saveMessage && (
              <span className={`text-sm ${saveMessage.includes('Error') || saveMessage.includes('Failed') ? 'text-red-600' : 'text-green-600'}`}>
                {saveMessage}
              </span>
            )}
          </div>

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
