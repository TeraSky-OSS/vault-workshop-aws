# Vault Workshop - Vault Manual Snapshot

In this section, we will create a manual snapshot of the Vault data, simulate a data loss by deleting Vault’s data in Minikube, and then restore the snapshot to recover the Vault data.

---

### **Step 1: Create a Manual Snapshot**

1. **Create a snapshot**:
   Use the `vault operator raft snapshot save` command to create a snapshot of the Vault data.
   ```bash
   vault operator raft snapshot save vault-data.snap
   ```

2. **Verify the snapshot**:
   Check that the snapshot file exists on your machine (where you ran `vault operator raft snapshot save`).
   ```bash
   ls -l vault-data.snap
   ```

---

### **Step 2: Simulate Data Loss**

1. **Delete Vault data**:
   ```bash
   # Scale down vault
   kubectl scale statefulset vault -n vault --replicas=0
   
   # Wait until vault-0 disappears (Ctrl+C to stop watching)
   kubectl get pod -n vault -w
   
   # Now delete the data via a temp pod using the same PVC
   kubectl run vault-cleanup --rm --restart=Never \
  --namespace=vault \
  --image=busybox \
  --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data-vault-0"}}],"containers":[{"name":"vault-cleanup","image":"busybox","command":["sh","-c","rm -rf /vault/data/*"],"volumeMounts":[{"name":"data","mountPath":"/vault/data"}]}]}}' \
  --attach
   
   
   # Scale vault back up
   kubectl scale statefulset vault -n vault --replicas=1
   kubectl get pod -n vault
   ```

2. **Restart the Vault pod and confirm Vault is broken**:
   Force a new pod so it mounts the **empty** data volume, then check the cluster and Vault itself.

   ```bash
   kubectl delete pod -n vault vault-0
   kubectl get pods -n vault
   ```

   When `vault-0` is **Ready**, ask Vault for status from inside the pod. You should see a **bad** state **`Initialized false`** (empty Raft store, like a brand-new node) and **`Sealed true`**. That is the simulated disaster: **no usable Vault data**.

   ```bash
   kubectl exec -n vault vault-0 -- vault status
   # Expect Initialized         false  (empty Raft data after the wipe)
   #        Sealed              true
   ```

---

### **Step 3: Restore the Snapshot**


Now need to initialize the vault, creating a temporary one, and unseal it for the restore command to succeed
```bash
kubectl exec -n vault vault-0 -- vault operator init \
    -key-shares=1 \
    -key-threshold=1 \
    -format=json > temp_cluster-keys.json

kubectl exec -n vault -it vault-0 -- vault status

VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" temp_cluster-keys.json)
kubectl exec -n vault -it vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
```
2. **Restore the snapshot**:
   Use the snapshot file created earlier to restore the Vault data.
   ```bash

   # Start port forwarding
   kubectl port-forward svc/vault 8200:8200 -n vault &
```
Configure vault client towards the vault in the minikube
```bash
export VAULT_ADDR="https://127.0.0.1:8200"
export VAULT_SKIP_VERIFY="true"



vault status
vault login $(jq -r ".root_token" temp_cluster-keys.json)

# Restore the snapshot
   vault operator raft snapshot restore -force vault-data.snap

   

4. **Confirm Vault is usable again**:
   ```bash
   kubectl exec -n vault vault-0 -- vault status
   # Expect Sealed  false  after a successful unseal
   ```


> **Note:** If you no longer have the original `cluster-keys.json`, you cannot unseal the restored cluster unless you have another copy of the unseal keys from **when the snapshot was taken**.

Unseal the vault with the original unseal key and check the status
```sh
VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" cluster-keys.json)
kubectl exec -n vault -it vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY

vault status

---

### **Conclusion**

In this section, we successfully created a manual snapshot of the Vault data, simulated a data loss by deleting the Vault data in kubernetes, and restored the Vault using the snapshot. This process ensures that you can recover your Vault data in case of unexpected failures.

Next: [Cleanup](./cleanup)
