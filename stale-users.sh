#!/bin/bash
# Script written by Derek DeMoss for Dark Horse Comics, Inc. 2015
# This is designed to create a list of users who will be disabled on next login attempt due to 
# lack of logins in the last 180 days, per our global PasswordPolicy 
# Most of the logic is stolen from my disabled users script:
# https://github.com/derekcat/disabled-users.sh

if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "" ]; then
	echo "stale-users.sh"
	echo "Generates a list of stale OD users and either emails or prints to STDOUT"
	echo "Usage: stale-users.sh -e [email-to address]"
	echo "Usage: stale-users.sh -p"
	echo "Options"
	echo "-h, --help			Display this help message"
	echo "-e [email-to address], --email	Email the results to [email-to address]"
	echo "-p, --print			Print to STDOUT instead of emailing the list"
	echo "-u [username], --user		Same as -p, but only for the specified user"
	exit
fi

# Make a list of OpenDirectory Users
ODUSERS="$(dscl /LDAPv3/127.0.0.1 -list /Users | grep -v vpn | grep -v ldap | grep -v _krb_)"

if [ $1 = "-u" ] || [ $1 = "-user" ]; then
	ODUSERS=$2
fi

# Get the current Unix Epoch time
UNIXTIME="$(date +%s)"

# Cleanly initialize our list of stale users
STALEUSERS=""

if [ $1 = "-p" ] || [ $1 = "--print" ] || [ $1 = "-u" ] || [ $1 = "--user" ]; then # If we're printing to STDOUT
	echo "Now checking for stale users, please wait..."

	for USER in $ODUSERS # Step through our list of users
	do
		
		# When was their last login time?
		LASTLOGINTIME="$(pwpolicy -u $USER --get-effective-policy | awk '{print $6}' | cut -d = -f 2)"

		echo "Unixtime is $UNIXTIME" 
		echo "Last login time is $LASTLOGINTIME" 
		
		# Age of the login in seconds
		AGE=$((UNIXTIME - LASTLOGINTIME))
		echo "$USER's last login was about $((AGE / 86400)) days ago." 
	
		# If they're over 180 days, add them to the list
		if (( $AGE >= 15552000 )); then 
			STALEUSERS+="$USER "
		fi
	done
	
	if [[ -n "$STALEUSERS" ]]; then # If $STALEUSERS is not empty, print them
		echo "Stale user[s]:$STALEUSERS"
		exit
	else
		echo "No one is stale, yay!"
		exit
	fi
fi


if [ $1 = "-e" ] || [ $1 = "--email" ]; then # If we're emailing the list
	EMAILADDRESS=$2 # Let's give that a nice name

	for USER in $ODUSERS # Step through our list of users
	do
		# When was their last login time?
		LASTLOGINTIME="$(pwpolicy -u $USER --get-effective-policy | awk '{print $6}' | cut -d = -f 2)"

		# Age of the login in seconds
		AGE=$((UNIXTIME - LASTLOGINTIME))

		# If they're over 180 days, add them to the list
		if (( $AGE >= 15552000 )); then 
			STALEUSERS+="$USER "
		fi
	done
	
	if [[ -n "$STALEUSERS" ]]; then # If $STALEUSERS is not empty, email the list
		echo "Stale user[s]:$STALEUSERS" | mail -s "Subject: server has stale users" "$EMAILADDRESS"
		exit
	else
		echo "No one is stale, yay!  Let's not bother sending an email."
		exit
	fi
fi
