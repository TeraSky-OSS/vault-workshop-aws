########################
# Import magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################

VAULT_REMOTE="http://172.16.26.220:8200/"
VAULT_REMOTE_TOKEN="REDACTED_VAULT_TOKEN"
VAULT_REMOTE_UNSEAL="REDACTED_UNSEAL_KEY"

PATH_YAML_SSH="$YAML_PATH/secret_ssh"
VAULT_SSH="172.16.85.154"
VAULT_SSH_USER="k8s"
VAULT_SSH_PASSWORD="REDACTED_PASSWORD"
VAULT_SSH_TARGET="$VAULT_SSH_USER@$VAULT_SSH"

clear

# Start demo here

caption "SSH Secret Engine in Vault"
echo ""

p "Connecting to remote vault..."
export VAULT_ADDR="$VAULT_REMOTE"
vault operator unseal $VAULT_REMOTE_UNSEAL > /dev/null
vault login $VAULT_REMOTE_TOKEN > /dev/null

echo ""

p "Enable SSH secret engine"
pe "vault secrets enable -path=ssh-client-signer ssh"

echo ""

p "Configure Vault CA for signing client keys"
pe "vault write ssh-client-signer/config/ca generate_signing_key=true"

echo ""

p "Retrieve and store Vault CA public key for SSH config"
pe "vault read -field=public_key ssh-client-signer/config/ca > $PATH_YAML_SSH/trusted-user-ca-keys.pem"

echo ""

p "Adding Vault CA public key to SSH configuration on our local machine that we will ssh to"
pe "sudo mv $PATH_YAML_SSH/trusted-user-ca-keys.pem /etc/ssh/trusted-user-ca-keys.pem"
p "sudo sed -i \"\$a TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem\" /etc/ssh/sshd_config"
sudo sed -i "$ a TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem" /etc/ssh/sshd_config
pe "sudo systemctl restart sshd.service"

echo ""

p "Create Vault role for signing SSH client keys"
p "vault write ssh-client-signer/roles/my-role -<<"EOH"
{
  "algorithm_signer": "rsa-sha2-256",
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": {
    "permit-pty": ""
  },
  "key_type": "ca",
  "default_user": "$VAULT_SSH_USER",
  "ttl": "30m0s"
}
EOH"
vault write ssh-client-signer/roles/my-role -<<"EOH"
{
  "algorithm_signer": "rsa-sha2-256",
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": {
    "permit-pty": ""
  },
  "key_type": "ca",
  "default_user": "k8s",
  "ttl": "30m0s"
}
EOH

echo ""

p "------------------ On Local Machine ------------------" 
p "Generate SSH key pair for Vault authentication"
pe "ssh-keygen -t rsa -C \"user@example.com\" -f $HOME/.ssh/vault_rsa -N ''" 

echo ""

p "Sign public key with Vault"
PUBLIC_KEY=$(cat $HOME/.ssh/vault_rsa.pub)
p "vault write ssh-client-signer/sign/my-role public_key=\$PUBLIC_KEY"
vault write ssh-client-signer/sign/my-role public_key="$PUBLIC_KEY"

echo ""

p "Save the signed public key"
p "vault write -field=signed_key ssh-client-signer/sign/my-role public_key=\$PUBLIC_KEY > $HOME/.ssh/vault_rsa-cert.pub"
vault write -field=signed_key ssh-client-signer/sign/my-role public_key="$PUBLIC_KEY" > $HOME/.ssh/vault_rsa-cert.pub

echo ""

p "View signed key metadata"
pe "ssh-keygen -Lf $HOME/.ssh/vault_rsa-cert.pub"

echo ""

p "SSH into the host machine using the signed key"
pe "ssh -i ~/.ssh/vault_rsa $VAULT_SSH_TARGET \"echo 'Successfully connected to machine using Vault secret ssh engine!'\""

p ""

# Cleanup
rm -f $HOME/.ssh/vault_rsa $HOME/.ssh/vault_rsa.pub $HOME/.ssh/vault_rsa-cert.pub > /dev/null
vault secrets disable ssh-client-signer/ > /dev/null
vault policy delete ssh_test > /dev/null
rm -f $PATH_YAML_SSH/trusted-user-ca-keys.pem > /dev/null
sudo sed -i '/TrustedUserCAKeys \/etc\/ssh\/trusted-user-ca-keys.pem/d' /etc/ssh/sshd_config > /dev/null
sudo systemctl restart sshd.service > /dev/null
export VAULT_ADDR="http://127.0.0.1:8200"
vault login $TOKEN_VAULT

clear
