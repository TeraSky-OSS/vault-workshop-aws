#!/bin/bash

########################
# Import magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################
clear

PATH_YAML_SETNITNEL="$YAML_PATH/sentinel"

# Start demo here

caption "Setting Up Sentinel"
echo ""

p "Downloading and installing Sentinel..."
wget -q https://releases.hashicorp.com/sentinel/0.16.1/sentinel_0.16.1_linux_amd64.zip
sudo unzip -o sentinel_0.16.1_linux_amd64.zip -d /usr/local/bin > /dev/null
rm -f sentinel_0.16.1_linux_amd64.zip > /dev/null

echo ""

p "----------- Testing Sentinel Policies --------------"
echo ""

p "Inspecting 'cidr-check' policy:"
p "Enforces access based on IP address, allowing only specified IPs to interact with resources."
pe "cat "$PATH_YAML_SETNITNEL/cidr-check.sentinel" "

p "Defining a success scenario for 'cidr-check'"
pe "cat "$PATH_YAML_SETNITNEL/test/cidr-check/success.json" "

p "Defining a failure scenario for 'cidr-check'"
pe "cat "$PATH_YAML_SETNITNEL/test/cidr-check/fail.json" "

echo ""
echo "---------"
echo ""

p "Inspecting 'business hours' policy:"
p "Restricts access to resources based on business hours, allowing operations only during specified times."
pe "cat "$PATH_YAML_SETNITNEL/business-hrs.sentinel" "

p "Defining a success scenario for 'business hours'"
pe "cat "$PATH_YAML_SETNITNEL/test/business-hrs/success.json" "

p "Defining a failure scenario for 'business hours'"
pe "cat "$PATH_YAML_SETNITNEL/test/business-hrs/fail.json" "

echo ""

p "Executing policy tests..."
CURRENT_PATH=$(pwd)
cd $PATH_YAML_SETNITNEL
pe "sentinel test"
cd $CURRENT_PATH
echo ""

p "----------- Deploying Policies --------------"
echo ""

p "Encoding 'cidr-check' policy for deployment"
p "POLICY=\$(base64 -i $PATH_YAML_SETNITNEL/cidr-check.sentinel)"
POLICY=$(base64 -i $PATH_YAML_SETNITNEL/cidr-check.sentinel)

echo ""

p "Creating 'cidr-check' policy with hard-mandatory enforcement"
p "vault write sys/policies/egp/cidr-check
    policy="\${POLICY}"
    paths="secret/*"
    enforcement_level="hard-mandatory""
vault write sys/policies/egp/cidr-check policy="${POLICY}" paths="secret/*" enforcement_level="hard-mandatory"

echo ""
echo "----------"
echo ""

p "Encoding 'business-hrs' policy for deployment"
p "POLICY2=\$(base64 -i $PATH_YAML_SETNITNEL/business-hrs.sentinel)"
POLICY2=$(base64 -i $PATH_YAML_SETNITNEL/business-hrs.sentinel)

echo ""

p "Creating 'business-hrs' policy with soft-mandatory enforcement"
p "vault write sys/policies/egp/business-hrs
   policy="\${POLICY2}"
   paths="kv-v2/*"
   enforcement_level="soft-mandatory""
vault write sys/policies/egp/business-hrs policy="${POLICY2}" paths="kv-v2/*" enforcement_level="soft-mandatory"


echo ""

p "----------- Verifying Policies --------------"
echo ""

p "Creating tester policy for secret and kv-v2 paths"
p "vault policy write tester -<<EOF
path "secret/*" {
   capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv-v2/*" {
   capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
"
vault policy write tester -<<EOF
path "secret/*" {
   capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv-v2/*" {
   capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

echo ""

p "Creating a tester token with the 'tester' policy"
p "export TEST_TOKEN=\$(vault token create -policy="tester" -field=token) && echo \$TEST_TOKEN"
export TEST_TOKEN=$(vault token create -policy="tester" -field=token) && echo $TEST_TOKEN

echo ""

p "Testing 'cidr-check' policy by rejecting requests from unauthorized IP"
pe "VAULT_TOKEN=$TEST_TOKEN vault kv put secret/accounting/test acct_no="29347230942""
echo "Request failed as expected"

echo ""
echo "------------"
echo ""

p "Testing 'business-hrs' policy"

p "Enabling KV v2 secrets engine at kv-v2."
pe "vault secrets enable kv-v2"

echo ""

p "Sending test data to kv-v2"
pe "VAULT_TOKEN=$TEST_TOKEN vault kv put kv-v2/test id="29347230942""

echo ""

p "The 'business-hrs' policy will reject requests outside business hours."

caption "Setting Up Sentinel - Done"

# Cleanup
vault token revoke $TEST_TOKEN > /dev/null
vault secrets disable kv-v2 > /dev/null
vault policy delete cidr-check > /dev/null
vault policy delete business-hrs > /dev/null
vault policy delete tester > /dev/null
vault delete sys/policies/egp/business-hrs > /dev/null
vault delete sys/policies/egp/cidr-check > /dev/null
rm -f sentinel_0.16.1_linux_amd64.zip > /dev/null
sudo rm -f /usr/local/bin/sentinel > /dev/null

clear
