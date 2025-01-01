# Demo Directory README

## Introduction

Welcome to the **Demo** directory! This directory contains all the necessary scripts and configurations to run the Vault demos for this workshop. Follow the instructions below to set up and run the Vault environment, customize the demos, and clean up the environment when you're done.

### Prerequisites

Before starting the demo, ensure that you have the following tools installed:

- **Minikube**: A tool for running Kubernetes clusters locally.
- **kubectl**: The Kubernetes command-line tool to interact with your cluster.
- **Vault CLI**: The command-line interface for HashiCorp Vault.

### Setting Up the Vault Environment

To set up the Vault environment, follow these steps:

1. **Run the `warmup.sh` script**:
   This script will set up the Vault cluster. It will initialize Vault, unseal it, and configure the environment. The unseal keys and tokens will be saved in a file named `cluster-keys.json`. Be sure to keep this file safe as it contains sensitive information.

   To run the script, use the following command:

   ```bash
   ./warm_up.sh
   ```

### Running the Demo

Once the Vault environment is set up, you can start the demo by running the following script:

```bash
./demo.sh
```

This will trigger the demo to run in the default sequence. If you want to control the order and which demos are displayed, you can modify the `demo_config.yaml` file located in the `./configuration` directory. In this file, you can set the order of the demos and choose which ones to display.

### Demos

The `demos` directory within **Demo** contains all the demo scripts for various Vault functionalities. Each demo is designed to be run independently, and you can execute them in any order based on your preferences.

### Rerunning Demos

Each demo is rerunnable, meaning you can run the demos as many times as needed. The environment is designed to be flexible and allows you to experiment with different Vault features multiple times.

### Cleaning Up the Environment

When you're done with the demos and want to clean up the environment, you can run the `delete_env.sh` script. This script will destroy the Vault environment and remove any resources created during the demo.

To run the cleanup script, use:

```bash
./delete_env.sh
```

### Environment Variables

The environment variables that control the Vault environment are located in the `./configuration/env.sh` file. You can modify this file to customize your Vault setup, such as adjusting configurations or changing Vault-related settings.

---

This directory provides everything you need to run the Vault demos, customize the environment, and clean up afterward. Enjoy the demos, and feel free to experiment with different configurations!