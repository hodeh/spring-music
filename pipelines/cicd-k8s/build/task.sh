#!/bin/sh

set -xeu


export ROOT_FOLDER=$( pwd )
export GRADLE_USER_HOME="${ROOT_FOLDER}/.gradle"

cd spring-music
./gradlew build

