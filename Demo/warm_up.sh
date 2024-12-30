#!/bin/bash

########################
# Import Magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env
########################

clear
caption "Setting up Vault Cluster..."

p "Installing Vault..."
kubectl create ns $NAMESPACE 2> /dev/null
kubectl create secret generic vault-enterprise-license --from-file=license=./configuration/vault.hclic --namespace $NAMESPACE 2> /dev/null
helm upgrade -i $SERVICE_NAME hashicorp/vault --version 0.28.0 -f ./configuration/vault-values.yaml --namespace $NAMESPACE --create-namespace > /dev/null

wait_for_pod_by_label "statefulset.kubernetes.io/pod-name=$POD_NAME" $NAMESPACE


p "Initializing Vault..."

INIT_STATUS=$(kubectl exec $POD_NAME --namespace $NAMESPACE -- vault status -format=json | jq -r '.initialized')
if [ "$INIT_STATUS" == "true" ]; then
    p "Vault is already initialized."
else
    kubectl exec $POD_NAME -- vault operator init \
        -key-shares=1 \
        -key-threshold=1 \
        -format=json > cluster-keys.json 
fi

VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" cluster-keys.json)
TOKEN_VAULT=$(jq -r ".root_token" cluster-keys.json)
export VAULT_ADDR="http://127.0.0.1:8200"

p "Unsealing Vault..."
SEALED_STATUS=$(kubectl exec $POD_NAME --namespace $NAMESPACE -- vault status -format=json | jq -r '.sealed')
if [ "$SEALED_STATUS" == "false" ]; then
    p "Vault is already unsealed."
else
    kubectl exec -it $POD_NAME -- vault operator unseal $VAULT_UNSEAL_KEY
fi

p "Exposing Vault service..."
if !(pgrep -f "kubectl port-forward svc/$SERVICE_NAME $PORT:$PORT --namespace=$NAMESPACE" > /dev/null); then
    nohup kubectl port-forward svc/$SERVICE_NAME $PORT:$PORT --namespace=$NAMESPACE > /dev/null 2>&1 &
fi

p "Logging into Vault..."
vault login $TOKEN_VAULT

p "Done!"
clear

# Start workshop
read -p "Do you want to start the workshop? (y/n): " response

# Check the user's response
if [[ "$response" == "y" || "$response" == "Y" ]]; then
    bash demo.sh
fi

clear