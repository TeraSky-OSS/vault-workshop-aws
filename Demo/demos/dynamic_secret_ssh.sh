########################
# include the magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################

VAULT_SSH_HELPER="172.16.85.154"
VAULT_SSH_HELPER_USER="k8s"
VAULT_SSH_HELPER_PASSWORD="REDACTED_PASSWORD"

clear

# Start demo here

caption "SSH Dynamic Secret - One Time SSH Password"
echo ""

p "Enable SSH secret engine"
pe "vault secrets enable ssh"

p "Create an OTP role"
pe "vault write ssh/roles/otp_key_role \
    key_type=otp \
    default_user=$VAULT_SSH_HELPER_USER \
    cidr_list=0.0.0.0/0 "

P "Create an OTP credential for an IP of the remote host that belongs to otp_key_role"
vault write ssh/creds/otp_key_role ip=$VAULT_SSH_HELPER


# p "Create a policy that provides access to the ssh/creds/otp_key_role path."
# pe "vault policy write ssh_test -<<EOF
# # To list SSH secrets paths
# path "ssh/*" {
#   capabilities = [ "list" ]
# }
# # To use the configured SSH secrets engine otp_key_role role
# path "ssh/creds/otp_key_role" {
#   capabilities = ["create", "read", "update"]
# }
# EOF"

# pe "vault auth enable userpass"
# pe "vault write auth/userpass/users/$VAULT_SSH_HELPER_USER password='$VAULT_SSH_HELPER_PASSWORD' policies='ssh_test' "

# # ssh-keyscan -H $VAULT_SSH_HELPER >> ~/.ssh/known_hosts
# # ssh $VAULT_SSH_HELPER_USER@$VAULT_SSH_HELPER -i /home/$VAULT_SSH_HELPER_USER/.ssh/vault_demo.pem -- echo "Hello from SSH secret engine"

p "generate OTP"
pe "vault write ssh/creds/otp_key_role ip=$VAULT_SSH_HELPER"

# p "ssh connect using OTP"
pe "ssh -o PubkeyAuthentication=no $VAULT_SSH_HELPER_USER@$VAULT_SSH_HELPER"
# vault ssh -role otp_key_role -mode otp $VAULT_SSH_HELPER_USER@$VAULT_SSH_HELPER

# vault ssh -role otp_key_role -mode otp -strict-host-key-checking=no username@x.x.x.x



# Cleanup
vault secrets disable ssh > /dev/null
# vault secrets disable userpass > /dev/null
# vault policy delete ssh_test > /dev/null


p "SSH Dynamic Secret - End"
clear