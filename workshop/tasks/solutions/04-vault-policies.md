# Vault Workshop - Create Vault Policies

In this section, we will define Vault **policies**, attach them to **Userpass** users (username + password)—similar to how many teams onboard operators—and test how those policies flow into the **tokens** Vault issues at login. Policies define what each identity may do in Vault.

---

### **Step 1: Enable the KV Secrets Engine (KV v2)**

Before we create policies, let's enable the KV v2 secrets engine and store some secrets for testing.

1. **Enable the KV v2 secrets engine**:
   If you haven't already, enable the KV v2 secrets engine at the `secret/` path:
   ```bash
   vault secrets enable -path=secret kv-v2
   ```

2. **Store some secrets in the KV v2 engine**:
   - Store a simple secret:
     ```bash
     vault kv put secret/data/example key="value"
     ```
   
   - Store another secret for testing:
     ```bash
     vault kv put secret/data/another-example username="admin" password="pass123"
     ```

3. **Verify the secrets**:
   - Retrieve the first secret:
     ```bash
     vault kv get secret/data/example
     ```

   - Retrieve the second secret:
     ```bash
     vault kv get secret/data/another-example
     ```

---

### **Step 2: Create Vault Policies**

1. **Define a policy for read-only access to a KV v2 secret engine**:
   Create a file named `readonly-policy.hcl` with the following content:
   ```
   cat > readonly-policy.hcl <<EOF
   path "secret/data/*" {
     capabilities = ["read", "list"]
   }
   EOF
   ```

2. **Define a policy for read-write access to a KV v2 secret engine**:
   Create a file named `readwrite-policy.hcl` with the following content:
   ```
   cat > readwrite-policy.hcl <<EOF
   path "secret/data/*" {
     capabilities = ["create", "read", "update", "delete", "list"]
   }
   EOF
   ```

3. **Define a policy for admin access**:
   Create a file named `admin-policy.hcl` with the following content:
   ```
   cat > admin-policy.hcl <<EOF
   path "*" {
     capabilities = ["create", "read", "update", "delete", "list", "sudo"]
   }
   EOF
   ```

4. **Write the policies to Vault**:
   Use the `vault policy write` command to store these policies in Vault:
   ```bash
   vault policy write readonly readonly-policy.hcl
   vault policy write readwrite readwrite-policy.hcl
   vault policy write admin admin-policy.hcl
   ```

---

### **Step 3: Create Userpass users and attach policies**

In a typical process, an admin **creates identities** (here, Userpass users) and assigns **policy names** to each user. When someone logs in, Vault issues a **token** that carries those policies—no need to hand-copy long token strings.

1. **Enable the Userpass auth method** (skip if you already enabled it in the auth-methods lab—Vault will say the path is already in use):
   ```bash
   vault auth enable userpass
   ```

2. **Create three users** and attach one policy each. The workshop uses the same password for simplicity; use **unique strong passwords** in production, and avoid putting real passwords on the command line (they can end up in shell history)—prefer an interactive `vault login` or a secret manager.

   | User | Policy | Intended role |
   |------|--------|----------------|
   | `demo-readonly` | `readonly` | Read/list KV only |
   | `demo-readwrite` | `readwrite` | Read/write KV |
   | `demo-admin` | `admin` | Broad admin-style access |

   ```bash
   vault write auth/userpass/users/demo-readonly \
     password="changeme" \
     policies="readonly"

   vault write auth/userpass/users/demo-readwrite \
     password="changeme" \
     policies="readwrite"

   vault write auth/userpass/users/demo-admin \
     password="changeme" \
     policies="admin"
   ```

---

### **Step 4: Log in as each user and test access**

If you still have **`VAULT_TOKEN` set** from the root token (or any earlier step), the CLI keeps using that value and **ignores** the token `vault login` writes to the token helper. Clear it before Userpass login:

```bash
unset VAULT_TOKEN
```

Use **Userpass login** so the CLI gets a fresh token for that user. Example (non-interactive—fine for the lab):

```bash
vault login -method=userpass username=demo-readonly password=changeme
```

1. **As `demo-readonly`** (after the `vault login` above):

   - Read a secret (should succeed):
     ```bash
     vault kv get secret/data/example
     ```

   - Write a secret (should **fail**—policy is read-only):
     ```bash
     vault kv put secret/data/example key="new-value"
     ```

2. **As `demo-readwrite`**:
   ```bash
   vault login -method=userpass username=demo-readwrite password=changeme
   ```

   - Read (should succeed):
     ```bash
     vault kv get secret/data/example
     ```

   - Write (should succeed):
     ```bash
     vault kv put secret/data/example key="new-value"
     ```

   - Enable a new secrets engine (should **fail**—no `sudo` on this policy):
     ```bash
     vault secrets enable -path=my-secrets kv
     ```

3. **As `demo-admin`**:
   ```bash
   vault login -method=userpass username=demo-admin password=changeme
   ```

   - Enable a new secrets engine (should succeed):
     ```bash
     vault secrets enable -path=my-secrets kv
     ```

---

### **Step 5: Verify policy enforcement**

1. **See policies on the token you are using**:
   After any `vault login` in step 4, Vault’s active token reflects the user’s attached policies. Inspect it:
   ```bash
   vault token lookup
   ```
   Check the **`policies`** line—for example, after logging in as `demo-readonly` you should see **`readonly`** (Vault may also include **`default`** depending on configuration).

2. **Optional: compare identities without switching the CLI token**:
   You can mint a one-off token for a user and inspect it (useful for scripts). Example for the read-only user:
   ```bash
   vault token lookup "$(vault write -field=token auth/userpass/login/demo-readonly password=changeme)"
   ```

3. **Try paths outside the policy**:
   For example, while logged in as `demo-readonly` or `demo-readwrite`, attempt paths under `secret/data/` that do not exist or operations the policy does not allow, and confirm Vault denies them.

---

### **Conclusion**

In this section, we defined policies, **bound them to Userpass users**, logged in like an operator would, and saw how Vault maps users → **tokens** → **allowed API paths**. The same policy documents can be attached to other auth methods (AppRole, LDAP, OIDC, and so on) for applications and integrations.

If a later workshop step expects the **root** token, switch back with `export VAULT_TOKEN=$(jq -r ".root_token" cluster-keys.json)` (from your `cluster-keys.json`).

Next: [Use Vault Database Secret Engine](./05-vault-secrets-database.md)
