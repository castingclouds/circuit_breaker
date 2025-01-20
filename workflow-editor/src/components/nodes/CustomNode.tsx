import React, { memo } from 'react';
import { Handle, Position, NodeProps } from 'reactflow';
import classnames from 'classnames';

function CustomNode({ data, selected }: NodeProps) {
  return (
    <div className={classnames('react-flow__node-custom', { selected })}>
      <Handle type="target" position={Position.Top} />
      <div className="node-content">
        <div className="node-title">{data.label}</div>
        {data.description && (
          <div className="node-description">{data.description}</div>
        )}
      </div>
      <Handle type="source" position={Position.Bottom} />
    </div>
  );
}

export default memo(CustomNode);
