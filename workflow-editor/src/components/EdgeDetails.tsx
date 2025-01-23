import { Edge, useNodes } from 'reactflow';
import { useState, useEffect } from 'react';

interface Action {
  executor: {
    name: string;
    method: string;
    result: string;
  }[];
}

interface Policy {
  all?: string[];
  any?: string[];
}

interface EdgeDetailsProps {
  edge: Edge | null;
  onChange: (edge: Edge) => void;
  onSave: () => Promise<boolean>;
}

export const EdgeDetails = ({ edge, onChange, onSave }: EdgeDetailsProps) => {
  const nodes = useNodes();
  const [label, setLabel] = useState(edge?.label || '');
  const [policy, setPolicy] = useState<Policy>(edge?.data?.policy || {});
  const [actions, setActions] = useState<Action[]>(edge?.data?.actions || []);
  const [newRequirement, setNewRequirement] = useState('');
  const [requirementType, setRequirementType] = useState<'all' | 'any'>('all');
  const [newAction, setNewAction] = useState({
    name: '',
    method: '',
    result: ''
  });
  const [isSaving, setIsSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState('');

  useEffect(() => {
    setLabel(edge?.label || '');
    setPolicy(edge?.data?.policy || {});
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
        policy,
        actions
      }
    };
    onChange(updatedEdge);
  };

  const handleAddRequirement = () => {
    if (!newRequirement.trim() || !edge) return;

    const updatedPolicy = {
      ...policy,
      [requirementType]: [...(policy[requirementType] || []), newRequirement.trim()]
    };
    setPolicy(updatedPolicy);
    setNewRequirement('');

    const updatedEdge = {
      ...edge,
      data: {
        ...edge.data,
        policy: updatedPolicy,
        actions
      }
    };
    onChange(updatedEdge);
  };

  const handleRemoveRequirement = (type: 'all' | 'any', index: number) => {
    if (!edge) return;

    const updatedPolicy = {
      ...policy,
      [type]: policy[type]?.filter((_, i) => i !== index)
    };
    setPolicy(updatedPolicy);

    const updatedEdge = {
      ...edge,
      data: {
        ...edge.data,
        policy: updatedPolicy,
        actions
      }
    };
    onChange(updatedEdge);
  };

  const handleAddAction = () => {
    if (!newAction.name.trim() || !newAction.method.trim() || !newAction.result.trim() || !edge) return;

    const updatedActions = [...actions, {
      executor: [{
        name: newAction.name.trim(),
        method: newAction.method.trim(),
        result: newAction.result.trim()
      }]
    }];
    setActions(updatedActions);
    setNewAction({ name: '', method: '', result: '' });

    const updatedEdge = {
      ...edge,
      data: {
        ...edge.data,
        policy,
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
        policy,
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
      <div className="bg-gray-100 p-4 rounded-lg border border-gray-400">
        <h5 className="text-xs uppercase tracking-wide font-semibold text-gray-500 m-0">TRANSITION</h5>
        <h3 className="text-2xl font-bold text-gray-900 m-0">
          {label}
        </h3>
        <p className="text-sm text-gray-600 mt-1">
          {sourceNode?.data?.label} → {targetNode?.data?.label}
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
            <h4 className="text-sm font-semibold text-gray-900 mb-2">Policy Requirements</h4>
            
            {/* All Requirements */}
            <div className="mb-4">
              <h5 className="text-sm font-medium text-gray-700 mb-2">All Requirements</h5>
              <div className="space-y-2">
                {policy.all?.map((req, index) => (
                  <div key={index} className="flex items-center justify-between bg-gray-50 p-3 rounded-md">
                    <span className="text-sm text-gray-900">{req}</span>
                    <button
                      onClick={() => handleRemoveRequirement('all', index)}
                      className="text-red-500 hover:text-red-700 focus:outline-none"
                    >
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                ))}
              </div>
            </div>

            {/* Any Requirements */}
            <div className="mb-4">
              <h5 className="text-sm font-medium text-gray-700 mb-2">Any Requirements</h5>
              <div className="space-y-2">
                {policy.any?.map((req, index) => (
                  <div key={index} className="flex items-center justify-between bg-gray-50 p-3 rounded-md">
                    <span className="text-sm text-gray-900">{req}</span>
                    <button
                      onClick={() => handleRemoveRequirement('any', index)}
                      className="text-red-500 hover:text-red-700 focus:outline-none"
                    >
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                ))}
              </div>
            </div>

            {/* Add New Requirement */}
            <div className="mt-2 flex space-x-2">
              <select
                value={requirementType}
                onChange={(e) => setRequirementType(e.target.value as 'all' | 'any')}
                className="p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="all">All</option>
                <option value="any">Any</option>
              </select>
              <input
                type="text"
                value={newRequirement}
                onChange={(e) => setNewRequirement(e.target.value)}
                className="flex-1 p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Enter requirement"
              />
              <button
                onClick={handleAddRequirement}
                className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
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
                  <div className="flex-1">
                    <p className="text-sm font-semibold text-gray-900">{action.executor[0].name}</p>
                    
                    <span className="text-xs uppercase text-gray-500">
                      Method:  &nbsp;
                    </span>
                    <span className="text-sm font-semibold text-gray-500">
                      {action.executor[0].method}
                    </span>
                    <p></p>
                    <span className="text-xs uppercase text-gray-500">
                      Result: &nbsp;
                    </span>
                    <span className="text-sm font-semibold text-gray-500">
                      {action.executor[0].result}
                    </span>
                  </div>
                  <button
                    onClick={() => handleRemoveAction(index)}
                    className="text-red-500 hover:text-red-700 focus:outline-none ml-2"
                  >
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              ))}
            </div>
            <div className="mt-2 space-y-2">
              <input
                type="text"
                value={newAction.name}
                onChange={(e) => setNewAction({ ...newAction, name: e.target.value })}
                className="w-full p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Executor name"
              />
              <input
                type="text"
                value={newAction.method}
                onChange={(e) => setNewAction({ ...newAction, method: e.target.value })}
                className="w-full p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Method"
              />
              <input
                type="text"
                value={newAction.result}
                onChange={(e) => setNewAction({ ...newAction, result: e.target.value })}
                className="w-full p-2 text-sm border rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Result"
              />
              <button
                onClick={handleAddAction}
                className="w-full px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              >
                Add Action
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="mt-4 flex items-center justify-between">
        <button
          onClick={handleSave}
          disabled={isSaving}
          className="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 disabled:opacity-50"
        >
          {isSaving ? 'Saving...' : 'Save'}
        </button>
        {saveMessage && (
          <span className={`text-sm ${saveMessage.includes('Error') || saveMessage.includes('Failed') ? 'text-red-500' : 'text-green-500'}`}>
            {saveMessage}
          </span>
        )}
      </div>
    </div>
  );
};
