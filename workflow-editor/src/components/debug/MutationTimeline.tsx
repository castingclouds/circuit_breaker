import React, { useState } from 'react';
import { StateMutation } from '../../state/mutations/types';
import { JsonView } from './JsonView';

interface MutationTimelineProps {
  mutations: StateMutation[];
  onSelectMutation?: (mutation: StateMutation) => void;
}

const mutationTypeColors: Record<string, string> = {
  STATE_CHANGE: 'bg-blue-100 border-blue-300',
  TRANSITION: 'bg-green-100 border-green-300',
  VALIDATION_ADDED: 'bg-yellow-100 border-yellow-300',
  VALIDATION_CLEARED: 'bg-yellow-100 border-yellow-300',
  TRANSITION_ADDED: 'bg-purple-100 border-purple-300',
  TRANSITION_REMOVED: 'bg-red-100 border-red-300',
  METADATA_UPDATED: 'bg-gray-100 border-gray-300'
};

export function MutationTimeline({ mutations, onSelectMutation }: MutationTimelineProps) {
  const [selectedMutation, setSelectedMutation] = useState<StateMutation | null>(null);
  const [filter, setFilter] = useState<string>('');

  const handleMutationClick = (mutation: StateMutation) => {
    setSelectedMutation(mutation);
    onSelectMutation?.(mutation);
  };

  const filteredMutations = mutations.filter(mutation =>
    filter ? mutation.type.toLowerCase().includes(filter.toLowerCase()) : true
  );

  return (
    <div className="flex h-full">
      <div className="w-1/2 overflow-y-auto border-r border-gray-200 p-4">
        <div className="mb-4">
          <input
            type="text"
            placeholder="Filter by type..."
            className="w-full px-3 py-2 border rounded-md"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
          />
        </div>
        <div className="space-y-2">
          {filteredMutations.map((mutation) => (
            <div
              key={mutation.id}
              className={`p-3 border rounded-md cursor-pointer transition-colors
                ${mutationTypeColors[mutation.type] || 'bg-gray-100 border-gray-300'}
                ${selectedMutation?.id === mutation.id ? 'ring-2 ring-blue-500' : ''}
              `}
              onClick={() => handleMutationClick(mutation)}
            >
              <div className="flex justify-between items-start">
                <div>
                  <span className="font-medium">{mutation.type}</span>
                  <div className="text-sm text-gray-600">
                    Path: {mutation.path.join(' > ')}
                  </div>
                </div>
                <div className="text-xs text-gray-500">
                  {new Date(mutation.timestamp).toLocaleTimeString()}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
      <div className="w-1/2 p-4 overflow-y-auto">
        {selectedMutation ? (
          <div className="space-y-4">
            <div>
              <h3 className="text-lg font-medium mb-2">Previous Value</h3>
              <div className="p-3 bg-gray-50 rounded-md">
                <JsonView data={selectedMutation.previousValue} />
              </div>
            </div>
            <div>
              <h3 className="text-lg font-medium mb-2">New Value</h3>
              <div className="p-3 bg-gray-50 rounded-md">
                <JsonView data={selectedMutation.newValue} />
              </div>
            </div>
            {selectedMutation.metadata && (
              <div>
                <h3 className="text-lg font-medium mb-2">Metadata</h3>
                <div className="p-3 bg-gray-50 rounded-md">
                  <JsonView data={selectedMutation.metadata} />
                </div>
              </div>
            )}
          </div>
        ) : (
          <div className="h-full flex items-center justify-center text-gray-500">
            Select a mutation to view details
          </div>
        )}
      </div>
    </div>
  );
}
