import React, { useState, useCallback, useEffect } from 'react';

interface ResizablePanelProps {
  children: React.ReactNode;
  defaultWidth?: number;
  minWidth?: number;
  maxWidth?: number;
}

export const ResizablePanel: React.FC<ResizablePanelProps> = ({
  children,
  defaultWidth = 400,
  minWidth = 350,
  maxWidth = 800
}) => {
  const [width, setWidth] = useState(defaultWidth);
  const [isDragging, setIsDragging] = useState(false);
  const [startX, setStartX] = useState(0);
  const [startWidth, setStartWidth] = useState(width);

  const startResizing = useCallback((e: React.MouseEvent) => {
    setIsDragging(true);
    setStartX(e.pageX);
    setStartWidth(width);
  }, [width]);

  const stopResizing = useCallback(() => {
    setIsDragging(false);
  }, []);

  const resize = useCallback((e: MouseEvent) => {
    if (isDragging) {
      const diff = startX - e.pageX;
      const newWidth = Math.max(minWidth, Math.min(maxWidth, startWidth + diff));
      setWidth(newWidth);
    }
  }, [isDragging, startX, startWidth, minWidth, maxWidth]);

  useEffect(() => {
    if (isDragging) {
      document.addEventListener('mousemove', resize);
      document.addEventListener('mouseup', stopResizing);
      return () => {
        document.removeEventListener('mousemove', resize);
        document.removeEventListener('mouseup', stopResizing);
      };
    }
  }, [isDragging, resize, stopResizing]);

  return (
    <div 
      className="relative"
      style={{ 
        width: `${width}px`,
        minWidth: `${minWidth}px`,
        maxWidth: `${maxWidth}px`
      }}
    >
      <div
        className="absolute left-0 top-0 w-1 h-full cursor-ew-resize group"
        onMouseDown={startResizing}
        style={{ 
          transform: 'translateX(-50%)',
          touchAction: 'none'
        }}
      >
        <div className="absolute inset-y-0 left-1/2 w-4 -translate-x-1/2 group-hover:bg-blue-500/20 transition-colors" />
      </div>
      <div className="h-full bg-white border-l border-gray-200">
        {children}
      </div>
    </div>
  );
};
