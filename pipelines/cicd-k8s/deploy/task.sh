#!/bin/bash

set -xu

curl -L https://s3.amazonaws.com/mevansam-software/pivotal/kubectl -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

curl -L https://s3.amazonaws.com/mevansam-software/pivotal/pks -o /usr/local/bin/pks
chmod +x /usr/local/bin/pks

pks login --skip-ssl-validation --api pks.pcf.pcfenv1.pocs.pcfs.io --username pks-admin --password Passw0rd
pks get-credentials pks-demo-run
kubectl config use-context pks-demo-run

kubectl get namespaces | grep "$ENVIRONMENT" >/dev/null 2&>1
if [[ $? -ne 0 ]]; then
  cat << ---EOF > namespace.yml
apiVersion: v1
kind: Namespace
metadata:
  name: $ENVIRONMENT
---EOF
  kubectl create -f namespace.yml
fi
kubectl config set-context pks-demo-run --namespace=$ENVIRONMENT

kubectl get secret harbor-cred >/dev/null 2&>1
if [[ $? -ne 0 ]]; then
    
  kubectl create secret docker-registry harbor-cred \
    --docker-server=$DOCKER_REGISTRY_SERVER \
    --docker-username=$DOCKER_REGISTRY_USERNAME \
    --docker-password=$DOCKER_REGISTRY_PASSWORD
fi

set -e

export VERSION=$(cat version/version)
echo "Deploying to spring-music verion $VERSION to $ENVIRONMENT."

cat << ---EOF > deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-music
  namespace: $ENVIRONMENT
  labels:
    app: spring-music
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spring-music
  template:
    metadata:
      labels:
        app: spring-music
    spec:
      imagePullSecrets:
      - name: harbor-cred
      containers:
      - name: spring-music
        image: harbor.pcf.pcfenv1.pocs.pcfs.io/demo/spring-music:$VERSION
        ports:
        - containerPort: 8080
---EOF

kubectl apply -f deployment.yml

cat << ---EOF > service.yml
kind: Service
metadata:
  name: spring-music
  namespace: $ENVIRONMENT
  labels:
    app: spring-music
spec:
  type: LoadBalancer
  ports:
  - name: http
    port: 8080
    targetPort: http
    protocol: TCP
  selector:
    app: spring-music
---EOF

set +e

kubectl get service --namespace sandbox spring-music >/dev/null 2&>1
if [[ $? -ne 0 ]]; then
  kubectl expose deployment spring-music --type=LoadBalancer --name=spring-music
fi

SERVICE_ENDPOINT=$(kubectl get service --namespace sandbox spring-music -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo -e "\n\n**** Spring Music in environment '$ENVIRONMENT' available at: http://${SERVICE_ENDPOINT}:8080"
