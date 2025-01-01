#!/bin/bash

########################
# Import magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################
clear

BACKUP_PATH_IN_POD="/vault/backups"

# Start demo here

caption "Vault Automatic Backups"
echo ""

p "Enable Automated Snapshots"
p "vault write sys/storage/raft/snapshot-auto/config/testsnap 
     storage_type=local 
     file_prefix=testsnappy 
     interval=3s 
     retain=7 
     local_max_space=1000000 
     path_prefix=$BACKUP_PATH_IN_POD"

vault write sys/storage/raft/snapshot-auto/config/testsnap storage_type=local file_prefix=testsnappy interval=3s retain=7 local_max_space=1000000 path_prefix=$BACKUP_PATH_IN_POD

echo ""

p "Lets inspect the auto snapshot configuration"
pe "vault read sys/storage/raft/snapshot-auto/config/testsnap"

echo ""

p "Sleeping for 3 seconds..."
sleep 3

echo ""

pe "kubectl exec $POD_NAME --namespace $NAMESPACE -- ls $BACKUP_PATH_IN_POD"
p ""

# Cleanup
vault delete sys/storage/raft/snapshot-auto/config/testsnap > /dev/null
kubectl exec $POD_NAME --namespace $NAMESPACE -- rm -fr $BACKUP_PATH_IN_POD > /dev/null

clear