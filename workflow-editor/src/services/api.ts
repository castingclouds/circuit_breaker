import { Node, Edge } from 'reactflow';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3001';

// Helper to resolve workflow path
const resolveWorkflowPath = (path: string): string => {
  // Clean the path to just the filename if it's in the config directory
  const cleanPath = path.replace(/^\/?(config\/)?/, '');
  console.log('Resolved workflow path:', {
    original: path,
    cleaned: cleanPath
  });
  return cleanPath;
};

interface WorkflowData {
  object_type: string;
  places: {
    states: string[];
    special_states?: string[];
  };
  transitions: {
    regular: {
      name: string;
      from: string;
      to: string;
      requires?: string[];
    }[];
    special?: {
      name: string;
      from: string;
      to: string;
      requires?: string[];
    }[];
  };
  metadata?: {
    states?: {
      [key: string]: {
        label?: string;
        description?: string;
      };
    };
    rules?: {
      id: string;
      description: string;
    }[];
  };
}

export const saveWorkflowToServer = async (workflowPath: string, workflowData: WorkflowData): Promise<boolean> => {
  try {
    const resolvedPath = resolveWorkflowPath(workflowPath);
    console.log('Making request to save workflow:', {
      url: `${API_BASE_URL}/api/workflow`,
      path: resolvedPath,
      data: workflowData
    });

    const response = await fetch(`${API_BASE_URL}/api/workflow`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        path: resolvedPath,
        data: workflowData
      }),
    });

    console.log('Server response status:', response.status);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error('Error saving workflow:', errorText);
      return false;
    }

    return true;
  } catch (error) {
    console.error('Error saving workflow:', error);
    return false;
  }
};

export const loadWorkflowFromServer = async (workflowPath: string): Promise<WorkflowData> => {
  try {
    const resolvedPath = resolveWorkflowPath(workflowPath);
    const url = `${API_BASE_URL}/api/workflow?path=${encodeURIComponent(resolvedPath)}`;
    console.log('Loading workflow from:', url);
    
    const response = await fetch(url);
    if (!response.ok) {
      const errorText = await response.text();
      console.error('Error loading workflow:', errorText);
      throw new Error(`Failed to load workflow: ${response.statusText}`);
    }
    
    const data = await response.json();
    console.log('Loaded workflow data:', data);
    return data;
  } catch (error) {
    console.error('Error loading workflow:', error);
    throw error;
  }
};
