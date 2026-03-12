# Vault Workshop - Create Vault Policies

In this section, we will explore Vault policies, create and assign them to tokens, and test how policies control access to Vault resources. Policies define the level of access a user or application has to Vault's secrets and functionalities.

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

### **Step 3: Generate Tokens with Specific Policies**

1. **Create a token with the `readonly` policy**:
   ```bash
   vault token create -policy="readonly" -ttl="1h"
   ```
   Save the generated token for testing.

2. **Create a token with the `readwrite` policy**:
   ```bash
   vault token create -policy="readwrite" -ttl="1h"
   ```
   Save this token as well.

3. **Create a token with the `admin` policy**:
   ```bash
   vault token create -policy="admin" -ttl="1h"
   ```
   Save this token for later use.

---

### **Step 4: Test Access with Different Tokens**

1. **Login with the `readonly` token**:
   ```bash
   vault login <readonly-token>
   ```

   - Attempt to read a secret:
     ```bash
     vault kv get secret/data/example
     ```
     This should succeed.

   - Attempt to write a secret:
     ```bash
     vault kv put secret/data/example key="new-value"
     ```
     This should fail because the `readonly` policy only allows reading and listing secrets.

2. **Login with the `readwrite` token**:
   ```bash
   vault login <readwrite-token>
   ```

   - Attempt to read a secret:
     ```bash
     vault kv get secret/data/example
     ```
     This should succeed.

   - Attempt to write a secret:
     ```bash
     vault kv put secret/data/example key="new-value"
     ```
     This should succeed because the `readwrite` policy allows creating, updating, and deleting secrets.

   - Attempt to perform an admin operation, such as enabling a new secret engine:
     ```bash
     vault secrets enable -path=my-secrets kv
     ```
     This should fail because `readwrite` policy lacks `sudo` capabilities.

3. **Login with the `admin` token**:
   ```bash
   vault login <admin-token>
   ```

   - Attempt to perform an admin operation, such as enabling a new secret engine:
     ```bash
     vault secrets enable -path=my-secrets kv
     ```
     This should succeed because the `admin` policy has `sudo` capability, allowing full administrative access.

---

### **Step 5: Verify Policy Enforcement**

1. **List policies assigned to a token**:
   For any token, you can verify the assigned policies:
   ```bash
   vault token lookup <token>
   ```

2. **Test access to restricted paths**:
   - Try accessing paths that are not covered by the assigned policy to see how Vault enforces restrictions. For example, a `readonly` token should not be able to create or delete secrets.

---

### **Conclusion**

In this section, we explored how to define and configure Vault policies, generate tokens with specific policies, and test their access to Vault resources. By using these policies, we can control who can access and modify secrets in Vault, ensuring that sensitive data is protected based on the principle of least privilege.

Next: [Use Vault Database Secret Engine](./05-vault-secrets-database.md)
