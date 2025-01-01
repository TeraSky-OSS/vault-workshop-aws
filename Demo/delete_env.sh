#!/bin/bash

. ./configuration/env.sh

# Delete release
helm uninstall $SERVICE_NAME -n $NAMESPACE

# Delete Vault pv's,pvc's
kubectl delete pvc -n vault --all
kubectl delete pv -n vault --all

echo "Enviroment was deleted successfully"