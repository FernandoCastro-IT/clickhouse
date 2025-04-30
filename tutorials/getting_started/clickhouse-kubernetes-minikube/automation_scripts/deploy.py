#!/usr/bin/env python3

import subprocess
import sys
import os
import time
import argparse
from datetime import datetime

RELEASE_NAME = "my-clickhouse"
CHART_NAME = "bitnami/clickhouse"
CHART_VERSION = "9.2.0"  # Specify the chart version used in README
VALUES_FILE = "helm/values.yaml"
NAMESPACE = "default"  # Assuming deployment in default namespace
MINIKUBE_MEMORY = "4096"
MINIKUBE_CPUS = "2"
HELM_TIMEOUT = "5m0s"
POD_WAIT_TIMEOUT = 60 # seconds

# --- Helper Functions ---

def log(message):
    """Prints a timestamped message."""
    print(f"[{datetime.now().strftime('%T')}] {message}", flush=True)

def run_command(command, check=True, capture_output=False, text=True, shell=False):
    """Runs a shell command."""
    log(f"Running command: {' '.join(command) if isinstance(command, list) else command}")
    try:
        result = subprocess.run(command, check=check, capture_output=capture_output, text=text, shell=shell)
        return result
    except subprocess.CalledProcessError as e:
        log(f"Error running command: {e}")
        if capture_output:
            log(f"Stderr: {e.stderr}")
            log(f"Stdout: {e.stdout}")
        sys.exit(1)
    except FileNotFoundError:
        log(f"Error: Command not found: {command[0]}")
        sys.exit(1)

def command_exists(command_name):
    """Checks if a command exists."""
    try:
        subprocess.run(["command", "-v", command_name], check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError:
        return False

def start_minikube():
    """Checks Minikube status and starts it if not running."""
    try:
        run_command(["minikube", "status"], check=True, capture_output=True)
        log("Minikube is already running.")
    except subprocess.CalledProcessError:
        log("Minikube is not running. Starting Minikube...")
        run_command(["minikube", "start", f"--memory={MINIKUBE_MEMORY}", f"--cpus={MINIKUBE_CPUS}"])
        log("Minikube started successfully.")

def add_helm_repo():
    """Adds the Bitnami Helm repo if not already added."""
    result = run_command(["helm", "repo", "list"], capture_output=True)
    if "bitnami" not in result.stdout:
        log("Adding Bitnami Helm repository...")
        run_command(["helm", "repo", "add", "bitnami", "oci://registry-1.docker.io/bitnamicharts"])
    else:
        log("Bitnami Helm repository already exists.")
    log("Updating Helm repositories...")
    run_command(["helm", "repo", "update"])

# --- Main Script ---

def main():
    # Check prerequisites
    for cmd in ["minikube", "kubectl", "helm"]:
        if not command_exists(cmd):
            log(f"Error: {cmd} is not installed. Please install it first.")
            sys.exit(1)

    # Ensure we are in the correct directory relative to the script
    script_dir = os.path.dirname(os.path.realpath(__file__))
    project_dir = os.path.abspath(os.path.join(script_dir, os.pardir))
    os.chdir(project_dir)
    log(f"Changed directory to: {project_dir}")

    values_path = os.path.join(project_dir, VALUES_FILE)
    if not os.path.isfile(values_path):
        log(f"Error: Values file not found at {values_path}")
        sys.exit(1)

    # Start Minikube if necessary
    start_minikube()

    # Add Helm repository
    add_helm_repo()

    # Create ClickHouse namespace if it doesn't exist
    try:
        run_command(["kubectl", "create", "namespace", NAMESPACE], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        log(f"Namespace '{NAMESPACE}' already exists. Skipping creation.")
    except Exception as e:
        log(f"Error creating namespace '{NAMESPACE}': {e}")
        sys.exit(1)
    log(f"Namespace '{NAMESPACE}' is ready.")

    # Change to ClickHouse namespace
    try:
        run_command(["kubectl", "config", "set-context", "--current", "--namespace", NAMESPACE], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        log(f"Error setting namespace '{NAMESPACE}' in kubectl context.")
        sys.exit(1)
    log(f"Changed kubectl context to namespace '{NAMESPACE}'.")
    
    # Check if the ClickHouse release already exists
    try:
        run_command(["helm", "status", RELEASE_NAME, "-n", NAMESPACE], check=True, capture_output=True)
        log(f"Helm release '{RELEASE_NAME}' already exists. Skipping installation.")
        sys.exit(0)
    except subprocess.CalledProcessError:
        log(f"Helm release '{RELEASE_NAME}' does not exist. Proceeding with installation.")


    # Install ClickHouse using Helm
    log(f"Installing ClickHouse chart '{CHART_NAME}' with release name '{RELEASE_NAME}'...")
    try:
        run_command([
            "helm", "install", RELEASE_NAME, CHART_NAME,
            "--version", CHART_VERSION,
            "-f", values_path,
            "--namespace", NAMESPACE,
            "--wait", f"--timeout={HELM_TIMEOUT}"
        ])
        log("ClickHouse Helm chart installed successfully!")
    except SystemExit:
        log("Error: Helm installation failed.")
        # Provide some debugging info
        log("Checking Helm status:")
        run_command(["helm", "status", RELEASE_NAME, "-n", NAMESPACE], check=False)
        log("Checking pods:")
        run_command(["kubectl", "get", "pods", "-n", NAMESPACE, "-l", f"app.kubernetes.io/instance={RELEASE_NAME}"], check=False)
        sys.exit(1)

    # Verification (Optional - Helm wait should cover this, but good for confirmation)
    log("Verifying deployment status...")

    status_result = run_command(["helm", "status", RELEASE_NAME, "-n", NAMESPACE], capture_output=True)
    if "STATUS: deployed" not in status_result.stdout:
        log("Warning: Helm release status is not 'deployed'. Check 'helm status {RELEASE_NAME}' for details.")
    else:
        log("Helm release status: deployed.")

    try:
        pod_name_result = run_command([
            "kubectl", "get", "pods", "-n", NAMESPACE,
            "-l", f"app.kubernetes.io/instance={RELEASE_NAME},app.kubernetes.io/name=clickhouse",
            "-o", "jsonpath={.items[0].metadata.name}"
        ], capture_output=True, check=False) # Don't exit if pod not found immediately
        
        pod_name = pod_name_result.stdout.strip()

        if not pod_name:
             log(f"Warning: Could not find ClickHouse pod. Check 'kubectl get pods -l app.kubernetes.io/instance={RELEASE_NAME}'")
        else:
             log(f"Found pod: {pod_name}. Waiting for it to be ready...")
             # Use kubectl wait
             try:
                 run_command([
                     "kubectl", "wait", "--for=condition=ready", f"pod/{pod_name}",
                     "-n", NAMESPACE, f"--timeout={POD_WAIT_TIMEOUT}s"
                 ], capture_output=True) # Capture output to suppress success message
                 log(f"ClickHouse pod '{pod_name}' is ready.")
             except SystemExit: # Catches CalledProcessError from run_command
                 log(f"Warning: ClickHouse pod '{pod_name}' did not become ready within the timeout. Check pod logs and events.")

    except Exception as e:
        log(f"An error occurred during pod verification: {e}")

    log("Deployment script finished.")

if __name__ == "__main__":
    main()

