#!/bin/bash
set -ex

# Author: Ellis Rhys Thomas
# Script: nordvpn-update.sh
# Date: 2019
# Depends: linux-utils, jq, wget, curl
#
## 
## USAGE: nordvpn-update [-t target] [-l location] [-p protocol] [-h]
##  
## Retrieves all NordVPN .ovpn configuration files and stores them in
## /etc/openvpn/client/nordvpn. Determines the fastest avalible vpn
## server and symlinks this configuration to /etc/openvpn/nordvpn.conf.
##  
## Requires an authorisation file (/etc/openvpn/nordvpn/auth.txt) to
## be present and containing only your NordVPN username and password
## on separate lines. Must be run with root permissions.
##  
## Options:
##
## [-t]    Target output openvpn configuration file.
##         Defaults to '/etc/openvpn/client/nordvpn.conf'.
## [-l]    NordVPN location identification number.
##         Defaults to '227' (United Kindgom).
##         Run nordvpn-country-codes.sh to print all options.
## [-p]    Protocol (tcp or udp).
##         Defaults to udp.
## [-h]    Print this help and exit.
## 
#
# Copyright (c) Ellis Rhys Thomas 2019
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

function die ()
{
    echo -e "ERROR: $1"
    sed -ne 's/^##\ //p' < $0; exit 1
}
    
# Script requires root to write to /etc/openvpn/client/
if (( $EUID )); then die "Requires root" ; fi

# Sane defaults
ROOT="/etc/openvpn/client/nordvpn"
URL='https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip'
TARGET="$ROOT/../nordvpn.conf"
COUNTRY="227"			# UK country code
PROTOCOL="udp"
LIMIT=1
AUTH=$ROOT/auth.txt

# Process arguements
while getopts "t:l:p:h" opt; do
    case $opt in
	t)
	    touch $TARGET || die "Can't touch target."
	    TARGET=$2;
	    shift 2
	    ;;
	l)
	    COUNTRIES_API="https://api.nordvpn.com/v1/servers/countries"
	    COUNTRIES="$(curl --silent "$COUNTRIES_API" | jq --raw-output '.[] | .id') "
	    [[ $COUNTRIES =~ $2[[:space:]] ]] || die "Invalid country id."
            shift 2
	    ;;

	# COUNTRIES=$(curl --silent "$COUNTRIES_API" \
	    # | jq --raw-output '.[] | [.id, .name] | @tsv')
	p)
	    [[ ! $PROTOCOL =~ ^udp$|^tcp$ ]] || die "Invalid protocol."
            PROTOCOL=$2;
            shift 2
	    ;;
	h | \?)
	    die "Incorrect usage."
            ;;
    esac
done

# Only update local copy of openvpn configuration files if the server
# archive is newer than local copy.
mkdir -p $ROOT
wget --tries=2 --timestamping --directory-prefix=$ROOT $URL
unzip -uoq $ROOT/ovpn.zip -d $ROOT
chown -R root:root $ROOT
chmod -R 400 $ROOT
echo "NordVPN archive update complete."

# Formulate API endpoint from parameters
API="https://api.nordvpn.com/v1/servers/recommendations"
API+="?filters\[country_id\]=$COUNTRY"
API+="&\[servers_technologies\]\[identifier\]=openvpn_$PROTOCOL"
API+="&limit=$LIMIT"

CONF="$ROOT/ovpn_$PROTOCOL/"
CONF+=$(curl --silent $API \
	     | jq --raw-output 'limit(1;.[]) | "\(.hostname)"')
CONF+=".udp.ovpn"

# Create config with option for plain text credentials
sed -e "s%^\(auth-user-pass\)$%\1 $AUTH%" \
    < $CONF > $TARGET

echo -e "NordVPN confifuration link updated.\nfrom:\t$CONF\nto:\t$TARGET"
