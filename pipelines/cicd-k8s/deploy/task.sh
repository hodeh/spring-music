#!/bin/bash

set -xu

curl -L https://s3.amazonaws.com/mevansam-software/pivotal/kubectl -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

curl -L https://s3.amazonaws.com/mevansam-software/pivotal/pks -o /usr/local/bin/pks
chmod +x /usr/local/bin/pks

pks login --skip-ssl-validation \
  --api $PKS_API_ENDPOINT \
  --username $PKS_USERNAME \
  --password $PKS_PASSWORD

pks get-credentials pks-demo-run
kubectl config use-context pks-demo-run

kubectl get namespace "$ENVIRONMENT" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  cat << ---EOF > namespace.yml
apiVersion: v1
kind: Namespace
metadata:
  name: $ENVIRONMENT
---EOF

  set -e
  kubectl create -f namespace.yml
  set +e
fi
kubectl config set-context pks-demo-run --namespace=$ENVIRONMENT

kubectl get secret harbor-cred >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  
  set -e
  kubectl create secret docker-registry harbor-cred \
    --docker-server=$DOCKER_REGISTRY_SERVER \
    --docker-username=$DOCKER_REGISTRY_USERNAME \
    --docker-password=$DOCKER_REGISTRY_PASSWORD
  set +e
fi

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

set -e
kubectl apply -f deployment.yml
set +e

kubectl get service --namespace $ENVIRONMENT spring-music >/dev/null 2>&1
if [[ $? -ne 0 ]]; then

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

  kubectl expose deployment spring-music --namespace $ENVIRONMENT --type=LoadBalancer --name=spring-music 
fi

SERVICE_ENDPOINT=$(kubectl get service --namespace $ENVIRONMENT spring-music -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo -e "\n\n**** Spring Music in environment '$ENVIRONMENT' available at: http://${SERVICE_ENDPOINT}:8080"
