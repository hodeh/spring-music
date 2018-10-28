#!/bin/sh

set -xeuo pipefail

export VERSION=$(cat version/version)
echo "Deploying to spring-music verion $VERSION to $ENVIRONMENT."

cat << ---EOF > deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-music-$ENVIRONMENT
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
      containers:
      - name: spring-music
        image: harbor.pcf.pcfenv1.pocs.pcfs.io/demo/spring-music:$VERSION
        ports:
        - containerPort: 8080
---EOF

