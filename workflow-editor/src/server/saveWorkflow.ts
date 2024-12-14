import express from 'express';
import { dump } from 'js-yaml';
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

app.post('/api/save-workflow', async (req, res) => {
  try {
    console.log('Received save workflow request');
    
    if (!req.body) {
      console.error('No workflow data provided');
      throw new Error('No workflow data provided');
    }

    const workflowData = req.body;
    
    // Convert the workflow data to YAML
    const yamlContent = dump(workflowData, {
      indent: 2,
      lineWidth: -1, // Don't wrap lines
      noRefs: true,  // Don't use aliases
    });

    // Add YAML header and save
    const fullContent = YAML_HEADER + yamlContent;
    const filePath = path.resolve(__dirname, '../../', WORKFLOW_PATH);
    fs.writeFileSync(filePath, fullContent, 'utf8');

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
