kubectl create deployment mysql \
  --image=mysql:8.0 \
  --port=3306 \
  -- env MYSQL_ROOT_PASSWORD=rootpass

kubectl expose deployment mysql --port=3306

# Connect
kubectl exec -it $(kubectl get pod -l app=mysql -o name) -- mysql -uroot -prootpass


SHOW DATABASES;
CREATE DATABASE test;
USE test;
CREATE TABLE hello (id INT, msg VARCHAR(50));
INSERT INTO hello VALUES (1, 'hello from minikube');
SELECT * FROM hello;