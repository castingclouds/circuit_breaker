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
    <div className="absolute top-4 right-4 z-50">
      <button
        onClick={handleSave}
        disabled={saving}
        className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded disabled:opacity-50"
      >
        {saving ? 'Saving...' : 'Save Workflow'}
      </button>
      {message && (
        <div className={`mt-2 p-2 rounded text-sm ${
          message.includes('success') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
        }`}>
          {message}
        </div>
      )}
    </div>
  );
}
