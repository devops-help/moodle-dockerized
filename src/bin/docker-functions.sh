#!/bin/bash
#
# This gist is licensed under the MIT License (MIT), see http://www.messners.com/mit-license.txt
# Copyright (c) 2014-2020 Greg Messner, greg@messners.com
#

#
# This file contains a set of bash functions to simplify working wth docker.
# To use with a bash shell or script, simply source the file as follows:
#
#	source [path-to-this-file]
#
#
# The following functions are available, function details are available in
# in the header of each function:
#
#	df_attach_container
#	df_clean_containers
#	df_clean_images
#	df_cleanup_container
#	df_container_status
#	df_kill_container
#	df_stop_container
#	df_wait_for_container
#


#
# Attaches to the log output of the container. This function is usually only used by services
# and not by command line tools.
#
# Usage: df_attach_container container_name
#
function df_attach_container() {

	# Verify the parameters
	if [ $# -ne 1 ]; then
		echo "Usage: ${FUNCNAME[0]} container_name" 1>&2
		return 1
	fi

	# Make sure the container is running
	local CONTAINER=$1
	docker ps --all --filter "status=running" --filter "name=${CONTAINER}" --format "{{.Status}}" > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		return 1
	fi

	# We use a tailing docker logs as the actual service process
	docker logs -f ${CONTAINER}
}


#
# Removes all containers that are in an exited state.
#
# Usage: df_clean_containers
#
function df_clean_containers() {
	local exitedContainers=$(docker ps -qa --filter "status=exited")
	if [ ! -z "$exitedContainers" ]; then
		docker rm $exitedContainers
	fi
}


#
# Removes all docker images that are dangling (don't have a name).
#
# Usage: df_clean_images
#
function df_clean_images() {
	local untaggedImages=$(docker images --filter "dangling=true" -q)
	if [ ! -z "$untaggedImages" ]; then
		docker rmi $untaggedImages
	fi
}


#
#
# Checks that the provided container name is in an exited state, and if so, removes the container.
#
# Usage: df_cleanup_container container_name
#
function df_cleanup_container() {

	# Verify the parameters
	if [ $# -ne 1 ]; then
		echo "Usage: ${FUNCNAME[0]} container_name" 1>&2
		return 1
	fi

	local CONTAINER=$1
	local STATUS="$(docker ps --all --filter "status=exited" --filter "name=${CONTAINER}" --format "{{.Status}}")"
	if [ "$STATUS" != "" ]; then
		docker rm ${CONTAINER} >/dev/null 2>&1
		echo "Removed ${CONTAINER} container"
	fi
}


#
# Gets the status of the specified container.  One of four(4) results will occur:
#
# 1) If the container is NOT found:
#	 - returns with fail code (1) and the message "not found"
#
# 2) The container is found and has a healthcheck defined:
#	 - simply outputs a health status (starting,healthy,...) and returns
#
# 3) The container is running and does NOT have a healthcheck defined:
#	 - simply outputs "running" and returns
#
# 4) The container is NOT running and does NOT have a healthcheck defined:
#	 - simply outputs "not running" and returns
#
# Usage:  df_container_status container-name
#
function df_container_status() {

	# Verify the passed parameters
	if [ $# -ne 1 ]; then
		echo "Usage: ${FUNCNAME[0]} container_name" 1>&2
		return 1
	fi

	local CONTAINER=$1
	docker inspect ${CONTAINER} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "not found"
		return 1
	fi

	# Get the health status from the container, if no healthcheck configured, simple echo "running" or "not running"
	local HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' ${CONTAINER} 2>/dev/null)
	if [ ! -z ${HEALTH_STATUS} ]; then
		echo "${HEALTH_STATUS}"
	else
		# Determine whether the container is running or not
		docker ps --all --filter "status=running" --filter "name=${CONTAINER}" --format "{{.Status}}" > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "running"
		else
			echo "not running"
		fi
	fi
}


#
# Performs a controlled docker stop and rm for a running docker container.
# It is meant to be called by system service scripts to cleanly shutdown a
# service running in a docker container.
#
# Usage: df_kill_container container_name
#
function df_kill_container() {

	# Verify the parameters
	if [ $# -ne 1 ]; then
		echo "Usage: ${FUNCNAME[0]} container_name" 1>&2
		return 1
	fi

	local CONTAINER=$1
	docker inspect $CONTAINER > /dev/null 2>&1
	if [ $? == 0 ]; then
		docker stop $CONTAINER > /dev/null 2>&1
		docker rm $CONTAINER > /dev/null 2>&1
		echo "Stopped and removed $CONTAINER"
	fi
}


#
# Sends a docker stop to a running container, if the container is not running, does nothing. Used by services and
# command lines alike to stop container.  It is common to follow this up with a 'cleanup_container', which will
# remove the stopped container
#
# Usage: df_stop_container container_name
#
function df_stop_container() {

	# Verify the parameters
	if [ $# -ne 1 ]; then
	echo "Usage: ${FUNCNAME[0]} container_name" 1>&2
		return 1
	fi

	local CONTAINER=$1
	local STATUS="$(docker ps --all --filter "status=running" --filter "name=${CONTAINER}" --format "{{.Status}}")"
	if [ "$STATUS" != "" ]; then
		docker stop --time 20 ${CONTAINER} >/dev/null 2>&1
		echo "Stopped ${CONTAINER} container"
	fi
}


#
# Will wait the specified number of seconds for a docker container to start.
# If the timeout elapses before the container is live, the function will
# return with 1 as the status, simply outputs a message and returns on success.
#
# If the container has a health check configured, then this script will wait
# time for the container to become "healthy"
#
# Usage: df_wait_for_container timeout_seconds container_name
#
function df_wait_for_container() {

	# Verify the parameters
	if [ $# -ne 2 ]; then
		echo "Usage: ${FUNCNAME[0]} timeout_seconds container_name" 1>&2
		return 1
	fi

	local MAX_LOOPS=$1
	local CONTAINER=$2

	# Determine the sleep command for the OS
	if [ -f /usr/bin/sleep ]; then
		SLEEP=/usr/bin/sleep
	else
		SLEEP=/bin/sleep
	fi

	# If the container has a healthcheck use it to determine that it is ready
	if docker inspect --format='{{.State.Health.Status}}' ${CONTAINER} >/dev/null 2>&1 ; then
		DO_HEALTHCHECK="true"
	fi

	local LOOPS=0
	while [ $LOOPS -lt $MAX_LOOPS ] ;do
		if [ "$DO_HEALTHCHECK" == "true" ]; then

			HEALTH_STATUS=$( docker inspect --format "{{.State.Health.Status}}" ${CONTAINER} 2>/dev/null )
			if [ $HEALTH_STATUS == "healthy" ]; then
				echo "${CONTAINER} is '${HEALTH_STATUS}' after $LOOPS seconds."
				break
			fi

			# Print the status every 5 seconds
			if [ $(($LOOPS % 5)) -eq 0 ]; then
				echo "${CONTAINER} is ${HEALTH_STATUS}"
			fi

		else
			docker inspect $CONTAINER >/dev/null 2>&1
			if [ $? == 0 ]; then
				break
			fi
		fi

		$SLEEP 1
		let LOOPS=LOOPS+1
	done

	# If we haven't reached the timeout. then the container started
	if [ $LOOPS -lt $MAX_LOOPS ]; then
		if [ "$DO_HEALTHCHECK" != "true" ]; then
			echo "'$CONTAINER' has started"
		fi
	else
		echo "'$CONTAINER' failed to start in $MAX_LOOPS seconds"
		return 1
	fi
}

# vim: syntax=sh ts=4 sw=4 sts=4 sr noet

