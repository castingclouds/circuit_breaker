import React, { useState } from 'react';
import { useStateMutations } from '../../hooks/useStateMutations';
import { useWorkflowState } from '../../hooks/useWorkflowState';
import { MutationTimeline } from './MutationTimeline';
import { JsonView } from './JsonView';

interface StateDebugPanelProps {
  isOpen: boolean;
  onClose: () => void;
}

export function StateDebugPanel({ isOpen, onClose }: StateDebugPanelProps) {
  const [activeTab, setActiveTab] = useState<'mutations' | 'current-state'>('mutations');
  const { mutations, clearMutations } = useStateMutations();
  const { state } = useWorkflowState();

  if (!isOpen) return null;

  return (
    <div className="fixed inset-y-0 right-[400px] w-[600px] bg-white border-l border-gray-200 shadow-lg flex flex-col">
      <div className="flex items-center justify-between p-4 border-b border-gray-200">
        <div className="flex space-x-4">
          <button
            className={`px-4 py-2 rounded-md ${
              activeTab === 'mutations'
                ? 'bg-blue-100 text-blue-800'
                : 'text-gray-600 hover:bg-gray-100'
            }`}
            onClick={() => setActiveTab('mutations')}
          >
            Mutations
          </button>
          <button
            className={`px-4 py-2 rounded-md ${
              activeTab === 'current-state'
                ? 'bg-blue-100 text-blue-800'
                : 'text-gray-600 hover:bg-gray-100'
            }`}
            onClick={() => setActiveTab('current-state')}
          >
            Current State
          </button>
        </div>
        <div className="flex items-center space-x-4">
          {activeTab === 'mutations' && (
            <button
              className="px-4 py-2 text-red-600 hover:bg-red-50 rounded-md"
              onClick={clearMutations}
            >
              Clear History
            </button>
          )}
          <button
            className="p-2 text-gray-500 hover:text-gray-700"
            onClick={onClose}
          >
            <svg
              className="w-6 h-6"
              fill="none"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth="2"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
      </div>
      
      <div className="flex-grow overflow-hidden">
        {activeTab === 'mutations' ? (
          <MutationTimeline mutations={mutations} />
        ) : (
          <div className="p-4 h-full overflow-y-auto">
            <JsonView data={state} expanded={true} />
          </div>
        )}
      </div>
    </div>
  );
}
