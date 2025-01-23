import express from 'express';
import { dump, load } from 'js-yaml';
import fs from 'fs';
import path from 'path';
import cors from 'cors';
import { fileURLToPath } from 'url';
import { YAML_HEADER } from '../config/constants';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = path.resolve(__dirname, '../..');

const app = express();
app.use(express.json());
app.use(cors());

const PORT = 3001;

// Helper function to resolve file path
const resolveFilePath = (workflowPath: string) => {
  // Remove any leading slashes and 'config' directory
  const cleanPath = workflowPath.replace(/^\/?(config\/)?/, '');
  const filePath = path.join(PROJECT_ROOT, 'src', 'config', cleanPath);
  console.log('Resolved file path:', {
    originalPath: workflowPath,
    cleanPath,
    projectRoot: PROJECT_ROOT,
    absolutePath: filePath
  });
  return filePath;
};

// Get current workflow
app.get('/api/workflow', async (req, res) => {
  try {
    console.log('GET /api/workflow - Query params:', req.query);
    
    const workflowPath = req.query.path as string;
    if (!workflowPath) {
      throw new Error('No workflow path provided');
    }

    const filePath = resolveFilePath(workflowPath);
    console.log('Attempting to read file:', filePath);
    
    if (!fs.existsSync(filePath)) {
      console.error('File does not exist:', filePath);
      return res.status(404).json({
        success: false,
        message: `Workflow file not found: ${workflowPath}`,
        resolvedPath: filePath
      });
    }
    
    const yamlContent = fs.readFileSync(filePath, 'utf8');
    console.log('Read YAML content:', yamlContent.substring(0, 100) + '...');
    
    const workflowData = load(yamlContent);
    console.log('Parsed workflow data:', workflowData);
    
    res.json(workflowData);
  } catch (error) {
    console.error('Error reading workflow:', {
      error: error.message,
      stack: error.stack,
      query: req.query
    });
    res.status(500).json({ 
      success: false, 
      message: 'Error reading workflow', 
      error: error.message,
      stack: error.stack
    });
  }
});

app.post('/api/workflow', async (req, res) => {
  try {
    console.log('POST /api/workflow - Request body:', JSON.stringify(req.body, null, 2));
    
    if (!req.body) {
      console.error('No workflow data provided');
      throw new Error('No workflow data provided');
    }

    if (!req.body.path) {
      console.error('No workflow path provided');
      throw new Error('No workflow path provided');
    }

    const workflowData = req.body.data;
    const workflowPath = req.body.path;
    console.log('Processing workflow data for path:', workflowPath);
    
    // Convert the workflow data to YAML
    const yamlContent = dump(workflowData, {
      indent: 2,
      lineWidth: -1, // Don't wrap lines
      noRefs: true,  // Don't use aliases
    });

    // Add YAML header and save to file
    const finalContent = YAML_HEADER + yamlContent;
    const filePath = resolveFilePath(workflowPath);
    console.log('Saving workflow to:', filePath);
    
    fs.writeFileSync(filePath, finalContent, 'utf8');
    console.log('Workflow saved successfully');
    
    res.json({ success: true });
  } catch (error) {
    console.error('Error saving workflow:', {
      error: error.message,
      stack: error.stack,
      body: req.body
    });
    res.status(500).json({ 
      success: false, 
      message: 'Error saving workflow', 
      error: error.message,
      stack: error.stack
    });
  }
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
  console.log('Server directory:', __dirname);
  console.log('Project root:', PROJECT_ROOT);
});

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\nGracefully shutting down server...');
  app.close(() => {
    console.log('Server shutdown complete.');
    process.exit(0);
  });
});
