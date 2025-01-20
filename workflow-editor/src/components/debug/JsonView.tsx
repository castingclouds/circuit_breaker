import React, { useState } from 'react';

interface JsonViewProps {
  data: any;
  expanded?: boolean;
  level?: number;
  label?: string;
}

export function JsonView({ data, expanded = false, level = 0, label }: JsonViewProps) {
  const [isExpanded, setIsExpanded] = useState(expanded);
  const indent = '  '.repeat(level);

  if (data === null) return <span className="text-gray-500">null</span>;
  if (data === undefined) return <span className="text-gray-500">undefined</span>;

  if (Array.isArray(data)) {
    if (data.length === 0) return <span className="text-gray-500">[]</span>;
    
    return (
      <div>
        {label && <span className="text-blue-600">{label}: </span>}
        <span
          className="cursor-pointer text-gray-600 hover:text-gray-800"
          onClick={() => setIsExpanded(!isExpanded)}
        >
          [{data.length}] {isExpanded ? '▼' : '▶'}
        </span>
        {isExpanded && (
          <div className="ml-4">
            {data.map((item, index) => (
              <div key={index}>
                <JsonView data={item} level={level + 1} label={`${index}`} />
              </div>
            ))}
          </div>
        )}
      </div>
    );
  }

  if (typeof data === 'object') {
    const entries = Object.entries(data);
    if (entries.length === 0) return <span className="text-gray-500">{}</span>;

    return (
      <div>
        {label && <span className="text-blue-600">{label}: </span>}
        <span
          className="cursor-pointer text-gray-600 hover:text-gray-800"
          onClick={() => setIsExpanded(!isExpanded)}
        >
          {isExpanded ? '▼' : '▶'}
        </span>
        {isExpanded && (
          <div className="ml-4">
            {entries.map(([key, value]) => (
              <div key={key}>
                <JsonView data={value} level={level + 1} label={key} />
              </div>
            ))}
          </div>
        )}
      </div>
    );
  }

  return (
    <div>
      {label && <span className="text-blue-600">{label}: </span>}
      <span className={`${typeof data === 'string' ? 'text-green-600' : 'text-purple-600'}`}>
        {JSON.stringify(data)}
      </span>
    </div>
  );
}
