# #!/bin/bash

# ########################
# # include the magic
# ########################
# . demo-magic.sh

# # hide the evidence
# clear

# export AZURE_SUBSCRIPTION_ID="dea456a1-756d-4799-b2d6-07a0e0a2bb51"
# export AZURE_TENANT_ID="a982d310-fc08-418d-aca0-6b30ba7c0235"
# export AZURE_CLIENT_ID="fc1f194b-22b1-48bd-bc95-4fd1e7cc5346"
# export AZURE_CLIENT_SECRET="87868632-ca62-457f-b762-2d05bf2ff3e7"
# export AZURE_APP_OBJECT_ID="383ac0c3-c5c1-452e-9aaf-6d0261e6bb13"

# p "Vault AZURE Dynamic secrets Demo. - WIP"
# TYPE_SPEED=80
# p "Enable the AZURE secrets engine:"
# pe "vault secrets enable azure"

# p "Configure the credentials that Vault uses to communicate with AWS to generate the IAM credentials"
# p "vault write azure/config 
#     subscription_id=$AZURE_SUBSCRIPTION_ID 
#     tenant_id=$AZURE_TENANT_ID 
#     client_id=$AZURE_CLIENT_ID 
#     client_secret=$AZURE_CLIENT_SECRET"
# vault write azure/config \
#     subscription_id=$AZURE_SUBSCRIPTION_ID \
#     tenant_id=$AZURE_TENANT_ID \
#     client_id=$AZURE_CLIENT_ID \
#     client_secret=$AZURE_CLIENT_SECRET

# p "Configure a Vault role.A role may be set up with either an existing service principal, or a set of Azure roles that will be assigned to a dynamically created service principal."
# p "vault write azure/roles/my-role \
#     application_object_id=$AZURE_APP_OBJECT_ID \
#     ttl=1h"
# vault write azure/roles/my-role \
#     application_object_id=$AZURE_APP_OBJECT_ID \
#     ttl=1h

# p "Alternatively, to configure the role to create a new service principal with Azure roles"
# p "vault write azure/roles/my-role ttl=1h azure_roles=-<<EOF
#     [
#         {
#             "role_name": "Contributor",
#             "scope":  "/subscriptions/<uuid>/resourceGroups/Website"
#         }
#     ]
# EOF"

# p "After the secrets engine is configured and a user/machine has a Vault token with the proper permission, it can generate credentials."
# pe "vault read azure/creds/my-role"

# p "This endpoint generates a renewable set of credentials. The application can login using the client_id/client_secret and will have access provided by configured service principal or the Azure roles set in the "my-role" configuration."

# p "it also a good practice to rotate the initial root credentials,so it will only be accessible to vault"
# pe "vault write -f azure/rotate-root"

# p "If dynamic service principals are used, a list of Azure groups may be configured on the Vault role. When the service principal is created, it will be assigned to these groups. Similar to the format used for specifying Azure roles, Azure groups may be referenced by either their group_name or object_id. Group specification by name must yield a single matching group."
# p "for example:
# vault write azure/roles/my-role 
#     ttl=1h 
#     max_ttl=24h 
#     azure_roles=@az_roles.json 
#     azure_groups=@az_groups.json

# $ cat az_roles.json
# [
#   {
#     "role_name": "Contributor",
#     "scope":  "/subscriptions/<uuid>/resourceGroups/Website"
#   },
#   {
#     "role_id": "/subscriptions/<uuid>/providers/Microsoft.Authorization/roleDefinitions/<uuid>",
#     "scope":  "/subscriptions/<uuid>"
#   },
#   {
#     "role_name": "This won't matter as it will be overwritten",
#     "role_id": "/subscriptions/<uuid>/providers/Microsoft.Authorization/roleDefinitions/<uuid>",
#     "scope":  "/subscriptions/<uuid>/resourceGroups/Database"
#   }
# ]

# $ cat az_groups.json
# [
#   {
#     "group_name": "foo"
#   },
#   {
#     "group_name": "This won't matter as it will be overwritten",
#     "object_id": "a6a834a6-36c3-4575-8e2b-05095963d603"
#   }
# ]"

# p "If dynamic service principals are used, the option to permanently delete the applications and service principals created by Vault may be configured on the Vault role. When this option is enabled and a lease is expired or revoked, the application and service principal associated with the lease will be permanently deleted from the Azure Active Directory. As a result, these objects will not count toward the quota of total resources in an Azure tenant. When this option is not enabled and a lease is expired or revoked, the application and service principal associated with the lease will be deleted, but not permanently. These objects will be available to restore for 30 days from deletion."
# p "example configuration:
# vault write azure/roles/my-role permanently_delete=true ttl=1h azure_roles=-<<EOF
#     [
#         {
#             "role_name": "Contributor",
#             "scope":  "/subscriptions/<uuid>/resourceGroups/Website"
#         }
#     ]
# EOF"

# p "full info and features of vault AWS Dynamic secrets can be found on the official vault documentations at:"
# p "https://developer.hashicorp.com/vault/docs/secrets/azure"

# p "Demo End."

# vault secrets disable azure