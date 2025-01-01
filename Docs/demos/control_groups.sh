#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault Control group Demo."
p "lets create a policy named read-gdpr-order"
p "tee read-gdpr-order.hcl <<EOF
path "secret/data/orders/*" {
  capabilities = [ "read" ]

  control_group = {
    factor "authorizer" {
      identity {
        group_names = [ "acct_manager" ]
        approvals = 1
      }
    }
  }
}
EOF
"
tee read-gdpr-order.hcl <<EOF
path "secret/data/orders/*" {
  capabilities = [ "read" ]

  control_group = {
    factor "authorizer" {
      identity {
        group_names = [ "acct_manager" ]
        approvals = 1
      }
    }
  }
}
EOF
p "The condition in the policy is that Bob can read the secrets at secret/data/orders/* if someone from the acct_manager group approves"

p "Now we will create another policy named acct_manager. This policy is needed for the members of controller (acct_manager) to approve Bob's request."
p "tee acct_manager.hcl <<EOF
# To approve the request
path "sys/control-group/authorize" {
    capabilities = ["create", "update"]
}

# To check control group request status
path "sys/control-group/request" {
    capabilities = ["create", "update"]
}
EOF"
tee acct_manager.hcl <<EOF
# To approve the request
path "sys/control-group/authorize" {
    capabilities = ["create", "update"]
}

# To check control group request status
path "sys/control-group/request" {
    capabilities = ["create", "update"]
}
EOF
p "The important thing here is that the authorizer must have create and update permission on the sys/control-group/authorize endpoint so that they can approve the request."

p "lets deploy both policies"
pe "vault policy write read-gdpr-order read-gdpr-order.hcl"
pe "vault policy write acct_manager acct_manager.hcl"
p "after creating the policies, we will create a user bob and an acct_manager group with ellen as a group member."
pe "vault auth enable userpass"
pe "vault write auth/userpass/users/bob password="password""
pe "vault write auth/userpass/users/ellen password="password""

vault auth list -format=json | jq -r '.["userpass/"].accessor' > accessor.txt
vault write -format=json identity/entity name="Bob Smith" \
        policies="read-gdpr-order" \
        metadata=team="Processor" \
        | jq -r ".data.id" > entity_id_bob.txt

vault write identity/entity-alias name="bob" \
      canonical_id=$(cat entity_id_bob.txt) \
      mount_accessor=$(cat accessor.txt)

vault write -format=json identity/entity name="Ellen Wright" \
        policies="default" \
        metadata=team="Acct Controller" \
        | jq -r ".data.id" > entity_id_ellen.txt

vault write identity/entity-alias name="ellen" \
      canonical_id=$(cat entity_id_ellen.txt) \
      mount_accessor=$(cat accessor.txt)

p "now we create a acct_manager group and add Ellen's entity as a memnber"
p "vault write identity/group name="acct_manager" \
      policies="acct_manager" \
      member_entity_ids=$(cat entity_id_ellen.txt)"
vault write identity/group name="acct_manager" \
      policies="acct_manager" \
      member_entity_ids=$(cat entity_id_ellen.txt)

vault secrets enable -path=secret -version=2 kv
vault kv put secret/orders/acct1 order_number="12345678" product_id="987654321"

p "Now, lets do some testing. the secrets already been created in secret/ path"
p "lets login as Bob and try to read the secret at: secret/orders/acct1"
pe "vault login -method=userpass username="bob" password="password""
p "vault kv get secret/orders/acct1"
vault kv get secret/orders/acct1 > secret_request.txt
cat secret_request.txt
p "we got back a response with wrapping token and wrapping accessor"


p "now, A user who is a member of the acct_manager group can check and authorize Bob's request using the request and authorize commands."
p "so we login to vault as Ellen"
pe "vault login -method=userpass username="ellen" password="password""
p "and check the current status of the request"
pe "vault write sys/control-group/request accessor=$(grep -o 'wrapping_accessor:[^"]*' secret_request.txt | cut -c 34-)"
p "The approved status is currently false since it has not been approved."
p "lets approve the request"
pe "vault write sys/control-group/authorize accessor=$(grep -o 'wrapping_accessor:[^"]*' secret_request.txt | cut -c 34-)"
p "we can see the status is no Approved."
p "Since the control group requires one approval from a member of acct_manager group, the condition has been met. We will log back in as bob and unwrap the secret."
pe "vault login -method=userpass username="bob" password="password""
pe "vault unwrap $(grep -o 'wrapping_token:[^"]*' secret_request.txt | cut -c 34-)"

p "full info and features of vault control group can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/enterprise/control-groups"

p "Demo End."

vault login $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)
rm secret_request.txt
rm read-gdpr-order.hcl 
rm acct_manager.hcl
rm entity_id_ellen.txt
rm entity_id_bob.txt
vault secrets disable secret
vault policy delete read-gdpr-order
vault policy delete acct_manager