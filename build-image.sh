#!/bin/bash

DOCKER_REPO="devopshelp"
VERSION="1.0.0"

# Create the docker image
docker build --tag ${DOCKER_REPO}/moodle:latest .
docker tag ${DOCKER_REPO}/moodle:latest ${DOCKER_REPO}/moodle:${VERSION}

# If push was specified, push the image
if [ "$1" == "push" ]; then
    # Push the just created image to the Docker registry
    docker push ${DOCKER_REPO}/moodle:${VERSION}
    docker push ${DOCKER_REPO}/moodle:latest
fi
