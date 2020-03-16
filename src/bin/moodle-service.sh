#!/bin/bash
#
# This gist is licensed under the MIT License (MIT), see http://www.messners.com/mit-license.txt
# Copyright (c) 2014-2020 Greg Messner, greg@messners.com
#

#
# This is the service utility script for running Moodle in a docker container.  It is intended
# to be called from upstart or systemd service scripts, but can also be used from the command line
# to start, stop, and check the status of a running Moodle container.
#

#
# Print the help information for the Moodle service container.
#
function help {

    echo
    echo "  This script performs one or more actions on the Moodle service container."
    echo
    echo "  Usage : $(basename $0) action ..."
    echo
    echo "  Available actions"
    echo "  ------------------------------------------------------------------------"
    echo "  attach  Attaches the current process to the running Moodle service,"
    echo "          usually only used by actual OS services"
    echo "  cleanup Cleans up (removes) the Moodle service container"
    echo "  help    Prints this help information and exits"
    echo "  start   Starts the Moodle service container."
    echo "  status  Returns a one word status for the Moodle service"
    echo "  stop    Stops the Moodle service container"
    echo
    echo "  NOTE: Multiple actions may be combined on a single command line, for example:"
    echo "          $(basename $0) start attach"
    echo
}

#
# Launches the container and waits for it to be fully started.  After calling 'start', you can
# call the 'attach' method to attach to the log output of the container.
#
start() {

    # Must have MOODLE_SERVER_ADMIN and MOODLE_SERVER_NAME defined to start moodle
    local ERRORS=""
    if [ "$MOODLE_SERVER_ADMIN" == "" ]; then
        ERRORS="MOODLE_SERVER_ADMIN must be defined\n"
    fi

    if [ "$MOODLE_SERVER_NAME" == "" ]; then
        ERRORS="${ERRORS}MOODLE_SERVER_NAME must be defined\n"
    fi

    if [ "$ERRORS" != "" ]; then
        echo -e -n $ERRORS
        echo "Aborting!"
        exit 1
    fi

    # Make sure that docker does not have the service container present
    df_kill_container ${MOODLE_CONTAINER}

    # Make sure the moodle logs/apache2 directory exists, if not create it and
    # set the owner to www-data (www-data in docker container is 202:202)
    if [ ! -d "${MOODLE_DIR}/logs/apache2" ]; then
        mkdir -p "${MOODLE_DIR}/logs/apache2"
        chown 202:202 "${MOODLE_DIR}/logs"
    fi

    # If TZ is set pass it into the container
    if [ "$TZ" != "" ]; then
        TZ_ENV="--env TZ=${TZ}"
    else
        TZ_ENV=""
    fi

    # Set up the container link for the database if a DB container name was specified
    if [ "$MOODLE_DB_CONTAINER_NAME" != "" ]; then
        DB_LINK_ENV="--link $MOODLE_DB_CONTAINER_NAME"
    else
        DB_LINK_ENV=""
    fi

    # If the data volume does not exist, create it
    if ! docker volume inspect ${MOODLE_DATA_VOLUME} >/dev/null 2>&1 ; then
        echo "Creating ${MOODLE_DATA_VOLUME} data volume"
        docker volume create ${MOODLE_DATA_VOLUME} >/dev/null 2>&1
    fi

    # Run the docker container
    CONTAINER_ID=$(docker run --name "${MOODLE_CONTAINER}" \
        --detach --privileged \
        --restart=no \
        --publish ${MOODLE_PORT}:8080 \
        --env MOODLE_SERVER_ADMIN="$MOODLE_SERVER_ADMIN" \
        --env MOODLE_SERVER_NAME="$MOODLE_SERVER_NAME" \
        --volume ${MOODLE_DATA_VOLUME}:/var/www/html \
        --volume ${MOODLE_DIR}/logs/apache2:/var/log/apache2 \
        --health-cmd="/usr/bin/curl -sI http://127.0.0.1:8080/login || exit 1" \
        --health-interval=60s \
        ${TZ_ENV} ${DB_LINK_ENV} \
        ${MOODLE_IMAGE_NAME}:${MOODLE_IMAGE_VERSION})

    if [ $? -ne 0 ]; then
        echo "Error starting ${MOODLE_CONTAINER}"
        exit 1
    fi

    # Wait a maximum of 120 seconds for the container to be fully started and healthy
    echo "Started ${MOODLE_CONTAINER}, container ID=${CONTAINER_ID}"
    echo "Waiting for ${MOODLE_CONTAINER} to become healthy"
    df_wait_for_container 120 ${MOODLE_CONTAINER}
}


#############################################################################

# Need at least a single argumet (action), if none are provided putput usage info and exit with error.
if [ $# -lt 1 ]; then
    echo "Usage : $(basename $0) attach|cleanup|help|status|start|stop"
    exit 1
fi

if [ "$1" == "help" ]; then
    help
    exit 0
fi

# Load the docker utility functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/docker-functions.sh

# Default the MOODLE_DIR if not set, must do this before dotenv
MOODLE_DIR=${MOODLE_DIR:-"/var/moodle"}

# Load the configuration env file if present
if [[ -f  ${MOODLE_DIR}/moodle.env ]] && [[ -f $SCRIPT_DIR/dotenv.sh ]]; then
    source $SCRIPT_DIR/dotenv.sh
    dotenv ${MOODLE_DIR}/moodle.env >/dev/null
fi

# Default the env variables if they are not set.
MOODLE_IMAGE_NAME=${MOODLE_IMAGE_NAME:-"devopshelp/moodle"}
MOODLE_IMAGE_VERSION=${MOODLE_IMAGE_VERSION:-"latest"}
MOODLE_CONTAINER=${MOODLE_CONTAINER:-moodle}
MOODLE_DATA_VOLUME=${MOODLE_DATA_VOLUME:-${MOODLE_CONTAINER}-data}
MOODLE_PORT=${MOODLE_PORT:-8080}

#
# Loop thru the arguments (actions). Some actions may be paired together, for example:
#
#   start attach  -  Will start the container and attach the current process to it
#   stop cleanup  -  Will stop the container and then clean it up (remove it)
#
for ARG in "$@"
do
    case "$ARG" in

        "attach")
            df_attach_container $MOODLE_CONTAINER
            ;;

        "cleanup")
            df_cleanup_container $MOODLE_CONTAINER
            ;;

        "start")
            start
            ;;

        "status")
            df_container_status $MOODLE_CONTAINER
            ;;

        "stop")
            df_stop_container $MOODLE_CONTAINER
            ;;

        *)
            echo "'$1' is not a valid $(basename $0 '.sh') command, aborting!"
            exit 1
            ;;
    esac

    RESULTS=$?
    if [ $RESULTS -ne 0 ]; then
        exit $RESULTS
    fi
done

# vim: syntax=sh ts=4 sw=4 sts=4 sr noet
