import { Node, Edge } from 'reactflow';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3001';

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
    rules?: {
      id: string;
      description: string;
    }[];
  };
}

export const saveWorkflowToServer = async (workflowData: WorkflowData): Promise<boolean> => {
  try {
    console.log('Making request to save workflow:', {
      url: `${API_BASE_URL}/api/workflow`,
      data: workflowData
    });

    const response = await fetch(`${API_BASE_URL}/api/workflow`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(workflowData),
    });

    console.log('Server response status:', response.status);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error('Server error response:', errorText);
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const result = await response.json();
    console.log('Server response:', result);
    return result.success;
  } catch (error) {
    console.error('Error in saveWorkflowToServer:', error);
    throw error;
  }
};

export const loadWorkflowFromServer = async (): Promise<WorkflowData> => {
  try {
    const response = await fetch(`${API_BASE_URL}/api/workflow`);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    return await response.json();
  } catch (error) {
    console.error('Error loading workflow:', error);
    throw error;
  }
};
