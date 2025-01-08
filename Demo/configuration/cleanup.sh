#!/bin/bash

#######################################
# Global
#######################################
. ./env.sh 2> /dev/null 
TOKEN_VAULT=$(jq -r ".root_token" ../cluster-keys.json)
vault login $TOKEN_VAULT > /dev/null
export VAULT_ADDR="http://127.0.0.1:8200"
YAML_PATH="./yamls"

# Function to clean up Dynamic Secret k8s
cleanup_dynamic_secret_k8s() {
    local K8S_YAML_PATH="$YAML_PATH/k8s_dynamic_secrets"
    vault secrets disable kubernetes/ > /dev/null
    kubectl delete -f $K8S_YAML_PATH/k8s-full-secrets-abilities-with-labels.yaml > /dev/null
    kubectl delete -f $K8S_YAML_PATH/vault-token-creator-binding.yaml > /dev/null
}

# Function to clean up Dynamic Secret SSH
cleanup_dynamic_secret_ssh() {
    local PATH_YAML_SSH="$YAML_PATH/secret_ssh"
    rm -f $HOME/.ssh/vault_rsa $HOME/.ssh/vault_rsa.pub $HOME/.ssh/vault_rsa-cert.pub > /dev/null
    vault secrets disable ssh-client-signer/ > /dev/null
    vault policy delete ssh_test > /dev/null
    rm -f $PATH_YAML_SSH/trusted-user-ca-keys.pem > /dev/null
    sudo sed -i '/TrustedUserCAKeys \/etc\/ssh\/trusted-user-ca-keys.pem/d' /etc/ssh/sshd_config > /dev/null
    sudo systemctl restart sshd.service > /dev/null
}

# Function to clean up LDAP
cleanup_ldap() {
    local PATH_YAML_LDAP="$YAML_PATH/ldap"
    vault auth disable ldap > /dev/null
    vault secrets disable ldap > /dev/null
    helm uninstall ldap -n ldap > /dev/null &
    kubectl delete ns ldap --force  > /dev/null 2>&1
    kubectl delete pvc -n ldap --all > /dev/null
    kubectl delete configmap ldap-setup -n default > /dev/null
    kubectl delete -f $PATH_YAML_LDAP/ldap-client.yaml > /dev/null
}

# Function to clean up PKI
cleanup_pki() {
    rm -f ../root_2024_ca.crt ../intermediate.cert.pem ../pki_intermediate.csr > /dev/null
    vault delete pki/roles/2024-servers > /dev/null
    vault delete pki_int/roles/example-dot-com > /dev/null
    vault secrets disable pki > /dev/null
    vault secrets disable pki_int > /dev/null
}

# Function to clean up Sentinel
cleanup_sentinel() {
    vault secrets disable kv-v2 > /dev/null
    vault policy delete cidr-check > /dev/null
    vault policy delete business-hrs > /dev/null
    vault policy delete tester > /dev/null
    vault delete sys/policies/egp/business-hrs > /dev/null
    vault delete sys/policies/egp/cidr-check > /dev/null
    rm -f ../sentinel_0.16.1_linux_amd64.zip > /dev/null
    sudo rm -f /usr/local/bin/sentinel > /dev/null
}

# Function to clean up Vault Agent Deployment
cleanup_vault_agent() {
    local PATH_YAML_VAULT_AGENT="$YAML_PATH/vault_agent"
    kubectl delete -f $PATH_YAML_VAULT_AGENT/ > /dev/null
    kubectl delete serviceaccount myapp-sa -n default > /dev/null
    vault secrets disable secret > /dev/null
    vault auth disable kubernetes > /dev/null
}

# Function to clean up Vault Automatic Backups
cleanup_vault_backups() {
    vault delete sys/storage/raft/snapshot-auto/config/testsnap > /dev/null
    kubectl exec $POD_NAME --namespace $NAMESPACE -- rm -fr "/vault/backups" > /dev/null
}

# Function to clean up Vault Monitoring
cleanup_vault_monitoring() {
    local MONITOING_YAML_PATH="$YAML_PATH/monitoring"
    vault audit disable file/ > /dev/null
    vault token lookup $(cat $MONITOING_YAML_PATH/prometheus-token) > /dev/null
    vault policy delete prometheus-metrics > /dev/null
    kubectl delete -n monitoring -f $MONITOING_YAML_PATH/grafana_dashboard_vault.yaml > /dev/null
    kubectl delete secret -n monitoring prometheus-token > /dev/null
    helm uninstall kube-prometheus-stack -n monitoring > /dev/null &
    kubectl delete ns monitoring --force  > /dev/null 2>&1
    rm -fr $MONITOING_YAML_PATH/prometheus-token > /dev/null
}

# Function to clean up Vault Secret Operator
cleanup_vault_secret_operator() {
    local VSO_YAML_PATH="$YAML_PATH/vso"
    kubectl delete -f "$VSO_YAML_PATH/" > /dev/null
    helm uninstall -n vault-secrets-operator vault-secrets-operator > /dev/null &
    kubectl delete ns vault-secrets-operator --force  > /dev/null 2>&1
    vault secrets disable secret > /dev/null
    vault auth disable kubernetes > /dev/null
    vault policy delete app-read-policy > /dev/null
}

# Main cleanup logic
if [[ -z $1 ]]; then
    echo "No demo specified for cleanup."
    exit 1
fi

case $1 in
    dynamic_secret_k8s) cleanup_dynamic_secret_k8s ;;
    dynamic_secret_ssh) cleanup_dynamic_secret_ssh ;;
    ldap) cleanup_ldap ;;
    pki) cleanup_pki ;;
    sentinel_policies) cleanup_sentinel ;;
    vault_agent_deployment) cleanup_vault_agent ;;
    vault_automaic_backups) cleanup_vault_backups ;;
    vault_monitoring) cleanup_vault_monitoring ;;
    vault_secret_operator) cleanup_vault_secret_operator ;;
    *) echo "Invalid demo specified: $1"; exit 1 ;;
esac
