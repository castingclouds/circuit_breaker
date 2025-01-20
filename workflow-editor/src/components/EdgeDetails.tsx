import { Edge, useNodes } from 'reactflow';
import { Card } from 'flowbite-react';
import { useState, useEffect } from 'react';

interface EdgeDetailsProps {
  edge: Edge | null;
  onChange: (edge: Edge) => void;
  onSave: () => Promise<boolean>;
}

export const EdgeDetails = ({ edge, onChange, onSave }: EdgeDetailsProps) => {
  const nodes = useNodes();
  const [label, setLabel] = useState(edge?.label || '');
  const [requirements, setRequirements] = useState<string[]>(edge?.data?.requirements || []);
  const [newRequirement, setNewRequirement] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState('');

  useEffect(() => {
    setLabel(edge?.label || '');
    setRequirements(edge?.data?.requirements || []);
  }, [edge]);

  const handleLabelChange = (newLabel: string) => {
    if (!edge) return;
    setLabel(newLabel);
    
    const updatedEdge = {
      ...edge,
      label: newLabel,
      data: {
        ...edge.data,
        requirements: requirements
      }
    };
    onChange(updatedEdge);
  };

  const handleAddRequirement = () => {
    if (!newRequirement.trim() || !edge) return;

    const updatedRequirements = [...requirements, newRequirement.trim()];
    setRequirements(updatedRequirements);
    setNewRequirement('');

    const updatedEdge = {
      ...edge,
      data: {
        ...edge.data,
        requirements: updatedRequirements
      }
    };
    onChange(updatedEdge);
  };

  const handleRemoveRequirement = (index: number) => {
    if (!edge) return;

    const updatedRequirements = requirements.filter((_, i) => i !== index);
    setRequirements(updatedRequirements);

    const updatedEdge = {
      ...edge,
      data: {
        ...edge.data,
        requirements: updatedRequirements
      }
    };
    onChange(updatedEdge);
  };

  const handleSave = async () => {
    if (!edge) return;
    
    setIsSaving(true);
    setSaveMessage('Saving...');
    
    try {
      const success = await onSave();
      if (success) {
        setSaveMessage('Saved successfully!');
        setTimeout(() => setSaveMessage(''), 2000);
      } else {
        setSaveMessage('Failed to save');
      }
    } catch (error) {
      setSaveMessage('Error saving');
      console.error('Error saving edge:', error);
    } finally {
      setIsSaving(false);
    }
  };

  if (!edge) return null;

  const sourceNode = nodes.find(node => node.id === edge.source);
  const targetNode = nodes.find(node => node.id === edge.target);

  return (
    <Card className="m-4">
      <h5 className="text-xl font-bold tracking-tight text-gray-900 dark:text-white">
        Edge Details
      </h5>
      <div className="space-y-4">
        <div>
          <p className="text-sm text-gray-500">From: {sourceNode?.data?.label || edge.source}</p>
          <p className="text-sm text-gray-500">To: {targetNode?.data?.label || edge.target}</p>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">
            Label
          </label>
          <input
            type="text"
            value={label}
            onChange={(e) => handleLabelChange(e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            placeholder="Enter edge label"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">
            Requirements
          </label>
          <div className="mt-2 space-y-2">
            {requirements.map((req, index) => (
              <div key={index} className="flex items-center space-x-2">
                <span className="text-sm">{req}</span>
                <button
                  onClick={() => handleRemoveRequirement(index)}
                  className="text-red-500 hover:text-red-700"
                >
                  ×
                </button>
              </div>
            ))}
          </div>
          <div className="mt-2 flex space-x-2">
            <input
              type="text"
              value={newRequirement}
              onChange={(e) => setNewRequirement(e.target.value)}
              className="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              placeholder="Add requirement"
              onKeyPress={(e) => {
                if (e.key === 'Enter') {
                  handleAddRequirement();
                }
              }}
            />
            <button
              onClick={handleAddRequirement}
              className="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            >
              Add
            </button>
          </div>
        </div>

        <div className="flex justify-between items-center">
          <button
            onClick={handleSave}
            disabled={isSaving}
            className="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50"
          >
            {isSaving ? 'Saving...' : 'Save'}
          </button>
          {saveMessage && (
            <span className="text-sm text-gray-500">{saveMessage}</span>
          )}
        </div>
      </div>
    </Card>
  );
};
