# Vault Workshop - Prerequisites

Before starting the Vault workshop, make sure you have the following prerequisites:

- **[Minikube](https://minikube.sigs.k8s.io/docs/start/?arch=%2Flinux%2Fx86-64%2Fstable%2Fbinary+download)**: A tool to run Kubernetes clusters locally. You will need this to set up a local Kubernetes environment for the workshop.
    
    ```sh
    minikube start
    ```
- **[Vault CLI](https://releases.hashicorp.com/vault/1.21.2/vault_1.21.2_linux_amd64.zip)**: The Vault CLI (Version 1.16.3) to interact with Vault instances and perform various tasks during the workshop.
 
    ```sh
    sudo snap install vault
    ```
- **[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux)**: The Kubectl CLI installed on your local machine to interact with the minikube.
- **[Helm](https://helm.sh/docs/intro/install/#from-script)**: The Helm 3.x CLI installed on your local machine.
    ```sh
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    ```
- Clone the workshop repository to your workstation
    ```sh
    git clone https://github.com/TeraSky-OSS/vault-workshop-aws.git
    ``` 
Make sure both Minikube and Vault CLI are installed and configured on your machine before proceeding.

Next: start performing the workshop [tasks](./tasks.md)
