#!/bin/sh
pwd
ls
mkdir compiled-src
cd resource-web-app
ls
pwd
./gradlew assemble
ls build/libs/*
cd ..
cp -a resource-web-app/. compiled-src/
ls compiled-src/*

# publishing to git
git clone git@github.com:vponnam/repo.git

cd repo

git config --global user.email "me@concourse.ci"
git config --global user.name "concourse"

git add .
git commit -m "Publishing outputs"

git push

