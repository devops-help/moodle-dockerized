#!/bin/bash

####################################################################
# This is the Docker entry point for Apache2 to run Moodle.        #
####################################################################

set -e

help() {
    echo
    echo "  This Docker image provides Ubuntu 18.04 set up with Apache2 to run Moodle."
    echo
    echo "  Available Commands:"
    echo
    echo "  Tool       Description"
    echo "  ---------  ------------------------------------------------------------"
    echo "  moodle     Starts apache2 (httpd) with moodle as the root"
    echo "  help       Prints this help message and exits (default)"
    echo
    echo "  NOTE:"
    echo "  If you provide a command other than moodle or help the moodle container"
    echo "  will be started and the provided args will be executed."
}

function moodle {

    # Make sure the apache2.pid file is not present
    rm -f /var/run/apache2/apache2.pid

    # Update the ServerAdmin if provided
    if [ "$MOODLE_SERVER_ADMIN" != "" ]; then
        sed "s/ServerAdmin.*$/ServerAdmin $MOODLE_SERVER_ADMIN/" /etc/apache2/sites-available/moodle.conf > /tmp/moodle.conf
        cp /tmp/moodle.conf /etc/apache2/sites-available/moodle.conf
    fi

    # Update the ServerName if provided
    if [ "$MOODLE_SERVER_NAME" != "" ]; then
        sed "s/ServerName.*$/ServerName $MOODLE_SERVER_NAME/" /etc/apache2/sites-available/moodle.conf > /tmp/moodle.conf
        cp /tmp/moodle.conf /etc/apache2/sites-available/moodle.conf
    fi

    # Start apache2 in the foreground
    exec /usr/sbin/apachectl -DFOREGROUND
}

# Run the specified command.
case "$1" in

    "help")
        help
        exit 0
        ;;

    "moodle"|"")
        moodle
        ;;

    *)
        # Execute the specified command and arguments
        exec $*
        ;;
esac

# vim: syntax=sh ts=4 sw=4 sts=4 sr noet

