#!/bin/bash

########################
# Import Magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################

# Check expiration of license
EXPIRATION_DATE="2025-02-06"
CURRENT_DATE=$(date +"%Y-%m-%d")

# Check if the current date matches the expiration date
if [[ "$CURRENT_DATE" == "$EXPIRATION_DATE" ]]; then
    echo "The license is expired. Please provide a new license in './configuration/vault.hclic' file."
    exit 1
fi


clear
caption "Setting up Vault Cluster..."

p "Installing Vault..."
kubectl create ns $NAMESPACE > /dev/null 2>&1
kubectl create secret generic vault-enterprise-license --from-file=license=./configuration/vault.hclic --namespace $NAMESPACE > /dev/null 2>&1
helm upgrade -i $SERVICE_NAME hashicorp/vault --version 0.28.0 -f ./configuration/vault-values.yaml --namespace $NAMESPACE --create-namespace > /dev/null

wait_for_pod_by_label "statefulset.kubernetes.io/pod-name=$POD_NAME" $NAMESPACE


p "Initializing Vault..."

INIT_STATUS=$((kubectl exec vault-0 --namespace vault -- vault status -format=json | jq -r '.initialized') 2> /dev/null )
if [ "$INIT_STATUS" == "true" ]; then
    p "Vault is already initialized."
else
    kubectl exec $POD_NAME --namespace $NAMESPACE -- vault operator init \
        -key-shares=1 \
        -key-threshold=1 \
        -format=json > cluster-keys.json 
fi

VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" cluster-keys.json)
TOKEN_VAULT=$(jq -r ".root_token" cluster-keys.json)
export VAULT_ADDR="http://127.0.0.1:8200"

p "Unsealing Vault..."
SEALED_STATUS=$((kubectl exec $POD_NAME --namespace $NAMESPACE -- vault status -format=json | jq -r '.sealed') 2> /dev/null )
if [ "$SEALED_STATUS" == "false" ]; then
    p "Vault is already unsealed."
else
    kubectl exec -it $POD_NAME --namespace $NAMESPACE -- vault operator unseal $VAULT_UNSEAL_KEY
fi

p "Exposing Vault service..."
( kubectl port-forward svc/$SERVICE_NAME $PORT:$PORT --namespace=$NAMESPACE > /dev/null 2>&1 & )

p "Logging into Vault..."
vault login $TOKEN_VAULT

p "Done!"

# Start workshop
read -p "Do you want to start the workshop? (y/n): " response

# Check the user's response
if [[ "$response" == "y" || "$response" == "Y" ]]; then
    clear
    bash demo.sh
fi

clear