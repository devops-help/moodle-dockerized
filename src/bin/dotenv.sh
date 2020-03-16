#!/bin/bash
#
# This gist is licensed under the MIT License (MIT), see http://www.messners.com/mit-license.txt
# Copyright (c) 2014-2020 Greg Messner, greg@messners.com
#

#
# bash dotenv configuration file processing based on the "12-factor app". See https://12factor.net/config for more info.
#
# This function exports variables from a dotenv file to the environment. It can handle dotenv files with
# the export keyword, verifies the name/value pair, and only exports variables if the variable is not
# already set in the environment.
#
# Usage: dotenv [dotenv_filename]
#
# NOTE: If dotenv_filename is not provided, will default to ".env" in the current working directory.
#
function dotenv() {

	# Verify the parameters
	if [ $# -gt 1 ]; then
		echo "Usage: ${FUNCNAME[0]} env_filename" 1>&2
		return 1
	elif [ $# -eq 1 ]; then
		# Make sure the specified dotenv file exists
		ENV_FILE="$1"
		if [ ! -f "$ENV_FILE" ]; then
			echo "${FUNCNAME[0]}: '$ENV_FILE' dotenv file not found!" 1>&2
			return 1
		fi
	else
		# Make sure a .env file exists in the current directory
		ENV_FILE=".env"
		if [ ! -f ${ENV_FILE} ]; then
			echo "${FUNCNAME[0]}: no .env file in current directory!" 1>&2
			return 1
		fi
	fi

	# Use VALIDATOR to ensure the variable starts off with a valid character
	local VALIDATOR="[a-zA-Z_]"

	while read LINE
	do
		if [ -n "$(echo $LINE | egrep "^${VALIDATOR}[a-zA-Z_0-9]+=.*$")" ]; then
			# This is a valid line containing a name/value pair
			NAME_VALUE_PAIR="$LINE"
		elif [ -n "$(echo $LINE | egrep "^export ${VALIDATOR}[a-zA-Z_0-9]+=.*$")" ]; then
			# The line starts with the word "export" and is a valid name/value pair, trim off "export"
			NAME_VALUE_PAIR="${LINE:7}"
		else
			# The current line is not a valid env variable, skip it
			continue
		fi

		# Only export the variable if it is not currently set in the environment
		NAME=$(echo "$NAME_VALUE_PAIR" | cut -d= -f1)
		if [ -z "${!NAME}" ]; then
			VALUE=$(echo "$NAME_VALUE_PAIR" | cut -d= -f2)
			# Trim any leading and trailing quotes (")
			VALUE="${VALUE%\"}"
			VALUE="${VALUE#\"}"
			export ${NAME}="${VALUE}"
		fi
	done < $ENV_FILE
}

# vim: syntax=sh ts=4 sw=4 sts=4 sr noet

