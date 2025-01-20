import { useState } from 'react';

interface SaveButtonProps {
  onSave: () => Promise<boolean>;
}

export function SaveButton({ onSave }: SaveButtonProps) {
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  const handleSave = async () => {
    setSaving(true);
    setMessage('');
    
    try {
      const success = await onSave();
      setMessage(success ? 'Saved successfully!' : 'Failed to save');
      setTimeout(() => setMessage(''), 3000);
    } catch (error) {
      setMessage('Error saving workflow');
      setTimeout(() => setMessage(''), 3000);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="flex flex-col items-end gap-2">
      <button
        onClick={handleSave}
        disabled={saving}
        className={`
          px-4 py-2 rounded-lg text-sm font-medium
          ${saving 
            ? 'bg-gray-300 text-gray-600 cursor-not-allowed'
            : 'bg-blue-600 text-white hover:bg-blue-700 active:bg-blue-800'
          }
          transition-colors duration-200 ease-in-out
          shadow-lg hover:shadow-xl
        `}
      >
        {saving ? 'Saving...' : 'Save Workflow'}
      </button>
      {message && (
        <div className={`
          text-sm px-3 py-1 rounded-md
          ${message.includes('success') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}
        `}>
          {message}
        </div>
      )}
    </div>
  );
}
