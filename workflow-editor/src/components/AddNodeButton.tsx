import { useState } from 'react';
import { Node } from 'reactflow';

interface AddNodeButtonProps {
  onAdd: (node: Partial<Node>) => void;
}

export function AddNodeButton({ onAdd }: AddNodeButtonProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [nodeName, setNodeName] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!nodeName.trim()) return;

    const newNode: Partial<Node> = {
      id: `${Date.now()}`,
      data: { 
        label: nodeName,
        description: 'New node description'
      },
      position: { x: 250, y: 100 },
    };

    onAdd(newNode);
    setNodeName('');
    setIsOpen(false);
  };

  return (
    <div className="absolute left-4 top-4 z-50">
      {!isOpen ? (
        <button
          onClick={() => setIsOpen(true)}
          className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Add Node
        </button>
      ) : (
        <form onSubmit={handleSubmit} className="bg-white p-4 rounded shadow-lg">
          <input
            type="text"
            value={nodeName}
            onChange={(e) => setNodeName(e.target.value)}
            placeholder="Enter node name"
            className="border p-2 rounded mb-2 w-full"
            autoFocus
          />
          <div className="flex gap-2">
            <button
              type="submit"
              className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
            >
              Add
            </button>
            <button
              type="button"
              onClick={() => setIsOpen(false)}
              className="bg-gray-500 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded"
            >
              Cancel
            </button>
          </div>
        </form>
      )}
    </div>
  );
}
