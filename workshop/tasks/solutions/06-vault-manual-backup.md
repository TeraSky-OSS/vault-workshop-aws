Issues found:

1. Step 3 has no "Step 1" label - jumps straight to init block
2. After `snapshot restore`, vault-0 will restart and come sealed with the ORIGINAL keys, not the temp ones. The temp unseal step is valid but the restore wipes that init - the explanation is missing
3. `kubectl delete pod vault-0` in Step 2 is redundant - scaling to 0 and back to 1 already creates a fresh pod
4. port-forward is started before `vault login` but there is no `wait` or check - on slow machines the next command races against it
5. Step 4 "Confirm Vault is usable" says "Expect Sealed false after successful unseal" but at that point vault is still sealed - the unseal with original keys happens AFTER that block, making the comment wrong
6. The closing code block for the unseal section is never closed before the Conclusion

Here is the corrected version:

---

# Vault Workshop - Vault Manual Snapshot

In this section, we will create a manual snapshot of the Vault data, simulate a data loss by deleting Vault's data in Minikube, and then restore the snapshot to recover the Vault data.

---

### Step 1: Create a Manual Snapshot

1. Create a snapshot using the vault operator raft snapshot save command:
```bash
vault operator raft snapshot save vault-data.snap
```

2. Verify the snapshot file exists:
```bash
ls -l vault-data.snap
```

---

### Step 2: Simulate Data Loss

1. Scale down Vault, wipe the PVC data, then scale back up:
```bash
# Scale down vault so the PVC is released
kubectl scale statefulset vault -n vault --replicas=0

# Wait until vault-0 is gone (Ctrl+C to stop watching)
kubectl get pod -n vault -w

# Wipe the data via a temp pod mounting the same PVC
kubectl run vault-cleanup --rm --restart=Never \
  --namespace=vault \
  --image=busybox \
  --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data-vault-0"}}],"containers":[{"name":"vault-cleanup","image":"busybox","command":["sh","-c","rm -rf /vault/data/*"],"volumeMounts":[{"name":"data","mountPath":"/vault/data"}]}]}}' \
  --attach

# Scale vault back up
kubectl scale statefulset vault -n vault --replicas=1

# Wait for vault-0 to be Running
kubectl get pod -n vault -w
```

2. Confirm Vault sees an empty Raft store. You should see Initialized false and Sealed true - this is the simulated disaster:
```bash
kubectl exec -n vault vault-0 -- vault status
# Expect: Initialized false  (empty Raft store after wipe)
#         Sealed      true
```

---

### Step 3: Restore the Snapshot

1. Vault requires an initialized and unsealed node before snapshot restore can run. Initialize a temporary single-key cluster and unseal it:
```bash
kubectl exec -n vault vault-0 -- vault operator init \
    -key-shares=1 \
    -key-threshold=1 \
    -format=json > temp_cluster-keys.json

VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" temp_cluster-keys.json)
kubectl exec -n vault vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY

# Confirm: Initialized true, Sealed false
kubectl exec -n vault vault-0 -- vault status
```

2. Start port-forward and wait for it to be ready, then point the Vault client at it:
```bash
kubectl port-forward svc/vault 8200:8200 -n vault &
sleep 2

export VAULT_ADDR="https://127.0.0.1:8200"
export VAULT_SKIP_VERIFY="true"

vault status
```

3. Log in with the temporary root token and restore the snapshot. The restore replaces all Raft data with the snapshot content, discarding the temporary init:
```bash
vault login $(jq -r ".root_token" temp_cluster-keys.json)

vault operator raft snapshot restore -force vault-data.snap
```

4. After restore, vault-0 restarts sealed with the original snapshot keys. Unseal it using the keys from when the snapshot was taken:

> Note: If you no longer have the original cluster-keys.json you cannot unseal the restored cluster. The temp keys from step 1 are gone - the restore overwrote them.

```bash
VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" cluster-keys.json)
kubectl exec -n vault vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
```

5. Confirm Vault is initialized, unsealed, and active:
```bash
vault status
# Expect: Initialized true
#         Sealed      false
```

---

### Conclusion

In this section, we created a manual snapshot, simulated data loss by wiping the PVC, and restored Vault from the snapshot. This process ensures you can recover Vault data in case of unexpected failures.

Next: [Cleanup](./cleanup)