#!/bin/bash
set -e

# Author: Ellis Rhys Thomas
# Script: nordvpn-update.sh
# Date: 2019
#
# Description: Retrieves all NordVPN .ovpn configuration files. see
# --help for details.
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

# Argument pre-processing requires getopt from linux-utils for long
# form (--arg) arguments to process correctly.
# ARG_ERR=$(strcat "nordvpn-update"\
#		 "[-h] [-u url]"\
#		 "[-a custom.conf]\n\n"\
#		 "Retrieves the NordVPN .ovpn configuration files.\n\n"\
#		 "Options:\n\n"\
#		 "h, --help\tdisplay this help and exit\n"\
#		 "u, --url\tovpn configuration file archive url\n"\
#		 "\t\tdefaults to "\
#		 "https://downloads.nordcdn.com/configs/archives/servers/"\
#		 "ovpn.zip\n")

# ARGV=`getopt -o hu: --long help,url: -n 'nordvpn-update' -- "$@"`
# if [ $? != 0 ] ; then echo "Invalid Arguments.\n\n$ARG_ERR"  >&2 ; exit 1 ; fi
# eval set -- "$ARGV"

if (( $EUID )); then echo "ERROR: $0 must be run as root"; exit 1 ; fi

# Set some sane defaults and process arguments
ROOT="/etc/openvpn/client/nordvpn"
URL='https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip'
TARGET="$ROOT/../nordvpn.conf"

# while true; do
#   case "$1" in
#       -h | --help      ) echo -e $ARG_ERR; exit 1;;
#       -u | --url       ) URL="$2";         shift 2;;
#       --               )                   break;;
#       *                ) echo -e $ARG_ERR; exit 1;;
#   esac
# done

# Only update local files if the server archive is newer than local
# copy
mkdir -p $ROOT
wget --tries=2 --timestamping --directory-prefix=$ROOT $URL
unzip -uoq $ROOT/ovpn.zip -d $ROOT
chown -R root:root $ROOT
chmod -R 400 $ROOT
echo "NordVPN archive update complete."

# Get the fastest servers
COUNTRY="227"
PROTOCOL="udp"
LIMIT=1
AUTH=$ROOT/auth.txt

API="https://api.nordvpn.com/v1/servers/recommendations"
API+="?filters\[country_id\]=$COUNTRY"
API+="&\[servers_technologies\]\[identifier\]=openvpn_$PROTOCOL"
API+="&limit=$LIMIT"

CONF="$ROOT/ovpn_$PROTOCOL/"
CONF+=$(curl --silent $API \
	     | jq --raw-output 'limit(1;.[]) | "\(.hostname)"')
CONF+=".udp.ovpn"

sed -e "s%^\(auth-user-pass\)$%\1 $AUTH%" \
    < $CONF > $TARGET

echo -e "NordVPN confifuration link updated.\nfrom:\t$CONF\nto:\t$TARGET"
