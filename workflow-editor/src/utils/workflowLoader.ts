import { load as yamlLoad, dump as yamlDump } from 'js-yaml';
import { WorkflowDSL } from './workflowTransformer';
import { UIWorkflow } from './workflowTransformer';
import { transformDSLToUI, transformUIToDSL } from './workflowTransformer';

export const loadWorkflow = async (path: string): Promise<UIWorkflow> => {
  try {
    const response = await fetch(path);
    const yamlContent = await response.text();
    const dsl = yamlLoad(yamlContent) as WorkflowDSL;
    return transformDSLToUI(dsl);
  } catch (error) {
    console.error('Error loading workflow:', error);
    throw error;
  }
};

export const saveWorkflow = async (workflow: UIWorkflow): Promise<string> => {
  try {
    const dsl = transformUIToDSL(workflow);
    return yamlDump(dsl);
  } catch (error) {
    console.error('Error saving workflow:', error);
    throw error;
  }
};
