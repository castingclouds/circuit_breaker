import path from 'path';

// This is used for server-side file operations
export const WORKFLOW_FILE = 'workflow.yaml';
export const WORKFLOW_PATH = path.join('src', 'config', WORKFLOW_FILE);

// Add a YAML header when saving
export const YAML_HEADER = '---\n';

// Note: For client-side imports, we must use the hardcoded path:
// import workflowConfig from './workflow.yaml';
