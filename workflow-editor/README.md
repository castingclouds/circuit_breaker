# Workflow Editor

A visual editor for creating and modifying workflow configurations using React Flow. This editor allows you to create, edit, and visualize workflow states and transitions in a user-friendly interface.

## Features

- Interactive graph visualization of workflow states and transitions
- Real-time editing of nodes (states) and edges (transitions)
- Automatic layout using the Dagre algorithm
- Details panel for editing node and edge properties
- YAML configuration file integration
- Smooth edges with directional arrows
- Support for multiple workflow configurations
- Real-time UI updates

## Getting Started

1. Install dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm start
```

This will start both the Vite development server and the backend server for handling workflow files.

## Usage Guide

### Loading Different Workflows

1. By default, the editor loads `/config/document_workflow.yaml`
2. To load a different workflow, use the URL parameter:
   ```
   http://localhost:3000?workflow=change_workflow.yaml
   ```
3. You can also use the full path:
   ```
   http://localhost:3000?workflow=/config/change_workflow.yaml
   ```

### Editing the Workflow

#### States and Transitions
- States are represented as nodes in the graph
- Transitions are represented as edges connecting the states
- The layout is automatically arranged for optimal visualization

#### Edge (Transition) Details
When a transition is selected, the details panel shows:
- Transition name (editable)
- Source and target states
- Requirements list
  - Add new requirements by typing and pressing Enter
  - Remove requirements by clicking the × button
- Changes are reflected immediately in the UI
- Click Save to persist changes to the YAML file

### Configuration Files

The editor works with YAML files in the `src/config` directory. Each workflow file follows this structure:
```yaml
object_type: string
places:
  states:
    - state1
    - state2
  special_states:
    - special_state1
transitions:
  regular:
    - name: transition_name
      from: state1
      to: state2
      requires:
        - requirement1
        - requirement2
```

### Key Files

- `src/config/*.yaml`: Workflow configuration files
- `src/App.tsx`: Main application component
- `src/components/EdgeDetails.tsx`: Edge property editor
- `src/server/saveWorkflow.ts`: Server for handling file operations
- `src/services/api.ts`: API client for server communication
- `src/config/flowConfig.ts`: Graph visualization configuration

## Development

### Architecture

- Frontend: React + Vite + TypeScript
- UI Components: React Flow + Flowbite React
- Backend: Express server for file operations
- Configuration: YAML for workflow definitions

### Server API

The server provides two endpoints:
- `GET /api/workflow?path=workflow.yaml`: Load a workflow configuration
- `POST /api/workflow`: Save workflow changes

### State Management

- React Flow manages the graph state
- React's useState and useCallback for component state
- Real-time UI updates through component props
- File persistence through the server API
