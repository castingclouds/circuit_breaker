#!/bin/bash

# Function to check if NATS server is running
check_nats() {
    nc -z localhost 4222 2>/dev/null
    return $?
}

# Function to start NATS server if not running
ensure_nats_running() {
    if ! check_nats; then
        echo "Starting NATS server..."
        nats-server &
        sleep 2  # Give NATS server time to start
    else
        echo "NATS server is already running"
    fi
}

# Function to run a worker in the background
run_worker() {
    local worker_file=$1
    local worker_name=$(basename "$worker_file" .rb)
    echo "Starting $worker_name..."
    ruby "$worker_file" &
    echo "$worker_name started with PID $!"
}

# Kill all background processes when the script exits
cleanup() {
    echo "Cleaning up..."
    jobs -p | xargs -I{} kill {} 2>/dev/null
}
trap cleanup EXIT

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Start NATS server if not running
ensure_nats_running

# Start all function workers
echo "Starting function workers..."
for worker in serverless/functions/*_function.rb; do
    if [ -f "$worker" ] && [ "$worker" != "serverless/functions/base_function.rb" ]; then
        run_worker "$worker"
        sleep 1  # Give each worker time to initialize
    fi
done

echo "All workers started. Running main workflow..."
echo "----------------------------------------"

# Run the main workflow
ruby serverless_workflow.rb

# Keep the script running to maintain the workers
echo "----------------------------------------"
echo "Workflow started. Press Ctrl+C to stop all workers and exit."
wait
