#!/bin/bash

# Automation script to deploy ClickHouse using Helm on Minikube

set -eo pipefail

RELEASE_NAME="my-clickhouse"
CHART_NAME="bitnami/clickhouse"
CHART_VERSION="9.2.0" # Specify the chart version used in README
VALUES_FILE="helm/values.yaml"
NAMESPACE="default" # Assuming deployment in default namespace

# --- Helper Functions --- 

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Minikube status and start if not running
start_minikube() {
    if ! minikube status > /dev/null 2>&1; then
        echo "[$(date +%T)] Minikube is not running. Starting Minikube..."
        minikube start --memory 4096 --cpus 2 || {
            echo "[$(date +%T)] Error: Failed to start Minikube." >&2
            exit 1
        }
        echo "[$(date +%T)] Minikube started successfully."
    else
        echo "[$(date +%T)] Minikube is already running."
    fi
}

# Add Bitnami Helm repo if not already added
add_helm_repo() {
    if ! helm repo list | grep -q "bitnami"; then
        echo "[$(date +%T)] Adding Bitnami Helm repository..."
        helm repo add bitnami oci://registry-1.docker.io/bitnamicharts || {
            echo "[$(date +%T)] Error: Failed to add Bitnami Helm repository." >&2
            exit 1
        }
    else
        echo "[$(date +%T)] Bitnami Helm repository already exists."
    fi
    echo "[$(date +%T)] Updating Helm repositories..."
    helm repo update || {
        echo "[$(date +%T)] Error: Failed to update Helm repositories." >&2
        exit 1
    }
}

# --- Main Script --- 

# Check prerequisites
if ! command_exists minikube; then
    echo "[$(date +%T)] Error: minikube is not installed. Please install it first." >&2
    exit 1
fi
if ! command_exists kubectl; then
    echo "[$(date +%T)] Error: kubectl is not installed. Please install it first." >&2
    exit 1
fi
if ! command_exists helm; then
    echo "[$(date +%T)] Error: helm is not installed. Please install it first." >&2
    exit 1
fi

# Ensure we are in the correct directory relative to the script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR/.." # Move to the parent directory (clickhouse-kubernetes-minikube)

if [ ! -f "$VALUES_FILE" ]; then
    echo "[$(date +%T)] Error: Values file not found at $VALUES_FILE" >&2
    exit 1
fi

# Start Minikube if necessary
start_minikube

# Add Helm repository
add_helm_repo

# Create ClickHouse namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    echo "[$(date +%T)] Creating namespace '$NAMESPACE'..."
    kubectl create namespace "$NAMESPACE" || {
        echo "[$(date +%T)] Error: Failed to create namespace '$NAMESPACE'." >&2
        exit 1
    }
else
    echo "[$(date +%T)] Namespace '$NAMESPACE' already exists."
fi

# Change to ClickHouse namespace
echo "[$(date +%T)] Switching to namespace '$NAMESPACE'..."
kubectl config set-context --current --namespace="$NAMESPACE" || {
    echo "[$(date +%T)] Error: Failed to switch to namespace '$NAMESPACE'." >&2
    exit 1
}

# Install ClickHouse using Helm
echo "[$(date +%T)] Installing ClickHouse chart '$CHART_NAME' with release name '$RELEASE_NAME'..."
helm install "$RELEASE_NAME" "$CHART_NAME" \
    --version "$CHART_VERSION" \
    -f "$VALUES_FILE" \
    --namespace "$NAMESPACE" \
    --wait --timeout 5m0s || { # Wait for deployment to complete (adjust timeout as needed)
        echo "[$(date +%T)] Error: Helm installation failed." >&2
        # Provide some debugging info
        echo "[$(date +%T)] Checking Helm status:"
        helm status "$RELEASE_NAME" -n "$NAMESPACE" || true
        echo "[$(date +%T)] Checking pods:"
        kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance=$RELEASE_NAME || true
        exit 1
    }

echo "[$(date +%T)] ClickHouse Helm chart installed successfully!"

# Verification (Optional - Helm wait should cover this, but good for confirmation)
echo "[$(date +%T)] Verifying deployment status..."

if ! helm status "$RELEASE_NAME" -n "$NAMESPACE" | grep -q "STATUS: deployed"; then
    echo "[$(date +%T)] Warning: Helm release status is not 'deployed'. Check 'helm status $RELEASE_NAME' for details." >&2
else
    echo "[$(date +%T)] Helm release status: deployed."
fi

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance=$RELEASE_NAME,app.kubernetes.io/name=clickhouse -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "[$(date +%T)] Warning: Could not find ClickHouse pod. Check 'kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME'" >&2
elif ! kubectl wait --for=condition=ready pod/"$POD_NAME" -n "$NAMESPACE" --timeout=60s > /dev/null 2>&1; then
    echo "[$(date +%T)] Warning: ClickHouse pod '$POD_NAME' is not ready. Check pod logs and events." >&2
else
    echo "[$(date +%T)] ClickHouse pod '$POD_NAME' is ready."
fi

echo "[$(date +%T)] Deployment script finished."

