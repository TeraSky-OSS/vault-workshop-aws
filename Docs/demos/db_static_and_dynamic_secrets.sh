#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password -e "CREATE USER 'dude-demo'@'%' IDENTIFIED BY 'password'; GRANT ALL PRIVILEGES ON *.* TO 'dude-demo'@'%'"
p "Vault Database Secret Engine Demo."
TYPE_SPEED=80

p "enabling auditing to a log file"
pe "vault audit enable file file_path=/var/log/vault_audit.log"

p "Enabling Database Secret Engine in default path:"
pe "vault secrets enable database"

p "Configuring Vault to work with mysql Database:"
p 'vault write database/config/vault-lab-db 
  plugin_name=mysql-legacy-database-plugin 
  connection_url="{{username}}:{{password}}@tcp($(cat ../../db-srv.txt))/" 
  root_rotation_statements="SET PASSWORD = PASSWORD('{{password}}')" 
  allowed_roles="mysqlrole","dude" 
  username="root" 
  password="password"'

vault write database/config/vault-lab-db \
  plugin_name=mysql-legacy-database-plugin \
  connection_url="{{username}}:{{password}}@tcp($(cat ../../db-srv.txt))/" \
  root_rotation_statements="SET PASSWORD = PASSWORD('{{password}}')" \
  allowed_roles="mysqlrole","dude" \
  username="root" \
  password="password"

p "lets Rotate the initial db root credentials so only vault will have access to it:"
pe "vault write -force database/rotate-root/vault-lab-db"

p "and lets try to connect to our db with the origional root credentials to see what happens."
pe "mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password"


p "*** static database secrets ***"

p "Lets demonstrate managing a static role - which means managing an existing db user and automatically rotating its password with Vault."
p "we will configure a role that maps our database and db user named dude-demo, and sets the password rotation interval to 1 hour - or 3600 seconds:"
tee rotation.sql <<EOF
SET PASSWORD FOR "{{name}}" = PASSWORD('{{password}}');
EOF
p 'vault write database/static-roles/dude 
	db_name=vault-lab-db 
	rotation_statements=@rotation.sql 
  username="dude-demo" 
	rotation_period=3600'

vault write database/static-roles/dude \
	db_name=vault-lab-db \
	rotation_statements=@rotation.sql \
	username="dude-demo" \
	rotation_period=3600

p "lets veryfy our role's configuration"
pe "vault read database/static-roles/dude"

p "now lets read our role's password"
pe "vault read database/static-creds/dude"

p "we can also manually rotate the password at any time"
pe "vault write -f database/rotate-role/dude"

p "and lets read our role's password again to see the change"
pe "vault read database/static-creds/dude"
p "we can see that the password has changes and it's ttl period was resetted."
p "we can also set username and password templating, fine details can be seen in the documentation at: https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets#define-a-username-template"

pe "clear"

p "*** dynamic database secrets ***"
p "let's Configure a role that maps a name in Vault to an SQL statement to execute to create the database credential:"
p 'vault write database/roles/mysqlrole \
  db_name=vault-lab-db \
  creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';" \
  ttl="1h" \
  max_ttl="24h"'
vault write database/roles/mysqlrole db_name=vault-lab-db creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';" ttl="1h" max_ttl="24h"

p "we can create multiple roles pointing to the same DB, with different creation statements."

p "Get A new dynamic database secret:"
p "vault read database/creds/mysqlrole"
vault read database/creds/mysqlrole -format=json > db.creds
cat db.creds

p "Connect to db with new credentials. - After connected type exit to return to demo:"
pe "mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=$(cat db.creds | jq -r .data.username) --password=$(cat db.creds | jq -r .data.password)"

p "Revoke the dynamic DB credential:"
pe "vault lease revoke $(cat db.creds | jq -r .lease_id)"

p "Trying to Connect to db with dynamic credentials after revocation:"
pe "mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=$(cat db.creds | jq -r .data.username) --password=$(cat db.creds | jq -r .data.password)"

p "lets look at the vault log file"
pe "ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq"

p "full info and features of vault Database secret engine can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/secrets/databases"

p "Demo End."

vault secrets disable database
vault audit disable file
rm db.creds 
mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=admin --password=password --execute="SET PASSWORD FOR 'root' = PASSWORD('password');"
mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=admin --password=password --execute="DROP user 'dude-demo'"