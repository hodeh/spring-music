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

echo $PKS_PASSWORD | pks get-credentials $PKS_CLUSTER_NAME
kubectl config use-context $PKS_CLUSTER_NAME

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
kubectl config set-context $PKS_CLUSTER_NAME --namespace=$ENVIRONMENT

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

kubectl get deployment --namespace $ENVIRONMENT spring-music >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
echo "Creating new deployment"

cat << ---EOF > deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-music
  namespace: $ENVIRONMENT
  labels:
    app: spring-music
spec:
  replicas: 3
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
        image: $IMAGE_REPO:$VERSION
        imagePullPolicy: "Always"
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
             path: /
             port: 8080
             initialDelaySeconds: 5
             periodSeconds: 5
             successThreshold: 1
---EOF

set -e
kubectl apply -f deployment.yml
set +e
else
echo "updating existing deployment"

kubectl set image deployment/spring-music spring-music=$IMAGE_REPO:$VERSION --namespace $ENVIRONMENT
fi

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
