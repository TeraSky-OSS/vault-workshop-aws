#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault Performance Replication High Availability Demo."
p "this is for creating a sync between 2 different vault clusters"
p "Initializing Vault HA"
ssh-keyscan -H $VAULT_HA >> ~/.ssh/known_hosts
ssh ec2-user@$VAULT_HA -i /home/ubuntu/.ssh/vault_demo.pem -- sudo /tmp/setup.sh

p "lets enable performance replication on vault:"
pe "vault write -f sys/replication/performance/primary/enable"
p "We will now create a secondary token for our HA cluster node."
p "vault write sys/replication/performance/primary/secondary-token id=vault2"
vault write sys/replication/performance/primary/secondary-token id=vault2 > ha_secondary_token.txt
cat ha_secondary_token.txt

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