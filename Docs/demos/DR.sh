#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault Disaster Recovery Demo."
p "Initializing Vault DR"
ssh-keyscan -H $VAULT_DR >> ~/.ssh/known_hosts
ssh ec2-user@$VAULT_DR -i /home/ubuntu/.ssh/vault_demo.pem -- sudo /tmp/setup.sh

p "lets enable DR in our primary vault:"
pe "vault write -f sys/replication/dr/primary/enable"

p "We will now create a secondary token for our DR Vault instance"
p "vault write sys/replication/dr/primary/secondary-token id="dr-secondary""
vault write sys/replication/dr/primary/secondary-token id="dr-secondary" > dr_secondary_token.txt
cat dr_secondary_token.txt

p "now we run the following command on our DR instance to register it to our cluster"
p "so we first login to the dr vault"
export VAULT_ADDR=http://$VAULT_DR:8200
vault operator init > vlt_dr.txt
vault login $(grep -o 'Initial[^"]*' vlt_dr.txt | cut -c 21-)
p "and now on our dr vault we run the command:"
pe "vault write sys/replication/dr/secondary/enable token="$(grep -o 'wrapping_token:[^"]*' dr_secondary_token.txt | cut -c 34-)""
p "lets see our configuration"
pe "vault read -format=json sys/replication/dr/status | jq"

p "full info and features of vault DR can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/tutorials/enterprise/disaster-recovery"

p "Demo End."

export VAULT_ADDR=http://$VAULT_IP:8200
vault login $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)
vault write -f sys/replication/dr/primary/disable
rm dr_secondary_token.txt