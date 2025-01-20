import { Edge, useNodes } from 'reactflow';
import { useState, useEffect } from 'react';

interface Action {
  executor: string;
  method: string;
  result: string;
}

interface EdgeDetailsProps {
  edge: Edge | null;
  onChange: (edge: Edge) => void;
  onSave: () => Promise<boolean>;
}

export const EdgeDetails = ({ edge, onChange, onSave }: EdgeDetailsProps) => {
  const nodes = useNodes();
  const [label, setLabel] = useState(edge?.label || '');
  const [requirements, setRequirements] = useState<string[]>(edge?.data?.requirements || []);
  const [actions, setActions] = useState<Action[]>(edge?.data?.actions || []);
  const [newRequirement, setNewRequirement] = useState('');
  const [newAction, setNewAction] = useState<Action>({ executor: '', method: '', result: '' });
  const [isSaving, setIsSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState('');

  useEffect(() => {
    setLabel(edge?.label || '');
    setRequirements(edge?.data?.requirements || []);
    setActions(edge?.data?.actions || []);
  }, [edge]);

  const handleLabelChange = (newLabel: string) => {
    if (!edge) return;
    setLabel(newLabel);
    
    const updatedEdge = {
      ...edge,
      label: newLabel,
      data: {
        ...edge.data,
        requirements,
        actions
      }
    };
    onChange(updatedEdge);
  };

  const handleEdgeClick = () => {
    if (!edge) return;
    onChange(edge);
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
        requirements: updatedRequirements,
        actions
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
        requirements: updatedRequirements,
        actions
      }
    };
    onChange(updatedEdge);
  };

  const handleAddAction = () => {
    if (!newAction.executor.trim() || !newAction.method.trim() || !newAction.result.trim() || !edge) return;

    const updatedActions = [...actions, { ...newAction }];
    setActions(updatedActions);
    setNewAction({ executor: '', method: '', result: '' });

    const updatedEdge = {
      ...edge,
      data: {
        ...edge.data,
        requirements,
        actions: updatedActions
      }
    };
    onChange(updatedEdge);
  };

  const handleRemoveAction = (index: number) => {
    if (!edge) return;

    const updatedActions = actions.filter((_, i) => i !== index);
    setActions(updatedActions);

    const updatedEdge = {
      ...edge,
      data: {
        ...edge.data,
        requirements,
        actions: updatedActions
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
    <div className="p-6 space-y-4">
      <div className="bg-gray-100 p-4 rounded-lg border border-gray-200">
        <h3 className="text-lg font-bold text-gray-900 m-0">
          {label || 'Transition'}
        </h3>
        <p className="text-sm text-gray-600 mt-1 mb-0">
          From {sourceNode?.data?.label || edge.source} to {targetNode?.data?.label || edge.target}
        </p>
      </div>

      <div className="shadow-sm">
        <div className="space-y-6">
          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Name</h4>
            <input
              type="text"
              value={label}
              onChange={(e) => handleLabelChange(e.target.value)}
              className="w-full p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Enter transition name"
            />
          </div>

          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Requirements</h4>
            <div className="space-y-2">
              {requirements.map((req, index) => (
                <div key={index} className="flex items-center justify-between bg-gray-50 p-3 rounded-md">
                  <span className="text-sm text-gray-900">{req}</span>
                  <button
                    onClick={() => handleRemoveRequirement(index)}
                    className="text-red-500 hover:text-red-700 focus:outline-none"
                  >
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              ))}
            </div>
            <div className="mt-2 flex space-x-2">
              <input
                type="text"
                value={newRequirement}
                onChange={(e) => setNewRequirement(e.target.value)}
                className="flex-1 p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Add requirement"
                onKeyPress={(e) => {
                  if (e.key === 'Enter') {
                    handleAddRequirement();
                  }
                }}
              />
              <button
                onClick={handleAddRequirement}
                className="bg-blue-600 hover:bg-blue-700 active:bg-blue-800 text-white font-bold py-2 px-4 rounded transition-colors duration-200 ease-in-out"
              >
                Add
              </button>
            </div>
          </div>

          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Actions</h4>
            <div className="space-y-2">
              {actions.map((action, index) => (
                <div key={index} className="flex items-center justify-between bg-gray-50 p-3 rounded-md">
                  <span className="text-sm text-gray-900">
                    {action.executor}.{action.method} → {action.result}
                  </span>
                  <button
                    onClick={() => handleRemoveAction(index)}
                    className="text-red-500 hover:text-red-700 focus:outline-none"
                  >
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              ))}
            </div>
            <div className="mt-2 space-y-2">
              <div className="flex space-x-2">
                <input
                  type="text"
                  value={newAction.executor}
                  onChange={(e) => setNewAction({ ...newAction, executor: e.target.value })}
                  className="flex-1 p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="Executor"
                />
                <input
                  type="text"
                  value={newAction.method}
                  onChange={(e) => setNewAction({ ...newAction, method: e.target.value })}
                  className="flex-1 p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="Method"
                />
                <input
                  type="text"
                  value={newAction.result}
                  onChange={(e) => setNewAction({ ...newAction, result: e.target.value })}
                  className="flex-1 p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="Result"
                />
              </div>
              <button
                onClick={handleAddAction}
                className="w-full bg-blue-600 hover:bg-blue-700 active:bg-blue-800 text-white font-bold py-2 px-4 rounded transition-colors duration-200 ease-in-out"
              >
                Add Action
              </button>
            </div>
          </div>

          <div className="flex items-center justify-between pt-4">
            <button
              onClick={handleSave}
              disabled={isSaving}
              className="bg-blue-600 hover:bg-blue-700 active:bg-blue-800 text-white font-bold py-2 px-4 rounded disabled:opacity-50 transition-colors duration-200 ease-in-out shadow-lg hover:shadow-xl"
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
    </div>
  );
};
