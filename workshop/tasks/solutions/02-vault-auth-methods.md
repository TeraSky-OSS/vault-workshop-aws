# Vault Workshop - Configure Vault Auth Methods

In this section, we will configure four different authentication methods in Vault: **AppRole**, **Token**, and **Kubernetes**. 
Each method will be configured with specific tasks, followed by instructions on how to log in using the respective method.

### 1. **AppRole Authentication**

**AppRole** is an authentication method that allows machines or applications to authenticate with Vault using a role-based approach. The AppRole method is commonly used for automated workflows.

#### Tasks:
1. **Enable the AppRole authentication method**:
   ```bash
   vault auth enable approle
   ```

2. **Create an AppRole**:
   Define the policies and set up the AppRole.
   ```bash
   vault write auth/approle/role/my-role policies="default" secret_id_ttl="10m" token_ttl="20m" token_max_ttl="30m"
   ```

3. **Retrieve the Role ID**:
   The Role ID is used by applications to authenticate.
   ```bash
   ROLE_ID=$(vault read -field=role_id auth/approle/role/my-role/role-id)
   ```

4. **Create a Secret ID**:
   The Secret ID is used along with the Role ID to authenticate.
   ```bash
   SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/my-role/secret-id)
   ```

5. **Login with AppRole**:
   Use the Role ID and Secret ID to authenticate.
   ```bash
   vault write auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID"
   ```
   
   - After successful authentication, Vault will return a client token.

#### Logging in with AppRole:
With `ROLE_ID` and `SECRET_ID` set `VAULT_TOKEN` from the login response so the CLI uses this AppRole. Either copy the `token` value from step 5, or capture it in one step:

```bash
export VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")
```

Example: verify the token and see its TTL and policies:

```bash
vault token lookup
```

The AppRole token only has the `default` policy. For the rest of this workshop, set `VAULT_TOKEN` to the **root token** from `cluster-keys.json`:

```bash
export VAULT_TOKEN=$(jq -r ".root_token" cluster-keys.json)
```

---


### 2. **Kubernetes Authentication**

**Kubernetes** authentication allows applications running within a Kubernetes cluster to authenticate with Vault.

#### Tasks:
1. **Enable the Kubernetes authentication method**:
   ```bash
   vault auth enable kubernetes
   ```

2. **Configure the Kubernetes authentication method**:
   Set up Vault to authenticate using the Kubernetes service account.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: default
  namespace: default
  annotations:
    kubernetes.io/service-account.name: default
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: default-tokenreview
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: default
  namespace: default
EOF
```

   Vault will ask the Kubernetes API whether incoming pod tokens are valid (**TokenReview**). The next commands collect what Vault needs for that: the **API server URL** (`KUBE_HOST`), the **cluster CA** so TLS to the API is trusted (`KUBE_CA_CERT`), and a **JWT for the `default` service account** (`TOKEN_REVIEW_JWT`) that is allowed to call TokenReview (via the `system:auth-delegator` binding above).

   ```bash
   TOKEN_REVIEW_JWT=$(kubectl get secret default -n default -o go-template='{{ .data.token }}' | base64 --decode)
   KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)
   KUBE_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
   ```
   
   ```bash
   vault write auth/kubernetes/config \
     kubernetes_host="$KUBE_HOST" \
     kubernetes_ca_cert="$KUBE_CA_CERT" \
     token_reviewer_jwt="$TOKEN_REVIEW_JWT"
   ```


3. **Create a Kubernetes role**:

   Define a Vault role that Kubernetes pods (or service accounts) can use to log in. **`bound_service_account_names`** and **`bound_service_account_namespaces`** limit which identities may use this role. **`audience`** must match the JWT’s **`aud`** claim so Vault only accepts tokens meant for the Kubernetes API.
   ```bash
   vault write auth/kubernetes/role/my-role \
     bound_service_account_names="default" \
     bound_service_account_namespaces="default" \
     audience="https://kubernetes.default.svc.cluster.local" \
     policies="default" \
     ttl="1h"
   ```

4. **Log in from a real pod**:
   The `TOKEN_REVIEW_JWT` you used in step 2 is only for Vault’s **TokenReview** calls to the API. A normal workload does not use that secret on your laptop—it uses the token Kubernetes **mounts into the pod** at `/var/run/secrets/kubernetes.io/serviceaccount/token` (for the pod’s service account).

   Start a short-lived pod in **`default`** with the **`default`** service account (same bounds as `my-role`). From inside the cluster, point the CLI at the Vault **Service** created by Helm (`vault` in namespace `vault`). This workshop uses TLS on Vault; `VAULT_SKIP_VERIFY=true` keeps the example short—in production you would trust Vault’s CA inside the pod instead.

   ```bash
   kubectl run vault-k8s-login -n default --rm -it --restart=Never \
     --image=hashicorp/vault:1.21.1 \
     --env "VAULT_ADDR=https://vault.vault.svc.cluster.local:8200" \
     --env "VAULT_SKIP_VERIFY=true" \
     --command -- /bin/sh
   ```

   Inside the pod shell, read the mounted service account JWT and log in with **`my-role`**:

   ```bash
   JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
   vault write auth/kubernetes/login role="my-role" jwt="$JWT"
   ```

   ```bash
   export VAULT_TOKEN=$(vault write -field=token auth/kubernetes/login role="my-role" jwt="$JWT")
   vault token lookup
   ```

   Type `exit` when finished; `--rm` parameter deletes the pod automatically.

#### Logging in with Kubernetes:
That flow mirrors how an application running in the cluster authenticates: it uses **its** projected or mounted service account token.

---

### Conclusion

In this section, we have covered the process of configuring and logging in with four different authentication methods in Vault: AppRole, Token, and Kubernetes. Each method has its specific use cases, and you can use the method that best fits your needs for managing access to Vault.


Next: [Use Vault KV Secret Engine](./03-vault-secrets-kv.md)

