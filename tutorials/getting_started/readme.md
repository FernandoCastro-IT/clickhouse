# Tutorial: Deploying ClickHouse on Kubernetes with Minikube using Helm

**Use Case/Feature:** Getting Started with ClickHouse on Kubernetes (Single Node) using Helm

## Overview

This tutorial provides a step-by-step guide to deploying a single-node ClickHouse instance on a local Kubernetes cluster using Minikube. It leverages the popular **Bitnami ClickHouse Helm chart** for a streamlined and robust deployment process.

Using Helm simplifies the management of Kubernetes applications, handling the creation and configuration of underlying resources like StatefulSets, Services, ConfigMaps, and PersistentVolumeClaims based on a customizable `values.yaml` file.

This approach is ideal for developers and administrators looking for an efficient way to run ClickHouse in a containerized environment for development, testing, or learning purposes.

## Features Demonstrated

-   Deploying a stateful application (ClickHouse) on Kubernetes using Helm.
-   Utilizing a community-maintained Helm chart (Bitnami ClickHouse).
-   Customizing the deployment using a `values.yaml` file (authentication, persistence, resources).
-   Managing the application lifecycle (install, upgrade, delete) with Helm.
-   Setting up persistent storage using Kubernetes PersistentVolumes/PersistentVolumeClaims via Helm.
-   Accessing the deployment using `kubectl port-forward`.

## Prerequisites

Before you begin, ensure you have the following tools installed and configured:

-   **Minikube:** A tool to run a single-node Kubernetes cluster locally. ([Installation Guide](https://minikube.sigs.k8s.io/docs/start/))
-   **kubectl:** The Kubernetes command-line tool. ([Installation Guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/))
-   **Helm:** The Kubernetes package manager. ([Installation Guide](https://helm.sh/docs/intro/install/))
-   **Docker (or other container runtime):** Minikube requires a container runtime like Docker, HyperKit, KVM, etc. Ensure your chosen driver is installed and running.

## Helm Chart Details

This tutorial uses the official Bitnami ClickHouse Helm chart.

-   **Chart Name:** `clickhouse`
-   **Repository:** `oci://registry-1.docker.io/bitnamicharts`
-   **Artifact Hub:** [https://artifacthub.io/packages/helm/bitnami/clickhouse](https://artifacthub.io/packages/helm/bitnami/clickhouse)

We will use a custom `values.yaml` file to configure the chart for our Minikube environment.

## Configuration (`helm/values.yaml`)

The `helm/values.yaml` file in this directory provides specific configurations tailored for this Minikube tutorial:

-   **Replica Count:** Set to 1 for a single-node deployment.
-   **Authentication:** Configures a default username (`user`) and password (`Password123`). **It is strongly recommended to change this password for any non-trivial use.**
-   **Persistence:** Enabled by default, using the default Minikube storage class with a size of 2Gi.
-   **Resources:** Sets basic CPU and memory requests/limits suitable for Minikube.
-   **ClickHouse Keeper:** Disabled as it's not required for a single replica.
-   **Service Type:** Uses `ClusterIP` for internal access.
-   **Metrics:** Disabled for simplicity.

You can modify this file to further customize the deployment (e.g., change passwords, adjust resources, use a specific ClickHouse version).

## Automation Scripts

For convenience, this tutorial includes automation scripts located in the `automation_scripts/` directory to simplify the deployment and cleanup process using Helm:

-   **`deploy.sh` / `deploy.py`**: These scripts automate the entire deployment process, including starting Minikube (if needed), adding the Bitnami Helm repository, and installing the ClickHouse chart using the provided `helm/values.yaml`.
-   **`cleanup.sh` / `cleanup.py`**: These scripts automate the cleanup process by uninstalling the Helm release. They also include options to stop Minikube.
-   **`test-connection.sh`**: A script to verify the connection to the deployed ClickHouse instance using the configured credentials.

Using these scripts is recommended for a quicker setup and teardown.

**Usage:**

1.  Navigate to this tutorial's directory:
    ```bash
    cd tutorials/getting_started/clickhouse-kubernetes-minikube
    ```
2.  Make shell scripts executable:
    ```bash
    chmod +x automation_scripts/*.sh
    ```
3.  **To Deploy:**
    *   Using Shell:
        ```bash
        ./automation_scripts/deploy.sh
        ```
    *   Using Python:
        ```bash
        python3 automation_scripts/deploy.py
        ```
4.  **To Test Connection (after deployment):**
    *   Ensure `clickhouse-client` is installed locally.
    *   Run the test script:
        ```bash
        ./automation_scripts/test-connection.sh
        ```
5.  **To Clean Up:**
    *   Using Shell (edit variables inside `cleanup.sh` to optionally stop Minikube):
        ```bash
        ./automation_scripts/cleanup.sh
        ```
    *   Using Python (use flags for options):
        ```bash
        # Basic cleanup (uninstall Helm release)
        python3 automation_scripts/cleanup.py 

        # Cleanup and stop Minikube
        # python3 automation_scripts/cleanup.py --stop-minikube
        ```

## Setup and Deployment Steps (Manual Helm)

Follow these steps to deploy ClickHouse using Helm:

1.  **Start Minikube:**
    Ensure Minikube is running with sufficient resources.
    ```bash
    minikube start --memory 4096 --cpus 2
    minikube status
    ```

2.  **Add Bitnami Helm Repository:**
    If you haven't already, add the Bitnami repository to your Helm client.
    ```bash
    helm repo add bitnami oci://registry-1.docker.io/bitnamicharts
    helm repo update
    ```

3.  **Install ClickHouse Chart:**
    Navigate to this tutorial's directory (`tutorials/getting_started/clickhouse-kubernetes-minikube`) in your terminal. Install the chart using Helm, providing a release name (e.g., `my-clickhouse`) and specifying the custom values file.
    ```bash
    helm install my-clickhouse bitnami/clickhouse -f helm/values.yaml --version 9.2.0 # Use the chart version researched
    ```
    *Note: Replace `9.2.0` with the specific chart version you intend to use if different.* 

## Verification

Check if the Helm deployment was successful:

-   **Check Helm Release Status:**
    ```bash
    helm status my-clickhouse
    # Should show STATUS: deployed
    ```
-   **Check Pod Status:**
    The chart creates a StatefulSet. Find the pod name.
    ```bash
    kubectl get pods -l app.kubernetes.io/instance=my-clickhouse
    # Should show STATUS: Running and READY: 1/1 (or similar based on chart structure)
    ```
-   **Check PersistentVolumeClaim:**
    ```bash
    kubectl get pvc -l app.kubernetes.io/instance=my-clickhouse
    # Should show STATUS: Bound
    ```
-   **Check Logs (if needed):**
    Get the pod name from the previous step.
    ```bash
    kubectl logs <pod-name>
    ```

## Accessing ClickHouse

Use `kubectl port-forward` to access the ClickHouse instance from your local machine. The service name is typically `<release-name>-clickhouse`.

-   **Find the Service:**
    ```bash
    kubectl get svc -l app.kubernetes.io/instance=my-clickhouse
    ```
-   **Port-forward for TCP Client (`clickhouse-client`):**
    Open a new terminal:
    ```bash
    kubectl port-forward svc/my-clickhouse 9000:9000
    ```
    Connect using the client and the credentials from `helm/values.yaml`:
    ```bash
    clickhouse-client --host 127.0.0.1 --port 9000 --user user --password 'Password123'
    # Example query: SHOW DATABASES;
    ```

-   **Port-forward for HTTP Interface:**
    Open another new terminal:
    ```bash
    kubectl port-forward svc/my-clickhouse 8123:8123
    ```
    Access via `curl` or a browser/GUI tool:
    ```bash
    curl "http://user:Password123@127.0.0.1:8123/?query=SELECT%20version()"
    ```

## Cleanup

To remove all resources created by the Helm chart:

```bash
helm uninstall my-clickhouse

# Optional: Stop Minikube
# minikube stop

# Note: Helm uninstall should also trigger the deletion of the PVC.
# You can verify with 'kubectl get pvc'
```

## File Structure

```
.
├── README.md                     # This tutorial guide (Helm-based)
├── helm/
│   └── values.yaml               # Custom Helm chart values for Minikube
├── automation_scripts/           # Automation scripts (to be refactored for Helm)
│   ├── deploy.sh
│   ├── cleanup.sh
│   ├── deploy.py
│   ├── cleanup.py
│   └── test-connection.sh        # (New) Script to test connection
└── research_summary.md           # Background research notes (may need update)
```
*(Note: The old `kubernetes/` directory and `minikube_setup_instructions.md` are no longer needed for the Helm approach and can be removed.)*

## Next Steps

-   Explore ClickHouse features by running queries via the client or HTTP interface.
-   Modify the `helm/values.yaml` file to experiment with different chart configurations (e.g., resources, versions).
-   Learn more about Helm chart customization and management.
-   Investigate deploying a clustered ClickHouse setup using the Helm chart (likely requires enabling ClickHouse Keeper).
