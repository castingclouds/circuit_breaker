import express from 'express';
import { dump } from 'js-yaml';
import fs from 'fs';
import path from 'path';
import cors from 'cors';
import { fileURLToPath } from 'url';

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

    console.log('Request body:', JSON.stringify(req.body, null, 2));

    // Ensure all edges have a label property
    if (req.body.edges) {
      console.log('Processing edges on server side');
      req.body.edges = req.body.edges.map(edge => {
        console.log('Processing edge:', edge);
        return {
          ...edge,
          label: edge.label || ''  // Ensure label exists
        };
      });
      console.log('Processed edges:', req.body.edges);
    }

    console.log('Generating YAML string...');
    const yamlStr = dump(req.body, {
      indent: 2,
      lineWidth: -1,  // No line wrapping
      noRefs: true    // Don't use aliases
    });
    
    const filePath = path.resolve(__dirname, '../../src/config/workflow.yaml');
    
    console.log('Saving workflow to:', filePath);
    console.log('YAML content to write:', yamlStr);

    await fs.promises.writeFile(filePath, yamlStr, 'utf8');
    console.log('Workflow saved successfully');

    // Verify the file was written
    const written = await fs.promises.readFile(filePath, 'utf8');
    console.log('Verification - File contents after save:', written);

    res.json({ success: true });
  } catch (error) {
    console.error('Error saving workflow:', error);
    res.status(500).json({ 
      success: false, 
      error: String(error),
      stack: error instanceof Error ? error.stack : undefined 
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
