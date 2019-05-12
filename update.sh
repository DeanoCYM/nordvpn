#!/bin/bash
set -e

RESULTS=$HOME/nordvpn/results
mkdir -p $RESULTS
cd $HOME/nordvpn

# Update and unzip NordVPN server configuration files. Only process if
# the archive is newer than local configuration files.
wget -N https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip
unzip -uo ovpn.zip

# Set each of the uk servers as shell arguements for easy processing.
UDP_DIR="$PWD/ovpn_udp"
set -- $(find $UDP_DIR -regextype sed \
	      -regex '.*uk[0-9]\{1,4\}\.nordvpn.com.udp.ovpn')

# Extract and store the common information (configurations,
# certificates and keys) from the first uk server.
CONF=$RESULTS/nord.conf
KEY=$RESULTS/nord.key
CERT=$RESULTS/nord.crt

sed -e '/^$/d' -e '/^#/d' -e '/<ca>/,/ca>/d' -e '/<tls-auth>/,/tls-auth>/d' \
    < $1 > $CONF

sed -ne '/^-----BEGIN\ OpenVPN\ Static\ key\ V1-----$/,/^-----END\ OpenVPN\ Static\ key\ V1-----$/p' \
    < $1 > $KEY

sed -ne '/^-----BEGIN\ CERTIFICATE-----$/,/^-----END\ CERTIFICATE-----$/p' \
    < $1 > $CERT

# Retreive each unique server address and append to one file.
ADDR=$RESULTS/uk.ip

n=0
for SERVER in $@ ; do
    echo -ne Importing UK IP addresses $(( 100 * ++n / $# ))%...\\r
    sed -Ene 's/^remote\ ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\ [0-9]+$/\1/p' < $SERVER >> $ADDR
done

echo -e Importing UK IP addresses 100% ... $# imported, success!

