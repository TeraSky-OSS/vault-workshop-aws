- [Workshop tasks](#workshop-tasks)
  - [1. Vault Setup with Helm Chart](#1-vault-setup-with-helm-chart)
  - [2. Vault Auth Methods](#2-vault-auth-methods)
  - [3. Vault KV Secret Engine](#3-vault-kv-secret-engine)
  - [4. Vault Policies](#4-vault-policies)
  - [5. Vault Database Secret Engine](#5-vault-database-secret-engine)
  - [6. Vault Manual backup](#6-vault-manual-backup)
  - [7. Vault HA in action](#7-vault-ha-in-action)
  - [Bonus: Kubernetes Production Patterns](#Bonus-Kubernetes-Production-Patterns)
  - [Developer Section: Secret Consumption Patterns](#Developer-Section-Secret-Consumption-Patterns)
# Workshop tasks
## 1. Vault Setup with Helm Chart
   - Download the vault official helm chart and configure the values in the helm chart as following:
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
   - The detailed solution is [here](./solutions/01-setup-vault-helm-chart.md)
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
   - Detailed solution is [here](./solutions/02-vault-auth-methods.md)
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
   - Detailed solution is [here](./solutions/03-vault-secrets-kv.md)
## 4. Vault Policies
   - Enable the KV v2 secrets engine (if you have'nt done already)
   - Store some secrets in the KV v2 engine
   - Define a policy for read-only access to a KV v2 secret engine
   - Define a policy for read-write access to a KV v2 secret engine
   - Define a policy for admin access
   - Enable Userpass (if not already) and create users with passwords, each attached to one policy (`readonly`, `readwrite`, `admin`)
   - Perform different operations as each user (Userpass login)
     - Log in as the read-only user
       - Attempt to read and write a secret
       - Attempt to perform an admin operation, such as enabling a new secret engine
     - Log in as the read-write user
       - Attempt to read and write a secret
       - Attempt to perform an admin operation, such as enabling a new secret engine
     - Log in as the admin user
       - Attempt to perform an admin operation, such as enabling a new secret engine
     - Policy enforcement
       - Inspect policies on the token (`vault token lookup`)
       - Test access to restricted paths
 - Detailed solution is [here](./solutions/04-vault-policies.md)
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
  - Detailed solution is [here](./solutions/05-vault-secrets-database.md)
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
  - Detailed solution is [here](./solutions/06-vault-manual-backup.md)
## 7. Vault HA in action

Confirm 3 pods running with integrated storage (Raft).

```bash
kubectl get pods -n vault
kubectl exec -n vault vault-0 -- vault operator raft list-peers
```

All 3 nodes must appear in the Raft peer list before proceeding.

---

### Step 1 - Identify the Active Leader

Run for each pod until you find the active one.

```bash
kubectl exec -n vault vault-0 -- vault status | grep "HA Mode"
kubectl exec -n vault vault-1 -- vault status | grep "HA Mode"
kubectl exec -n vault vault-2 -- vault status | grep "HA Mode"
```

Note the pod showing `active`. The others will show `standby`.

---

### Step 2 - Open a Watch Window

In a second terminal, watch pod status in real time.

```bash
kubectl get pods -n vault -w
```

---

### Step 3 - Kill the Active Leader

```bash
kubectl delete pod <active-pod-name> -n vault
```

---

### Step 4 - Observe Leader Election

In the watch window you will see the deleted pod enter Terminating state.
Within 2-10 seconds one of the standby pods wins the Raft election and becomes active.

Verify:

```bash
kubectl exec -n vault <any-remaining-pod> -- vault status | grep "HA Mode"
```

---

### Step 5 - Confirm Rejoin

Wait for Kubernetes to restart the deleted pod (Running state), then confirm it rejoined as standby.

```bash
kubectl exec -n vault vault-0 -- vault operator raft list-peers
```

All 3 nodes should appear again. The restarted pod shows as standby.

---

### What Is Happening Under the Hood

Vault HA with integrated storage uses the Raft consensus protocol.

- Only the active node accepts write requests. Standby nodes forward or redirect clients.
- Raft requires a quorum of (n/2)+1 nodes to elect a leader. With 3 nodes, 2 is sufficient.
- Before a write is committed, Raft replicates the log entry to a quorum. No data is lost when the leader dies mid-operation because uncommitted entries are replicated before acknowledgment.
- Election timeout is configurable. Default in Vault is 2-10 seconds.
- After restart, the former leader rejoins as a follower (standby) and syncs the log from the new leader.

---

## Key Takeaways

| Concept | Detail |
|---|---|
| Write path | Active node only |
| Read path | Any node (with `vault read` forwarding) |
| Quorum | 2 of 3 nodes required |
| Election time | 2-10 seconds |
| Data loss on leader failure | None (committed entries are replicated) |
| Pod restart behavior | Rejoins as standby, syncs Raft log automatically |

# Bonus: Kubernetes Production Patterns

---

## B1. Auto-Unseal with Transit Secrets Engine

Replace manual unseal with a second Vault instance acting as the unseal provider via its Transit engine.

Tutorial: https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-transit

Tasks:
- Deploy a second Vault instance (`vault-transit`) in standalone mode
- Enable the Transit secrets engine on `vault-transit`, create a key named `autounseal`
- Create a policy granting `encrypt` and `decrypt` on `transit/encrypt/autounseal` and `transit/decrypt/autounseal`
- Generate a token with that policy
- Configure the primary Vault Helm values with a `seal "transit"` stanza pointing to `vault-transit`
- Initialize the primary Vault, confirm seal type shows `transit` in `vault status`
- Kill `vault-0`, confirm it auto-unseals on restart without operator input
- Confirm recovery keys are generated instead of unseal keys

---

## B2. Vault Agent Sidecar Injector

Deliver secrets into pods without any app code change via the mutating webhook that ships with the Helm chart.

Tutorial: https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar

Tasks:
- Confirm `vault-agent-injector` pod is running
- Create a KV v2 secret at `internal/database/config` with `username` and `password`
- Create a Kubernetes service account bound to a Vault role with read access to that path
- Deploy a test pod with these annotations:
  - `vault.hashicorp.com/agent-inject: "true"`
  - `vault.hashicorp.com/role: your-role`
  - `vault.hashicorp.com/agent-inject-secret-config: internal/data/database/config`
- Exec into the pod, confirm secret appears at `/vault/secrets/config`
- Add a template annotation to render the secret as `key=value` format instead of raw JSON
- Delete the pod, confirm secret re-injects on restart

---

## B3. Vault Secrets Operator (VSO)

Kubernetes-native alternative to the sidecar. Syncs Vault secrets into native Kubernetes Secret objects via CRDs.

Tutorial: https://developer.hashicorp.com/vault/tutorials/kubernetes/vault-secrets-operator

Tasks:
- Install VSO via Helm: `hashicorp/vault-secrets-operator`
- Create a `VaultConnection` CRD pointing to your Vault address
- Create a `VaultAuth` CRD using `method: kubernetes`, referencing a service account
- Create a `VaultStaticSecret` CRD targeting a KV v2 path
- Confirm a native Kubernetes Secret is created
- Update the value in Vault, verify VSO rotates the Kubernetes Secret within the `refreshAfter` interval
- Mount the resulting Secret into a pod as an env var and confirm the value

> Trade-off: VSO writes to etcd (base64, visible via `kubectl get secret`). Sidecar injector writes to pod tmpfs only, never touches etcd. For regulated workloads the sidecar approach is preferable.

---

## B4. PKI Secrets Engine - Internal TLS for Kubernetes Services

Replace manually managed cluster TLS certs with Vault-issued, auto-rotated certificates.

Tutorial: https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine

Tasks:
- Enable PKI at `pki/`, set `max_lease_ttl` to `87600h`, generate an internal root CA
- Enable a second PKI mount at `pki_int/`, generate a CSR, sign it with the root CA, import the signed cert back
- Create a role on `pki_int/` scoped to `svc.cluster.local` with a `24h` TTL
- Issue a cert for `postgres.postgres.svc.cluster.local`
- Revoke the cert manually and confirm it appears in the CRL
- Issue a new cert for the same FQDN and verify it works

---

## Developer Section: Secret Consumption Patterns

For developers who need to consume secrets from application code. Requires only a running Vault instance.

---

### D1. REST API via curl

Understand the raw HTTP API before using any SDK. Every language and tool can consume this.

Tutorial: https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-apis

Tasks:
- Start Vault in dev mode: `vault server -dev -dev-root-token-id root`
- Write a secret via the API:
  ```bash
  curl -H "X-Vault-Token: root" \
    -H "Content-Type: application/json" \
    -X POST -d '{"data":{"username":"admin","password":"s3cr3t"}}' \
    http://127.0.0.1:8200/v1/secret/data/myapp/config
  ```
- Read the secret back and parse the response with `jq`
- Authenticate via AppRole: POST to `/v1/auth/approle/login` with `role_id` and `secret_id`, extract `client_token`
- Re-read the secret using the AppRole token instead of root
- Call `/v1/sys/leases/renew` to renew the token before expiry
- Observe the error when calling with an expired or invalid token

> Key point: KV v2 responses nest secrets under `.data.data`, not `.data`. This trips up every developer once.

---

### D2. Python SDK (hvac)

Tutorial: https://developer.hashicorp.com/vault/docs/get-started/developer-qs

Tasks:
- Install: `pip install hvac`
- Connect and authenticate with a token:
  ```python
  import hvac
  client = hvac.Client(url='http://127.0.0.1:8200', token='root')
  assert client.is_authenticated()
  ```
- Write and read a KV v2 secret using `client.secrets.kv.v2`
- Authenticate using AppRole instead of a static token:
  ```python
  client.auth.approle.login(role_id='...', secret_id='...')
  ```
- If running inside a Kubernetes pod, authenticate using the service account JWT:
  ```python
  with open('/var/run/secrets/kubernetes.io/serviceaccount/token') as f:
      jwt = f.read()
  client.auth.kubernetes.login(role='myapp', jwt=jwt)
  ```
- Read a dynamic database credential from the path used in task 5
- Handle a missing secret: catch `hvac.exceptions.InvalidPath`
- Renew the token before expiry using `client.auth.token.renew_self()`

---

### D3. Secret Lease Lifecycle - TTL, Renewal, and Revocation

Tutorial: https://developer.hashicorp.com/vault/tutorials/secrets-management/lease-management

Tasks:
- Generate a dynamic database credential (reuse task 5's PostgreSQL setup)
- Note the `lease_id` and `lease_duration` in the response
- Renew the lease before expiry: `vault lease renew <lease_id>`
- Confirm the TTL resets up to `max_ttl`
- Attempt to renew past `max_ttl` - observe the error
- Revoke the lease manually: `vault lease revoke <lease_id>`
- Attempt to connect to the database with the revoked credential - confirm rejection
- Implement the same renewal in Python using `POST /v1/sys/leases/renew`

> Key point: apps that cache dynamic credentials must track TTL and renew proactively, not reactively on auth failure. A credential that expires mid-request causes a harder-to-debug error than a renewal failure.

---

### D4. Env Var Anti-Pattern vs. File-Based Secret

No external tutorial - lab exercise based on the most common developer mistake.

Tasks:
- Deploy an app that reads `DB_PASSWORD` from an env var sourced from a Kubernetes Secret
- Exec into the pod: run `env | grep DB_PASSWORD` - confirm plaintext in process environment
- Run `cat /proc/1/environ` - confirm secret is readable from the proc filesystem by any process in the container
- Switch the same app to the Vault Agent sidecar (B2): remove the env var, read the secret from `/vault/secrets/config` file instead
- Re-run both checks - confirm the secret no longer appears in env or proc
- REasoning: env vars survive core dumps, get captured by debug middleware, and are logged by misconfigured frameworks. File-based secrets on tmpfs do not.
----
  - cleanup the deployments by uninstalling all charts and deleting all volumes
    - detailed [here](./cleanup.md)
