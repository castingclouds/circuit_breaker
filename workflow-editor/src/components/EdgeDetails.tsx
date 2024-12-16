import { Edge, useNodes } from 'reactflow';
import { Card } from 'flowbite-react';
import { useState, useEffect } from 'react';

interface EdgeDetailsProps {
  edge: Edge | null;
  onChange: (changes: any[]) => void;
  onSave: () => Promise<boolean>;
}

export const EdgeDetails = ({ edge, onChange, onSave }: EdgeDetailsProps) => {
  const nodes = useNodes();
  const [label, setLabel] = useState(edge?.startLabel || '');
  const [requirements, setRequirements] = useState<string[]>(edge?.data?.requirements || []);
  const [newRequirement, setNewRequirement] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState('');

  // Update label and requirements state when edge changes
  useEffect(() => {
    setLabel(edge?.startLabel || '');
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
    onChange([{
      id: edge.id,
      startLabel: newLabel,
      data: { 
        ...edge.data,
        label: newLabel,
        requirements 
      }
    }]);
  };

  const handleAddRequirement = () => {
    if (!newRequirement.trim()) return;
    
    const updatedRequirements = [...requirements, newRequirement.trim()];
    setRequirements(updatedRequirements);
    setNewRequirement('');
    
    onChange([{
      id: edge.id,
      data: { 
        ...edge.data,
        label,
        requirements: updatedRequirements 
      }
    }]);
  };

  const handleRemoveRequirement = (index: number) => {
    const updatedRequirements = requirements.filter((_, i) => i !== index);
    setRequirements(updatedRequirements);
    
    onChange([{
      id: edge.id,
      data: { 
        ...edge.data,
        label,
        requirements: updatedRequirements 
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
              className="w-full p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Enter transition label"
            />
          </div>
          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Requirements</h4>
            <div className="space-y-2">
              {requirements.map((req, index) => (
                <div key={index} className="flex items-center justify-between bg-gray-50 p-2 rounded">
                  <span className="text-sm text-gray-700">{req}</span>
                  <button
                    onClick={() => handleRemoveRequirement(index)}
                    className="text-red-500 hover:text-red-700"
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              ))}
              <div className="flex gap-2">
                <input
                  type="text"
                  value={newRequirement}
                  onChange={(e) => setNewRequirement(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && handleAddRequirement()}
                  className="flex-1 p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="Add a requirement"
                />
                <button
                  onClick={handleAddRequirement}
                  className="bg-blue-500 text-white px-3 py-2 rounded hover:bg-blue-600 transition-colors"
                >
                  Add
                </button>
              </div>
            </div>
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
        </div>
      </Card>
    </div>
  );
};
