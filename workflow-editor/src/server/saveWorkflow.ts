import express from 'express';
import { dump, load } from 'js-yaml';
import fs from 'fs';
import path from 'path';
import cors from 'cors';
import { fileURLToPath } from 'url';
import { WORKFLOW_PATH, YAML_HEADER } from '../config/constants';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(express.json());
app.use(cors());

const PORT = 3001;

// Get current workflow
app.get('/api/workflow', async (req, res) => {
  try {
    const filePath = path.resolve(__dirname, '../../', WORKFLOW_PATH);
    const yamlContent = fs.readFileSync(filePath, 'utf8');
    const workflowData = load(yamlContent);
    res.json(workflowData);
  } catch (error) {
    console.error('Error reading workflow:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error reading workflow', 
      error: error.message 
    });
  }
});

app.post('/api/workflow', async (req, res) => {
  try {
    console.log('Received save workflow request with data:', JSON.stringify(req.body, null, 2));
    
    if (!req.body) {
      console.error('No workflow data provided');
      throw new Error('No workflow data provided');
    }

    const workflowData = req.body;
    console.log('Processing workflow data...');
    
    // Convert the workflow data to YAML
    const yamlContent = dump(workflowData, {
      indent: 2,
      lineWidth: -1, // Don't wrap lines
      noRefs: true,  // Don't use aliases
    });
    console.log('Generated YAML content:', yamlContent);

    // Add YAML header and save
    const fullContent = YAML_HEADER + yamlContent;
    const filePath = path.resolve(__dirname, '../../', WORKFLOW_PATH);
    console.log('Saving to file:', filePath);
    
    // Create a backup of the current file
    if (fs.existsSync(filePath)) {
      const backupPath = `${filePath}.backup`;
      fs.copyFileSync(filePath, backupPath);
      console.log('Created backup at:', backupPath);
    }
    
    // Save the new content
    fs.writeFileSync(filePath, fullContent, 'utf8');
    console.log('Successfully wrote file');

    console.log('Workflow saved successfully');
    res.json({ success: true, message: 'Workflow saved successfully' });
  } catch (error) {
    console.error('Error saving workflow:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error saving workflow', 
      error: error.message 
    });
  }
});

const server = app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\nGracefully shutting down server...');
  server.close(() => {
    console.log('Server shutdown complete.');
    process.exit(0);
  });
});
