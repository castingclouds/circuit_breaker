import React, { memo } from 'react';
import { Handle, Position, NodeProps } from 'reactflow';

function CustomNode({ data }: NodeProps) {
  return (
    <div className="px-4 py-2 shadow-md rounded-md bg-white border border-gray-200">
      <Handle type="target" position={Position.Top} className="w-3 h-3" />
      <div className="flex flex-col">
        <div className="flex items-center">
          <div className="ml-2">
            <div className="text-lg font-bold">{data.label}</div>
            {data.description && (
              <div className="text-gray-500">{data.description}</div>
            )}
          </div>
        </div>
      </div>
      <Handle type="source" position={Position.Bottom} className="w-3 h-3" />
    </div>
  );
}

export default memo(CustomNode);
