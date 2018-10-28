#!/bin/sh

set -euo pipefail

version=1.0

cd spring-music-repo
./gradlew clean assemble
cd -

mv spring-music-repo/build/libs/spring-music-${version}.jar docker-build

cat << ---EOF > docker-build/Dockerfile
FROM openjdk:8-jdk-alpine
VOLUME /tmp
COPY spring-music-${version}.jar app.jar
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]
---EOF
