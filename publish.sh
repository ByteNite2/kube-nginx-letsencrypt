#!/bin/bash

export IMAGE_NAME="kube-nginx-letsencrypt"
FULL_IMAGE_NAME="europe-west3-docker.pkg.dev/transcoding-testing/bytenite-dev/$IMAGE_NAME"
docker build . -t $IMAGE_NAME
docker tag $IMAGE_NAME $FULL_IMAGE_NAME
docker push $FULL_IMAGE_NAME

echo "Imaged pushed to $FULL_IMAGE_NAME"