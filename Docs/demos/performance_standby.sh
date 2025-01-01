#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault Performance Standby  Demo."
p "this is for HA betweem nodes in a single vault cluster"

p "after initializing the first vault nodes..."
p "on the new uninitialized node do..."
pe "vault operator raft join -tls-skip-verify http://IP OF FIRST NODE:8200"


p "now we run the following command on our HA instance to register it to our cluster"
p "so we first login to the ha vault"
export VAULT_ADDR=http://$VAULT_HA:8200
vault operator init > vlt_ha.txt
vault login $(grep -o 'Initial[^"]*' vlt_ha.txt | cut -c 21-)
p "and now on our ha vault we run the command:"
pe "vault write sys/replication/performance/secondary/enable token="$(grep -o 'wrapping_token:[^"]*' ha_secondary_token.txt | cut -c 34-)""
p "lets see our configuration"
pe "vault read -format=json sys/replication/performance/status | jq"

p "full info and features of vault Performance replication can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/enterprise/replication"

p "Demo End."

export VAULT_ADDR=http://$VAULT_IP:8200
vault login $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)
vault write -f sys/replication/performance/primary/disable
rm ha_secondary_token.txt