#!/bin/bash

export IMAGE_NAME="kube-nginx-letsencrypt"
export IMAGE_TAG="v2.0"
FULL_IMAGE_NAME="us-docker.pkg.dev/bytenite-stage/bytenite-dev/$IMAGE_NAME:$IMAGE_TAG"
docker build . -t $IMAGE_NAME
docker tag $IMAGE_NAME $FULL_IMAGE_NAME
docker push $FULL_IMAGE_NAME

echo "Image pushed to $FULL_IMAGE_NAME"