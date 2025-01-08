#!/bin/bash

. ./configuration/env.sh

# Delete release
helm uninstall $SERVICE_NAME -n $NAMESPACE

# Delete Vault pvc's
kubectl delete pvc -n vault --all
rm -f cluster-keys.json

echo "Enviroment was deleted successfully"