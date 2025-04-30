#!/usr/bin/env python3

import subprocess
import sys
import os
import argparse
from datetime import datetime

RELEASE_NAME = "my-clickhouse"
NAMESPACE = "default"

# --- Helper Functions ---

def log(message):
    """Prints a timestamped message."""
    print(f"[{datetime.now().strftime(	'%T')}] {message}", flush=True)

def run_command(command, check=True, capture_output=False, text=True, shell=False):
    """Runs a shell command."""
    log(f"Running command: {	' '.join(command) if isinstance(command, list) else command}")
    try:
        result = subprocess.run(command, check=check, capture_output=capture_output, text=text, shell=shell)
        return result
    except subprocess.CalledProcessError as e:
        log(f"Warning: Command failed: {e}") # Use warning for cleanup failures
        if capture_output:
            log(f"Stderr: {e.stderr}")
            log(f"Stdout: {e.stdout}")
        # Don't exit on cleanup failure, just log
        return None
    except FileNotFoundError:
        log(f"Error: Command not found: {command[0]}")
        # Don't exit on cleanup failure, just log
        return None

def command_exists(command_name):
    """Checks if a command exists."""
    try:
        subprocess.run(["command", "-v", command_name], check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError:
        return False

# --- Main Script ---

def main():
    parser = argparse.ArgumentParser(description="Clean up ClickHouse Helm deployment on Minikube.")
    parser.add_argument("--stop-minikube", action="store_true", help="Stop the Minikube instance after cleanup.")
    args = parser.parse_args()

    # Check prerequisites
    if not command_exists("kubectl"):
        log("Error: kubectl is not installed.")
        # Allow script to continue if possible
    if not command_exists("helm"):
        log("Error: helm is not installed.")
        # Allow script to continue if possible

    # Ensure we are in the correct directory relative to the script
    script_dir = os.path.dirname(os.path.realpath(__file__))
    project_dir = os.path.abspath(os.path.join(script_dir, os.pardir))
    try:
        os.chdir(project_dir)
        log(f"Changed directory to: {project_dir}")
    except FileNotFoundError:
        log(f"Warning: Could not change to project directory {project_dir}. Running from current directory.")

    # Uninstall Helm release
    log(f"Checking Helm release status for 	'{RELEASE_NAME}	'...")
    status_check = run_command(["helm", "status", RELEASE_NAME, "-n", NAMESPACE], check=False, capture_output=True)
    
    if status_check and status_check.returncode == 0:
        log(f"Uninstalling Helm release 	'{RELEASE_NAME}	' from namespace 	'{NAMESPACE}	'...")
        run_command(["helm", "uninstall", RELEASE_NAME, "-n", NAMESPACE, "--wait"], check=False) # Don't exit on failure
        log(f"Helm release 	'{RELEASE_NAME}	' uninstall initiated.")
    else:
        log(f"Helm release 	'{RELEASE_NAME}	' not found in namespace 	'{NAMESPACE}	'. Skipping uninstall.")

    # Optional: Stop Minikube
    if args.stop_minikube:
        if not command_exists("minikube"):
            log("Warning: minikube command not found, cannot stop Minikube.")
        else:
            try:
                run_command(["minikube", "status"], check=True, capture_output=True)
                log("Stopping Minikube...")
                run_command(["minikube", "stop"], check=False) # Don't exit on failure
            except subprocess.CalledProcessError:
                 log("Minikube is not running. Skipping stop.")
            except Exception as e:
                 log(f"An error occurred while trying to stop Minikube: {e}")

    log("Cleanup script finished.")

if __name__ == "__main__":
    main()

