#!/bin/sh

set -xeu

export VERSION=$(cat version/version)
cp version/version docker-build/version

cd spring-music
./gradlew clean assemble
cd -

ls -al spring-music/build/libs

mv spring-music/build/libs/spring-music-1.0.jar docker-build

cat << ---EOF > docker-build/Dockerfile
FROM openjdk:8-jdk-alpine
VOLUME /tmp
COPY spring-music-1.0.jar app.jar
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]
---EOF
