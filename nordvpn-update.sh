#!/bin/bash
set -e

# NORDVPN-UPDATE.SH
#
# Retrieve the NordVPN .ovpn configuration files and installs them into /etc/ovpn/
#
# 

# Argument pre-processing requires getopt from linux-utils for long
# form (--arg) arguments to process correctly.
ARG_ERR='\nnordvpn-update [-h] [-c country] [-u url] [-d directory]\n\nOptions:\n\n h, --help\tdisplay this help and exit\n c, --country\tset server country (uk, us, fr, etc.)\n\t\tdefaults to uk\n u, --url\tserver ovpn url\n\t\tdefaults to https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip\n d, --directory\tset installation directory\n\t\tdefaults to :/etc/openvpn\n'
       
ARGV=`getopt -o hu:c:d: \
	     --long help,url:,country,directory: \
             -n 'nordvpn-update' -- "$@"`
if [ $? != 0 ] ; then echo $ARG_ERR  >&2 ; exit 1 ; fi
eval set -- "$ARGV"

# Set some sane defaults and process arguments
COUNTRY='uk'
URL='https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip'
DIR='/etc/ovpn'

while true; do
  case "$1" in
      -h | --help      ) echo -e $ARG_ERR; exit 1;;
      -c | --country   ) COUNTRY=true;     shift 2;;
      -u | --url       ) URL="$2";         shift 2;;
      -d | --directory ) DIRECTORY="$2";   shift 2;;
      --               )                   break;;
      *                ) echo -e $ARG_ERR; exit 1;;
  esac
done

# Update and unzip NordVPN server configuration files. Only process if
# the archive is newer than local configuration files.
ROOT=$HOME/.nordvpn
mkdir -p $ROOT
wget --tries=2 --timestamping --directory-prefix=$ROOT $URL
unzip -uoq $ROOT/ovpn.zip -d $ROOT

# Set each of the specified country's servers as shell arguments for
# easy processing.
UDP_DIR=$ROOT/ovpn_udp
set -- $(find $UDP_DIR -regextype sed \
	      -regex ".*$COUNTRY[0-9]\{1,4\}\.nordvpn.com.udp.ovpn")

# Extract and store the common information (configurations,
# certificates and keys) from the first country's server.
CONF=$ROOT/nord.conf
KEY=$ROOT/nord.key
CERT=$ROOT/nord.crt
sed -e '/^$/d' -e '/^#/d' -e '/^remote\ [0-9\.\ ]\+$/d' \
    -e '/<ca>/,/ca>/d' -e '/<tls-auth>/,/tls-auth>/d' \
    < $1 > $CONF
sed -ne '/^-----BEGIN\ OpenVPN\ Static\ key\ V1-----$/,/^-----END\ OpenVPN\ Static\ key\ V1-----$/p' \
    < $1 > $KEY
sed -ne '/^-----BEGIN\ CERTIFICATE-----$/,/^-----END\ CERTIFICATE-----$/p' \
    < $1 > $CERT

# Retrieve each unique server address and append to one file.
ADDR=$ROOT/$COUNTRY
rm -f $ADDR
N=0
for SERVER in $@ ; do
    echo -ne "Importing $COUNTRY ip addresses $(( 100 * ++N / $# ))% ...\\r"
    sed -ne '/^remote\ [0-9\.\ ]\+$/p'	< $SERVER >> $ADDR
    if [ $N -ge 64 ] ; then break ; fi ; # 64 is ovpn max permitted remotes
done

echo -e "Importing $COUNTRY ip addresses 100% ... Done, $N addresses imported."

# Reconstruct combined ovpn configuration file with multiple remote
# directives.

OVPN=$ROOT/nord-$COUNTRY.ovpn
{
    echo "# NordVPN $COUNTRY openvpn configuration file"
    echo "# Created by nordvpn-update on $(date)"
    echo "# https://github.com/DeanoCYM/nordvpn-update"
    cat $CONF $CUSTOMCONF
    echo "# $N $COUNTRY addresses imported"
    cat $ADDR
    echo "<ca>"
    cat $CERT
    echo "</ca>"
    echo "<tls-auth>"
    cat $KEY
    echo "</tls-auth>"
} > $OVPN

echo -e "Created $OVPN.\nSUCCESS."
