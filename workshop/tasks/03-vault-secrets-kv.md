# Vault Workshop - Vault KV Secret Engine

In this section, we will explore the **KV (Key-Value)** Secret Engine in Vault. The KV Secret Engine is used to store, retrieve, and manage secrets in a simple key-value format. 

Vault supports two versions of the KV Secret Engine: **Version 1** and **Version 2**. We will first discuss the differences between the two versions and then proceed with step-by-step tasks to use both versions.

---

### **Differences Between KV Version 1 and KV Version 2**

| Feature                          | KV Version 1                         | KV Version 2                         |
|----------------------------------|---------------------------------------|---------------------------------------|
| **Versioning**                   | No versioning support.               | Supports versioning of secrets.      |
| **Automatic Metadata**           | Not available.                       | Metadata for secret versions.        |
| **Soft Deletes and Recovery**    | Not available.                       | Supports soft deletes and recovery.  |
| **Default Use Case**             | Simple key-value storage.            | Advanced use cases requiring version control. |

---

### **KV Version 1**

#### 1. **Enable KV Version 1**
Enable the KV Secret Engine at a specified path (`kv-v1` in this example) and configure it for Version 1.

```bash
vault secrets enable -path=kv-v1 -version=1 kv
```

#### 2. **Write Secrets to KV Version 1**
Store a secret (key-value pair) in the KV store.

```bash
vault kv put kv-v1/my-secret username="admin" password="password123"
```

#### 3. **Read Secrets from KV Version 1**
Retrieve the secret from the KV store.

```bash
vault kv get kv-v1/my-secret
```

#### 4. **Delete Secrets from KV Version 1**
Delete the secret.

```bash
vault kv delete kv-v1/my-secret
```

#### 5. **Verify KV secret deletion**
Verify that there is no secret.

```bash
vault kv get kv-v1/my-secret
```

---

### **KV Version 2**

#### 1. **Enable KV Version 2**
Enable the KV Secret Engine at a specified path (`kv2` in this example) and configure it for Version 2.

```bash
vault secrets enable -path=kv2 kv-v2
# OR
vault secrets enable -path=kv2 -version=2 kv
```

#### 2. **Write Secrets to KV Version 2**
Store a secret (key-value pair) in the KV store. This automatically creates version 1 of the secret.

```bash
vault kv put kv2/my-secret username="admin" password="password123"
```

#### 3. **Read Secrets from KV Version 2**
Retrieve the latest version of the secret.

```bash
vault kv get kv2/my-secret
```

#### 4. **Rewrite Secrets to KV Version 2**
Store a secret (key-value pair) in the KV store. This automatically creates version 1 of the secret.

```bash
vault kv put kv2/my-secret username="admin" password="differentpassword123"
```

#### 5. **Read again Secrets from KV Version 2**
Retrieve the latest version of the secret.

```bash
vault kv get kv2/my-secret
```

#### 6. **Read a Specific Version of a Secret**
Retrieve a specific version of the secret.

```bash
vault kv get -version=1 kv2/my-secret
# Or
vault kv get -version=2 kv2/my-secret
```

#### 7. **Delete Secrets from KV Version 2**
Delete a specific version of the secret.

```bash
vault kv delete kv2/my-secret
```

#### 8. **Undelete or Recover Secrets**
Recover a deleted version of the secret.

```bash
vault kv undelete -versions=1 kv2/my-secret
```

#### 9. **Permanently Destroy Secrets**
Permanently delete a version of the secret.

```bash
vault kv destroy -versions=1 kv2/my-secret
```

---

### Conclusion

In this section, we have explored both **KV Version 1** and **KV Version 2**, highlighting their differences and providing step-by-step tasks to enable, use, and manage secrets. KV Version 1 is suitable for simple use cases, while KV Version 2 provides advanced features like versioning and recovery.

Next: [Create Vault Policies](./04-vault-policies.md)
