# Serverless Petri Workflow Functions

This directory contains serverless functions that can be used with the Petri Workflow system. Each function is designed to run independently and communicate through NATS JetStream.

## Structure

```
serverless/
├── config/
│   └── nats_config.rb       # NATS connection configuration
└── functions/
    ├── base_function.rb     # Base class for all functions
    ├── review_function.rb   # Handles document review
    ├── approval_function.rb # Handles approval decisions
    └── notification_function.rb # Handles notifications
```

## Running the Functions

Each function can be run independently. You'll need a NATS server running with JetStream enabled.

1. Start NATS server with JetStream:
```bash
nats-server -js
```

2. Run individual functions:
```bash
# Run review function
ruby functions/review_function.rb

# Run approval function
ruby functions/approval_function.rb

# Run notification function
ruby functions/notification_function.rb
```

## Environment Variables

- `NATS_URL`: NATS server URL (default: nats://localhost:4222)

## Function Descriptions

### Review Function
- Subscribes to: `function.function_pending_review`
- Simulates document review process
- Publishes review results

### Approval Function
- Subscribes to: `function.function_reviewed`
- Makes approval decisions based on review results
- Triggers appropriate transitions (approve/reject)

### Notification Function
- Subscribes to: `function.function_notification_pending`
- Handles sending notifications
- Marks notifications as sent

## Testing

You can test the functions by running the main workflow example:
```bash
ruby ../serverless_workflow.rb
```

This will create a workflow that triggers these functions in sequence.
