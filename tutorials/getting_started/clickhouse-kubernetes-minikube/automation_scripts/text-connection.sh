#!/bin/bash

# Script to test connection to ClickHouse deployed via Helm on Minikube

set -eo pipefail

RELEASE_NAME="my-clickhouse"
NAMESPACE="default"
SERVICE_NAME="${RELEASE_NAME}-clickhouse" # Default service name pattern for Bitnami chart
LOCAL_PORT=9001 # Use a different local port to avoid conflict if 9000 is already in use
REMOTE_PORT=9000 # ClickHouse TCP port

# Credentials from values.yaml (adjust if changed)
CLICKHOUSE_USER="user"
CLICKHOUSE_PASSWORD="Password123"

# --- Helper Functions --- 

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Main Script --- 

# Check prerequisites
if ! command_exists kubectl; then
    echo "[$(date +%T)] Error: kubectl is not installed." >&2
    exit 1
fi
if ! command_exists clickhouse-client; then
    echo "[$(date +%T)] Error: clickhouse-client is not installed. Please install it first." >&2
    echo "[$(date +%T)] (Hint: You might need to install clickhouse-client locally or run this from within a container that has it)" >&2
    exit 1
fi

# Ensure we are in the correct directory relative to the script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR/.." # Move to the parent directory (clickhouse-kubernetes-minikube)

# Check if the service exists
echo "[$(date +%T)] Checking if ClickHouse service 	'$SERVICE_NAME	' exists in namespace 	'$NAMESPACE	'..."
if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "[$(date +%T)] Error: Service 	'$SERVICE_NAME	' not found. Is ClickHouse deployed?" >&2
    exit 1
fi
echo "[$(date +%T)] Service found."

# Start port-forwarding in the background
echo "[$(date +%T)] Starting port-forwarding: localhost:$LOCAL_PORT -> $SERVICE_NAME:$REMOTE_PORT..."
kubectl port-forward svc/"$SERVICE_NAME" -n "$NAMESPACE" "$LOCAL_PORT:$REMOTE_PORT" > /dev/null 2>&1 &
PORT_FORWARD_PID=$!

# Wait a moment for port-forwarding to establish
sleep 3

# Check if port-forwarding is still running
if ! kill -0 $PORT_FORWARD_PID > /dev/null 2>&1; then
    echo "[$(date +%T)] Error: Failed to start port-forwarding." >&2
    exit 1
fi

# Attempt to connect and run a query
echo "[$(date +%T)] Attempting to connect to ClickHouse via port-forward..."
QUERY="SELECT 1"

if clickhouse-client --host 127.0.0.1 --port "$LOCAL_PORT" --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --query="$QUERY" --connect_timeout=5 --receive_timeout=5 > /dev/null 2>&1; then
    echo "[$(date +%T)] Connection successful! Query 	'$QUERY	' executed."
    CONNECTION_SUCCESS=true
else
    echo "[$(date +%T)] Error: Failed to connect or execute query on ClickHouse." >&2
    echo "[$(date +%T)] Please check:
    - If the ClickHouse pod is running and ready (	'kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME	').
    - If the credentials in this script match 	'helm/values.yaml	'.
    - If the port-forwarding is working correctly."
    CONNECTION_SUCCESS=false
fi

# Stop port-forwarding
echo "[$(date +%T)] Stopping port-forwarding (PID: $PORT_FORWARD_PID)..."
kill $PORT_FORWARD_PID
wait $PORT_FORWARD_PID 2>/dev/null # Wait for the process to terminate and suppress 
