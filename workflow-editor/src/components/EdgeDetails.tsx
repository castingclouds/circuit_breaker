import { Edge, useNodes } from 'reactflow';
import { Card } from 'flowbite-react';
import { useState, useEffect } from 'react';

interface EdgeDetailsProps {
  edge: Edge;
  onChange: (changes: any[]) => void;
  onSave: () => Promise<boolean>;
}

export const EdgeDetails = ({ edge, onChange, onSave }: EdgeDetailsProps) => {
  const nodes = useNodes();
  const [label, setLabel] = useState(edge?.label || '');
  const [isSaving, setIsSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState('');

  // Update label state when edge changes
  useEffect(() => {
    setLabel(edge?.label || '');
  }, [edge]);

  if (!edge) {
    return (
      <div className="p-6 text-center text-gray-500">
        <p className="text-sm">Select a transition to view details</p>
      </div>
    );
  }

  const sourceNode = nodes.find(n => n.id === edge.source);
  const targetNode = nodes.find(n => n.id === edge.target);

  const handleLabelChange = (newLabel: string) => {
    setLabel(newLabel);
    onChange([{
      id: edge.id,
      label: newLabel,
      data: { label: newLabel }
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
          {label || 'Transition'}
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
              value={label}
              onChange={(e) => handleLabelChange(e.target.value)}
              className="w-full p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500 mb-4"
              placeholder="Enter transition label"
            />
            <div className="flex items-center justify-between">
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
          </div>
        </div>
      </Card>
    </div>
  );
};
