#!/bin/sh

set -e


export ROOT_FOLDER=$( pwd )
export GRADLE_USER_HOME="${ROOT_FOLDER}/.gradle"
ls
cd spring-music
./gradlew build
cd -
cp version/version docker-build/version
mv spring-music/build/libs/spring-music-1.0.jar docker-build

cat << ---EOF > docker-build/Dockerfile
FROM openjdk:8-jdk-alpine
VOLUME /tmp
COPY spring-music-1.0.jar app.jar
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]
---EOF