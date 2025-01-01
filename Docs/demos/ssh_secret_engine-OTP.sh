#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear
TYPE_SPEED=80
p "Vault SSH secret engine Demo. One Time SSH Password"

p "enable SSH secret engine"
pe "vault secrets enable ssh"

p "Create an OTP role"
p "vault write ssh/roles/otp_key_role
    key_type=otp
    default_user=ubuntu
    cidr_list=0.0.0.0/0"

vault write ssh/roles/otp_key_role \
    key_type=otp \
    default_user=ubuntu \
    cidr_list=0.0.0.0/0

p "Create a policy file named, test.hcl, that provides access to the ssh/creds/otp_key_role path."
tee test.hcl <<EOF
# To list SSH secrets paths
path "ssh/*" {
  capabilities = [ "list" ]
}
# To use the configured SSH secrets engine otp_key_role role
path "ssh/creds/otp_key_role" {
  capabilities = ["create", "read", "update"]
}
EOF

pe "vault policy write test ./test.hcl"
vault auth enable userpass
vault write auth/userpass/users/ubuntu password="training" policies="test"

ssh-keyscan -H $VAULT_SSH_HELPER >> ~/.ssh/known_hosts
ssh ubuntu@$VAULT_SSH_HELPER -i /home/ubuntu/.ssh/vault_demo.pem -- sudo vault-ssh-helper -verify-only -dev -config /etc/vault-ssh-helper.d/config.hcl
# ssh ubuntu@$VAULT_SSH_HELPER -i /home/ubuntu/.ssh/vault_demo.pem -- sudo systemctl restart sshd

p "generate OTP"
pe "vault write ssh/creds/otp_key_role ip=$VAULT_SSH_HELPER"

p "ssh connect using OTP"
pe "ssh -o PubkeyAuthentication=no ubuntu@$VAULT_SSH_HELPER"

p "full info and features of vault SSH secret engine can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/tutorials/secrets-management/ssh-otp"

p "Demo End."

vault secrets disable ssh
vault secrets disable userpass
vault policy delete test
rm test.hcl