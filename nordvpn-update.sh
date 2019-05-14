#!/bin/bash
set -e

# NORDVPN-UPDATE.SH
#
# Retrieves the NordVPN .ovpn configuration files for the specified
# country and protocol and installs them to /etc/ovpn/.

# Argument pre-processing requires getopt from linux-utils for long
# form (--arg) arguments to process correctly.
ARG_ERR="\nnordvpn-update [-h] [-c country] [-u url] [-p protocol] [-d directory] [-a custom.conf]\n\nRetrieves the NordVPN .ovpn configuration files for the specified\ncountry and protocol and installs them to /etc/ovpn/.\n\nOptions:\n\n h, --help\tdisplay this help and exit\n c, --country\tset server country (uk, us, fr, etc.)\n\t\tdefaults to uk\n p, --protocol\tcommunication protocol (udp, tcp)\n\t\tdefaults to udp\n u, --url\tserver ovpn url\n\t\tdefaults to https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip\n d, --directory\tset installation directory\n\t\tdefaults to /etc/openvpn\n a, --append\tpath to custom configuration options appended to configuration\n\t\tdefaults to $HOME/.nordvpn/custom.conf\n"

ARGV=`getopt -o hu:c:p:u:d:a: \
	     --long help,url:,country:,protocol:,url:,directory:,append:,\
	     -n 'nordvpn-update' -- "$@"`
if [ $? != 0 ] ; then echo "Invalid Arguments.\n\n$ARG_ERR"  >&2 ; exit 1 ; fi
eval set -- "$ARGV"

# Set some sane defaults and process arguments
ROOT="$HOME/.nordvpn"
COUNTRY='uk'
URL='https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip'
DIR='/etc/ovpn'
PROTOCOL='udp'
CUSTOM="$ROOT/custom.conf"

while true; do
  case "$1" in
      -h | --help      ) echo -e $ARG_ERR; exit 1;;
      -c | --country   ) COUNTRY="$2";     shift 2;;
      -p | --protocol  ) PROTOCOL="$2";    shift 2;;
      -u | --url       ) URL="$2";         shift 2;;
      -d | --directory ) DIRECTORY="$2";   shift 2;;
      -a | --append    ) CUSTOM="$2";      shift 2;;
      --               )                   break;;
      *                ) echo -e $ARG_ERR; exit 1;;
  esac
done

# Update and unzip NordVPN server configuration files. Only process if
# the archive is newer than local configuration files.
mkdir -p $ROOT
wget --tries=2 --timestamping --directory-prefix=$ROOT $URL
unzip -uoq $ROOT/ovpn.zip -d $ROOT

# Set each of the specified country's servers as shell arguments for
# easy processing.
DIR=$ROOT/ovpn_$PROTOCOL
set -- $(find $DIR -regextype sed \
	      -regex ".*$COUNTRY[0-9]\{1,4\}\.nordvpn.com.$PROTOCOL.ovpn")

# Extract and store configuration
OVPN=$ROOT/nord-$COUNTRY-$PROTOCOL.ovpn
{
    echo "# NordVPN $COUNTRY openvpn configuration file"
    echo "# Created by nordvpn-update on $(date)"
    echo "# https://github.com/DeanoCYM/nordvpn-update"
    sed -e '/^$/d' -e '/^#/d' -e '/^remote\ [0-9\.\ ]\+$/d' \
	-e '/<ca>/,/ca>/d' -e '/<tls-auth>/,/tls-auth>/d' \
	< $1
} > $OVPN

# Custom configuration file is optionally appended if present in
# $ROOT/custom.conf
if [ -f "$FILE" ]; then
    cat $CUSTOM >> $OVPN
fi

# Remote server addresses
N=0
for SERVER in $@ ; do
    echo -ne "Importing $COUNTRY ip addresses $(( 100 * ++N / $# ))% ...\\r"
    sed -ne '/^remote\ [0-9\.\ ]\+$/p'	< $SERVER >> $OVPN
    if [ $N -ge 64 ] ; then break ; fi ; # 64 is ovpn max permitted remotes
done

echo -e "Importing $COUNTRY ip addresses 100% ... Done, $N addresses imported."
echo "# $N $COUNTRY addresses imported" >> $OVPN

# Certificate and key
{
    echo "<ca>"
    sed -ne '/^-----BEGIN\ CERTIFICATE-----$/,/^-----END\ CERTIFICATE-----$/p' \
	< $1
    echo "</ca>"
    echo "<tls-auth>"
    sed -ne '/^-----BEGIN\ OpenVPN\ Static\ key/,/^-----END\ OpenVPN\ Static\ key/p' \
	< $1
    echo "</tls-auth>"
} >> $OVPN

echo -e "Created $OVPN.\nSUCCESS."
