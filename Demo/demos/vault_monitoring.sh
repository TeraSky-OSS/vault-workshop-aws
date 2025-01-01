#!/bin/bash

########################
# Include the magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################
clear

MONITOING_YAML_PATH="$YAML_PATH/monitoring"

# Start demo here

caption "Setting Up Vault Monitoring"
echo ""

p "Enabling Vault Auditing"
vault audit enable file file_path="/vault/logs/audit.log"

echo ""

p "Defining Prometheus ACL Policy in Vault"
p "vault policy write prometheus-metrics - << EOF
path "/sys/metrics" {
  capabilities = ["read"]
}
EOF"
vault policy write prometheus-metrics - << EOF
path "/sys/metrics" {
  capabilities = ["read"]
}
EOF

echo ""

p "Creating Vault Token for Prometheus"
p "vault token create
  -field=token
  -policy prometheus-metrics
  > $MONITOING_YAML_PATH/prometheus-token"
vault token create -field=token -policy prometheus-metrics > $MONITOING_YAML_PATH/prometheus-token

echo ""

p "Creating Kubernetes Secret for Prometheus Token"
pe "kubectl create secret generic prometheus-token --from-file=prometheus-token=$MONITOING_YAML_PATH/prometheus-token -n monitoring"

echo ""

p "Applying Vault Dashboard Configuration"
pe "kubectl apply -f $MONITOING_YAML_PATH/grafana_dashboard_vault.yaml"

echo ""

p "Installing Kube Prometheus Stack via Helm"
helm upgrade -i kube-prometheus-stack prometheus-community/kube-prometheus-stack -f ./configuration/yamls/monitoring/values.yaml -n monitoring
wait_for_pod_by_label "app.kubernetes.io/name=grafana" "monitoring"

echo ""

p "Exposing Grafana Service"
nohup kubectl --namespace monitoring port-forward svc/kube-prometheus-stack-grafana 8080:80 > /dev/null 2>&1 &

p "Access Grafana at http://127.0.0.1:8080/d/vaults/hashicorp-vault
User Name: admin
Password: password"

caption "Setting Up Vault Monitoring - Done"

# Cleanup
vault audit disable file/ > /dev/null
vault token lookup $(cat $MONITOING_YAML_PATH/prometheus-token) > /dev/null
vault policy delete prometheus-metrics > /dev/null
kubectl delete -n monitoring -f $MONITOING_YAML_PATH/grafana_dashboard_vault.yaml > /dev/null
kubectl delete secret -n monitoring prometheus-token > /dev/null
helm uninstall kube-prometheus-stack -n monitoring > /dev/null
rm -fr $MONITOING_YAML_PATH/prometheus-token > /dev/null


clear
