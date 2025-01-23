import React, { useState } from 'react';
import { StateDebugPanel } from './StateDebugPanel';

export function DebugToggle() {
  const [isDebugOpen, setIsDebugOpen] = useState(false);

  return (
    <>
      <button
        className="fixed bottom-4 right-[420px] bg-gray-800 text-white p-3 rounded-full shadow-lg hover:bg-gray-700 transition-colors z-50"
        onClick={() => setIsDebugOpen(!isDebugOpen)}
        title="Toggle Debug Panel"
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
          {isDebugOpen ? (
            <path d="M6 18L18 6M6 6l12 12" />
          ) : (
            <path d="M12 4v1m6 11h2m-6 0h-2v4m0-11v-4m6 6v4m2-4h-2m-4 4h-2m-4-4h-2m2-4h-2m2 4v4" />
          )}
        </svg>
      </button>
      
      <StateDebugPanel
        isOpen={isDebugOpen}
        onClose={() => setIsDebugOpen(false)}
      />
    </>
  );
}
