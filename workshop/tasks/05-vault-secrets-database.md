# Vault Workshop - Vault Database Secret Engine

In this section, we will configure the **Database Secret Engine** in Vault to dynamically generate database credentials and rotate them. We will set up and configure two databases—**PostgreSQL** and **MongoDB**—on Minikube and integrate them with Vault.

---

## **PostgreSQL on Minikube**

### Deploy PostgreSQL on Minikube**

1. **Deploy PostgreSQL using Helm**:
   Add the Bitnami Helm chart repository and install PostgreSQL.
   ```bash
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo update
   helm upgrade --install postgres bitnami/postgresql --namespace postgres --set global.postgresql.auth.postgresPassword=password123,global.postgresql.auth.database=mydb --create-namespace
   ```

2. **Verify the PostgreSQL deployment**:
   Check the status of the PostgreSQL pods.
   ```bash
   kubectl get pods -n postgres
   ```

3. **Forward the PostgreSQL service to your local machine**:

   ```bash
   export POSTGRES_PASSWORD=$(kubectl get secret --namespace postgres postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

   kubectl run postgres-postgresql-client --rm --tty -i --restart='Never' --namespace postgres \
   --image docker.io/bitnami/postgresql:17.2.0-debian-12-r5 --env="PGPASSWORD=$POSTGRES_PASSWORD" \
      --command -- psql --host postgres-postgresql -U postgres -d mydb -p 5432
   
   ```

---

### Configure Vault for PostgreSQL**

1. **Enable the Database Secret Engine**:
   ```bash
   vault secrets enable -path postgres database 
   ```

2. **Configure the PostgreSQL database plugin**:
   ```bash
   vault write postgres/config/postgres \
     plugin_name=postgresql-database-plugin \
     connection_url="postgresql://{{username}}:{{password}}@postgres-postgresql.postgres.svc.cluster.local:5432/mydb" \
     allowed_roles="my-role" \
     username="postgres" \
     password=$POSTGRES_PASSWORD
   ```

3. **Rotate root user password**
   After preforming the rotation you will no longer be able to login with the admin user.
   ```bash
   vault write -force postgres/rotate-root/postgres
   ```

   Now try to access with the old password

   ```bash
   kubectl run postgres-postgresql-client --rm --tty -i --restart='Never' --namespace postgres \
   --image docker.io/bitnami/postgresql:17.2.0-debian-12-r5 --env="PGPASSWORD=$POSTGRES_PASSWORD" \
      --command -- psql --host postgres-postgresql -U postgres -d mydb -p 5432
   ```

   This should fail since we rotated the password.

   > **Note**: When this is done, the password for the user specified in the previous step is no longer accessible. Because of this, it is highly recommended that a user is created specifically for Vault to use to manage database users.

4. **Create a role for dynamic credential generation**:
   ```bash
   vault write postgres/roles/my-role \
     db_name=postgres \
     creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
     default_ttl="1h" \
     max_ttl="24h"
   ```

5. **Generate dynamic credentials and access the db with the dynamic credentials**

   Generate dynamic credentials
   ```bash
   vault read postgres/creds/my-role
   ```

   Now login with the new dynamic credentials
   ```bash
   kubectl run postgres-postgresql-client --rm --tty -i --restart='Never' --namespace postgres \
   --image docker.io/bitnami/postgresql:17.2.0-debian-12-r5 --env="PGPASSWORD=<new_password>" \
      --command -- psql --host postgres-postgresql -U <new_user> -d mydb -p 5432
   ```

   You can run this query to list data with the newly created user provisiend by vault.
   ```sql
   SELECT table_name
   FROM information_schema.tables
   WHERE table_schema = 'pg_catalog';
   ```

   The following command will attempt to create a table 
   ```sql
   CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY);
   ```

   This will fail since the role only allows select from tables.

---

## **MongoDB on Minikube**

### Deploy MongoDB on Minikube**

1. **Deploy MongoDB using Helm**:
   Add the Bitnami Helm chart repository and install MongoDB.
   ```bash
   helm upgrade --install mongodb bitnami/mongodb --namespace mongodb --create-namespace
   ```

2. **Verify the MongoDB deployment**:
   Check the status of the MongoDB pods.
   ```bash
   kubectl get pods -n mongodb
   ```

3. **Setup MongoDB Client and login to MongoDB host**:
   ```bash
   export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace mongodb mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 --decode)
   kubectl run --namespace mongodb mongodb-client --rm --tty -i --restart='Never' --image=mongo:latest --command -- mongosh --host mongodb --port 27017 -u root -p $MONGODB_ROOT_PASSWORD
   ```

---

### **Configure Vault for MongoDB**

1. **Enable the Database Secret Engine**:
   ```bash
   vault secrets enable -path mongodb database
   ```

2. **Configure the MongoDB database plugin**:
   ```bash
   vault write mongodb/config/mongodb \
     plugin_name=mongodb-database-plugin \
     connection_url="mongodb://{{username}}:{{password}}@mongodb.mongodb.svc.cluster.local:27017/admin" \
     allowed_roles="my-role" \
     username="root" \
     password=$MONGODB_ROOT_PASSWORD
   ```

3. **Rotate root user password**
   After preforming the rotation you will no longer be able to login with the root user.

   ```bash
   vault write -force mongodb/rotate-root/mongodb
   ```

   > **Note**: When this is done, the password for the user specified in the previous step is no longer accessible. Because of this, it is highly recommended that a user is created specifically for Vault to use to manage database users.

   Now try again accessing MongoDB with the old password
   ```bash
   kubectl run --namespace mongodb mongodb-client --rm --tty -i --restart='Never' --image=mongo:latest --command -- mongosh --host mongodb --port 27017 -u root -p $MONGODB_ROOT_PASSWORD
   ```

   As you can see this fails since we rotated the password.

4. **Create a role for dynamic credential generation**:
   ```bash
   vault write mongodb/roles/my-role \
      db_name=mongodb \
      creation_statements='{ "db": "admin", "roles": [{ "role": "read", "db": "admin" }] }' \
      default_ttl="1h" \
      max_ttl="24h"
   ```

5. **Generate dynamic credentials**:
   ```bash
   vault read mongodb/creds/my-role
   ```

6. **Access the db with the dynamic credentials**

   After generating the dynamic credentials try accessing MongoDB again

   ```bash
   kubectl run --namespace mongodb mongodb-client --rm --tty -i --restart='Never' --image=mongo:latest --command -- mongosh --host mongodb --port 27017 -u <new_user> -p <new_password>
   ```   

   Try running this query
   ```js
   show dbs
   use admin
   show collections
   ```

   Now try running this query
   ```js
   use admin
   db.createCollection("testCollection")
   ```

   This should fail since we only gave the role `read` permissions.

---

## **Conclusion**

In this section, we deployed PostgreSQL and MongoDB on Minikube and configured the Vault Database Secret Engine to dynamically generate credentials for both databases. These credentials can now be used by applications to securely access the databases.

Next: [Vault Manual Snapshot](./06-vault-manual-backup.md)
