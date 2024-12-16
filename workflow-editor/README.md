# Workflow Editor

A visual editor for creating and modifying workflow configurations using React Flow. This editor allows you to create, edit, and visualize workflow states and transitions in a user-friendly interface.

## Features

- Interactive graph visualization of workflow states and transitions
- Real-time editing of nodes (states) and edges (transitions)
- Automatic layout using the Dagre algorithm
- Details panel for editing node and edge properties
- YAML configuration file integration
- Smooth edges with directional arrows
- Auto-save functionality

## Getting Started

1. Install dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm start
```

This will start both the Vite development server and the backend server for handling workflow saves.

## Usage Guide

### Adding New Nodes

1. Click the "Add Node" button in the top-left corner
2. A new node will be created with a default name
3. Select the node to edit its properties in the details panel
4. The node will be automatically positioned in the graph

### Creating Transitions

1. Hover over a node to see the connection handle
2. Click and drag from one node to another to create a transition
3. The transition will be created with a default name
4. Select the transition to edit its properties

### Editing Properties

#### Node Details
- When a node is selected, the details panel shows:
  - Node label (editable)
  - Node type (regular or special)
  - Node description
  - Connected transitions

#### Edge Details
- When a transition is selected, the details panel shows:
  - Transition name (editable)
  - Source and target states
  - Requirements list (can be added/removed)

### Saving Changes

The workflow is automatically saved when:
- A new node is added
- A transition is created or modified
- Node or edge properties are updated

The save process:
1. Converts the visual graph to YAML format
2. Saves to `src/config/workflow.yaml`
3. Updates the graph to reflect any changes

## Configuration Files

### workflow.yaml
- Located in `src/config/workflow.yaml`
- Contains the workflow configuration in YAML format
- Structure:
  ```yaml
  object_type: Issue
  places:
    states: [...]
    special_states: [...]
  transitions:
    regular: [...]
  ```

### flowConfig.ts
- Located in `src/config/flowConfig.ts`
- Defines visual styles for nodes and edges
- Configures graph layout settings

## Development

### Key Components

- `App.tsx`: Main application component
- `Flow.tsx`: React Flow configuration and event handlers
- `EdgeDetails.tsx`: Edge property editor
- `NodeDetails.tsx`: Node property editor
- `saveWorkflow.ts`: Workflow save functionality

### State Management

- Node positions and connections are managed by React Flow
- Node and edge data is synchronized with the YAML configuration
- Real-time updates are handled through React state and callbacks
