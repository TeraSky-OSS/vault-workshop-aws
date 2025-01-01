#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault Log File Demo."
TYPE_SPEED=80
p "enabling auditing to a log file"
pe "vault audit enable file file_path=/var/log/vault_audit.log"

p "lets do some actions on vault:"
pe "vault secrets enable --path=kvtmp kv-v2"
pe "vault secrets enable --path=kvsecrets kv"
pe "vault kv put kvtmp/secret user=giraffe pass=salsa"
pe "vault kv put kvsecrets/secret user=xxx pass=yyy"
pe "vault kv get kvtmp/secret"
pe "vault kv get kvsecrets/secret"
pe "vault kv delete kvsecrets/secret"
pe "vault login asdasdaslkdjalkdsjlakjsdlakjdlaksjd"
pe "vault login dfjshdkfjhsdfuw4r982y34r98wefy98syf"

p "show vault log file"
pe "ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq"

p "let's list all non-null error fields along with their corresponding timestamps. This helps you gain some insight into the volume and error types logged by vault"
pe "ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq 'select(.error != null) | [.time,.error]'"

p "let's Count all requests and responses"
pe "ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq -n '[inputs | {Operation: .type}] | group_by(.Operation) | map({Operation: .[0].Operation, Count: length}) | .[]'"

p "let's break out the authentication display name counts for responses, we will set up a map of display names and counts where the values are not null."
pe "ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq -n '[inputs | {DisplayName: .auth.display_name | select(. != null)} ] | group_by(.DisplayName) | map({DisplayName: .[0].DisplayName, Count: length})  | .[]'"

p "This query breaks out all request operation types by count."
pe "ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq -n '[inputs | {Operation: .request.operation} ] | group_by(.Operation) | map({Operation: .[0].Operation, Count: length}) | .[]'"

p "let's Display the top 5 most busy endpoints based on their request counts"
pe "ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq -n '[inputs | {Path: .request.path} ] | group_by(.Path) | map({Path: .[0].Path, Count: length}) | sort_by(-.Count) | limit(5;.[])'"

p "You can query for errors and get their counts like this"
pe "ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq -n '[inputs | {Errors: .error} ] | group_by(.Errors) | map({Errors: .[0].Errors, Count: length}) | sort_by(-.Count) | .[]'"

p "It can be handy to know the request frequency by the value of the remote_address field in situations where inexplicable activity is occurring at a high volume"
pe "ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq -n '[inputs | {RemoteAddress: .request.remote_address} ] | group_by(.RemoteAddress) | map({RemoteAddress: .[0].RemoteAddress, Count: length}) | .[]'"

p "Path access by remote address"
pe "ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq -s 'group_by(.request.remote_address) | map({"remote_address": .[0].request.remote_address,"access": (group_by(.request.path) | map({"key":.[0].request.path,"value":length}) | from_entries)})'"

p "full info and features of vault log file can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/audit/file"
p "https://developer.hashicorp.com/vault/tutorials/monitoring/query-audit-device-logs"

p "Demo End."

vault secrets disable kvtmp
vault secrets disable kvsecrets
vault audit disable file