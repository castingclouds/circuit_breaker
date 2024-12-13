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
    if (!req.body) {
      throw new Error('No workflow data provided');
    }

    const yamlStr = dump(req.body);
    const filePath = path.resolve(__dirname, '../../src/config/workflow.yaml');
    
    console.log('Saving workflow to:', filePath);
    console.log('Workflow data:', yamlStr);

    await fs.promises.writeFile(filePath, yamlStr, 'utf8');
    console.log('Workflow saved successfully');
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
