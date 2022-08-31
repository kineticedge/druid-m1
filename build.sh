#!/bin/sh

VERSION=$(cat Dockerfile | grep "ARG DRUID_VERSION" | cut -d= -f2)

if [ -z $VERSION ]; then
  echo "Unable to extract version of Druid from Dockerfile, something has changed; aborting."
  exit
fi

echo "building version=${VERSION}"

docker build -t apache/druid:${VERSION}-arm64 -f ./Dockerfile .

