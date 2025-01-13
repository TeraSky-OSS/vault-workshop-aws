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
   Check that the snapshot file has been created.
   ```bash
   ll vault-data.snap
   ```

---

### **Step 2: Simulate Data Loss**

1. **Delete Vault data**:
   Delete raft directory to simulate data loss.
   ```bash
   kubectl exec -it vault-0 -- rm -fr /vault/data
   ```

2. **Restart the Vault pod**:
   Restart the Vault pod to confirm that the data is no longer available.
   ```bash
   kubectl delete pod -n vault vault-0
   kubectl get pods -n vault
   ```

   When the pod restarts, Vault will not function correctly due to missing data.

---

### **Step 3: Restore the Snapshot**

1. **Recreate the persistent volume and claim**:
   Recreate the storage for Vault. You can use the same YAML configuration used during the initial setup or let the Helm chart manage it:
   ```bash
   helm upgrade -i vault hashicorp/vault --version 0.28.0 -f vault-values.yaml --namespace vault --create-namespace
   kubectl delete pod -n vault vault-0
   ```

   > **Note**: Vault is now not initialized and practically is a new vault cluster we will need to reinitialize it and unseal it and the restore the data.

2. **Restore the snapshot**:
   Use the snapshot file created earlier to restore the Vault data.
   ```bash
   vault operator raft snapshot restore -force vault-data.snap
   ```

3. **Verify the restoration**:
   Check that the data has been restored and Vault is operational.
   ```bash
   vault status
   ```

4. **Unseal Vault**:
   ```bash
   vault operator unseal $VAULT_UNSEAL_KEY
   ```

   > **Note**: Use the old unseal keys since we restored the vault cluster.
   > **Note**: Inspect all the changes we made along the workshop and see that everything exists.

---

### **Conclusion**

In this section, we successfully created a manual snapshot of the Vault data, simulated a data loss by deleting the Vault data in kubernetes, and restored the Vault using the snapshot. This process ensures that you can recover your Vault data in case of unexpected failures.

Next: [Cleanup](./cleanup)
