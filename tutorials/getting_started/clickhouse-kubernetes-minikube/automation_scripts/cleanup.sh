#!/bin/bash

# --- Configuration ---
KUBERNETES_DIR="../kubernetes" # Relative path to the kubernetes YAML files
HOST_PATH_DIR="/data/clickhouse"
# Set to true to also remove the hostPath directory from Minikube node
REMOVE_HOST_PATH=false 
# Set to true to also stop Minikube
STOP_MINIKUBE=false

# --- Helper Functions ---

# Function to print messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check command success (optional, less critical for delete)
check_delete() {
    if [ $? -ne 0 ]; then
        log "Warning: $1 might not have been deleted successfully (or didn't exist)."
    fi
}

# --- Main Script ---

log "Starting ClickHouse on Minikube cleanup..."

# 1. Delete Kubernetes Resources (in reverse order of creation)
log "Deleting Kubernetes manifests from ${KUBERNETES_DIR}..."

log "Deleting StatefulSet..."
kubectl delete -f "${KUBERNETES_DIR}/statefulset.yaml" --ignore-not-found=true
check_delete "StatefulSet deletion"

log "Deleting Headless Service..."
kubectl delete -f "${KUBERNETES_DIR}/service-headless.yaml" --ignore-not-found=true
check_delete "Headless Service deletion"

log "Deleting ConfigMap..."
kubectl delete -f "${KUBERNETES_DIR}/configmap.yaml" --ignore-not-found=true
check_delete "ConfigMap deletion"

log "Deleting PersistentVolumeClaim..."
kubectl delete -f "${KUBERNETES_DIR}/pvc.yaml" --ignore-not-found=true
check_delete "PersistentVolumeClaim deletion"

# Wait briefly before deleting PV to allow volume release (optional)
sleep 5

log "Deleting PersistentVolume..."
kubectl delete -f "${KUBERNETES_DIR}/pv.yaml" --ignore-not-found=true
check_delete "PersistentVolume deletion"

log "Kubernetes resources deleted."

# 2. Optional: Remove HostPath Directory
if [ "${REMOVE_HOST_PATH}" = true ]; then
    log "Removing hostPath directory (${HOST_PATH_DIR}) from Minikube node..."
    minikube ssh -- sudo rm -rf ${HOST_PATH_DIR}
    check_delete "Remove directory ${HOST_PATH_DIR}"
    log "HostPath directory removed."
else
    log "Skipping removal of hostPath directory (${HOST_PATH_DIR}). Set REMOVE_HOST_PATH=true to enable."
fi

# 3. Optional: Stop Minikube
if [ "${STOP_MINIKUBE}" = true ]; then
    log "Stopping Minikube..."
    minikube stop
    check_delete "Minikube stop"
    log "Minikube stopped."
else
    log "Skipping stopping Minikube. Set STOP_MINIKUBE=true to enable."
fi

log "Cleanup script finished."

exit 0

