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

  // Update label and requirements state when edge changes
  useEffect(() => {
    setLabel(edge?.label || '');
    setRequirements(edge?.data?.requirements || []);
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
    if (!edge) return;
    
    const updatedEdge: Edge = {
      ...edge,
      label: newLabel,
      data: {
        ...edge.data,
        label: newLabel
      }
    };
    onChange(updatedEdge);
  };

  const handleAddRequirement = () => {
    if (!newRequirement.trim() || !edge) return;
    
    const updatedRequirements = [...requirements, newRequirement.trim()];
    setRequirements(updatedRequirements);
    setNewRequirement('');
    
    const updatedEdge: Edge = {
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
    
    const updatedEdge: Edge = {
      ...edge,
      data: {
        ...edge.data,
        requirements: updatedRequirements
      }
    };
    onChange(updatedEdge);
  };

  const handleSave = async () => {
    setIsSaving(true);
    setSaveMessage('');
    try {
      const success = await onSave();
      if (success) {
        setSaveMessage('Changes saved successfully!');
        setTimeout(() => setSaveMessage(''), 3000);
      }
    } catch (error) {
      setSaveMessage('Error saving changes');
    }
    setIsSaving(false);
  };

  return (
    <Card className="p-4">
      <h5 className="text-xl font-bold mb-4">Transition Details</h5>
      
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700 mb-1">
          From
        </label>
        <div className="text-gray-900">{sourceNode?.data?.label || edge.source}</div>
      </div>

      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700 mb-1">
          To
        </label>
        <div className="text-gray-900">{targetNode?.data?.label || edge.target}</div>
      </div>

      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700 mb-1">
          Label
        </label>
        <input
          type="text"
          value={label}
          onChange={(e) => handleLabelChange(e.target.value)}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        />
      </div>

      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700 mb-1">
          Requirements
        </label>
        <div className="flex gap-2 mb-2">
          <input
            type="text"
            value={newRequirement}
            onChange={(e) => setNewRequirement(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && handleAddRequirement()}
            placeholder="Add requirement"
            className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          />
          <button
            onClick={handleAddRequirement}
            className="px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600"
          >
            Add
          </button>
        </div>
        <ul className="space-y-2">
          {requirements.map((req, index) => (
            <li key={index} className="flex justify-between items-center bg-gray-50 p-2 rounded">
              <span>{req}</span>
              <button
                onClick={() => handleRemoveRequirement(index)}
                className="text-red-500 hover:text-red-600"
              >
                Remove
              </button>
            </li>
          ))}
        </ul>
      </div>

      {saveMessage && (
        <div className={`text-sm ${saveMessage.includes('Error') ? 'text-red-500' : 'text-green-500'}`}>
          {saveMessage}
        </div>
      )}
    </Card>
  );
};
