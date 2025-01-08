- [Workshop tasks](#workshop-tasks)
  - [1. Vault Setup with Helm Chart](#1-vault-setup-with-helm-chart)
  - [2. Vault Auth Methods](#2-vault-auth-methods)
  - [3. Vault KV Secret Engine](#3-vault-kv-secret-engine)
  - [4. Vault Policies](#4-vault-policies)
  - [5. Vault Database Secret Engine](#5-vault-database-secret-engine)
  - [6. Vault Manual backup](#6-vault-manual-backup)
# Workshop tasks
## 1. Vault Setup with Helm Chart
   - download and configure the values in the helm chart as following:
      * Standalone Vault: Configure Vault to run as a standalone instance, without HA.
      * Raft Storage Backend: Enable the Raft storage backend.
      * Configure Vault to use TLS for secure communication. You will need to provide your own certificates or enable auto-generation of certificates (use the example [here](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-tls#install-the-vault-helm-chart)).
      * Enable the Vault web UI for easier management and configuration.
      * Configure Kubernetes liveness and readiness probes to ensure Vault's health status is properly monitored
      * Set resource requests and limits for Vault to ensure it has enough resources to run efficiently and prevent over-provisioning.
   - Initialize the vault
   - Unseal the vault
   - Check Vault status
   - login to vault
   - The detailed solution is [here](./01-setup-vault-helm-chart.md)
## 2. Vault Auth Methods
   - Enable the AppRole authentication method
     - Create an AppRole
     - Retrieve the Role ID
     - Create a Secret ID
     - Login with AppRole
   - Enable the Kubernetes authentication method
     - Configure the Kubernetes authentication method
     - Create a Kubernetes role
     - Login with Kubernetes
   - Detailed solution is [here](./02-vault-auth-methods.md)
## 3. Vault KV Secret Engine
   - Enable KV Version 1
     - Write Secrets to KV Version 1
     - Read Secrets from KV Version
     - Delete Secrets from KV Version 1
     - Verify KV secret deletion
   - Enable KV Version 2
     - Write Secrets to KV Version
     - Read Secrets from KV Version 2
     - Rewrite Secrets to KV Version 2
     - Read again Secrets from KV Version 2
     - Read a Specific Version of a Secret
     - Delete Secrets from KV Version 2
     - Recover a deleted version of the secret
     - Permanently Destroy Secrets
   - Detailed solution is [here](./03-vault-secrets-kv.md)
## 4. Vault Policies
   - Enable the KV v2 secrets engine (if you have'nt done already)
   - Store some secrets in the KV v2 engine
   - Define a policy for read-only access to a KV v2 secret engine
   - Define a policy for read-write access to a KV v2 secret engine
   - Define a policy for admin access
   - Create a token with the `readonly` policy
   - Create a token with the `readwrite` policy
   - Create a token with the `admin` policy
   - Perform different operations with each token 
     - Login with the `readonly` token
       - attempt to read and write a secret
       - Attempt to perform an admin operation, such as enabling a new secret engine
     - Login with the `readwrite` token
       - attempt to read and write a secret
       - Attempt to perform an admin operation, such as enabling a new secret engine
     - Login with the `admin` token
       - Attempt to perform an admin operation, such as enabling a new secret engine
     - Policy Enforcement
       - List policies assigned to a token
       - Test access to restricted paths
 - Detailed solution is [here](./04-vault-policies.md)
## 5. Vault Database Secret Engine
  - Deploy PostgreSQL using Helm
        ```sh
        helm repo add bitnami https://charts.bitnami.com/bitnami
        helm repo update
        helm upgrade --install postgres bitnami/postgresql --namespace postgres --set global.postgresql.auth.postgresPassword=password123,global.postgresql.auth.database=mydb --create-namespace
        ```
  - Enable the Database Secret Engine on path postgres
    - Configure the PostgreSQL database plugin
    - Rotate root user password
    - Create a role for dynamic credential generation
    - Generate dynamic credentials and access the db with the dynamic credentials
    - run the following query to list data with the newly created user provisioned by vault
      ```sql
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'pg_catalog';
        ```
    - attempt to create a table 
       ```sql
        CREATE TABLE employees (
        employee_id SERIAL PRIMARY KEY);
        ```
  - Deploy MongoDB using Helm
     ```sh
     helm upgrade --install mongodb bitnami/mongodb --namespace mongodb --create-namespace
     ```
    - Setup MongoDB Client and login to MongoDB host
      ```sh
      export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace mongodb mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 --decode)
      kubectl run --namespace mongodb mongodb-client --rm --tty -i --restart='Never' --image=mongo:latest --command -- mongosh --host mongodb --port 27017 -u root -p $MONGODB_ROOT_PASSWORD
      ```
    - Enable the Database Secret Engine on path mongodb
      - Configure the MongoDB database plugin
      - Rotate root user password
      - Create a role for dynamic credential generation
      - Generate dynamic credentials
      - Access the db with the dynamic credentials
        ```bash
        kubectl run --namespace mongodb mongodb-client --rm --tty -i --restart='Never' --image=mongo:latest --command -- mongosh --host mongodb --port 27017 -u <new_user> -p <new_password>
        ```
      - Try running this query
        ```js
        show dbs
        use admin
        show collections
        ```

      - Now try running this query
        ```js
        use admin
        db.createCollection("testCollection")
        ```
  - Detailed solution is [here](./05-vault-secrets-database.md)
## 6. Vault Manual backup
  - Create a raft snapshot
  - Verify the vault snapshot file is created
  - Delete Vault data
    - Delete raft directory to simulate data loss.
    ```sh
      kubectl exec -it vault-0 -- rm -fr /vault/data
    ```
  - Recreate the storage for Vault. You can use the same YAML configuration used during the initial setup or let the Helm chart manage it
  - Restore the snapshot
  - Verify the restoration
  - Detailed solution is [here](./06-vault-manual-backup.md)
  - cleanup the deployments by uninstalling all charts and deleting all volumes
    - detailed [here](./cleanup.md)