#!/bin/bash
set -e

# Author: Ellis Rhys Thomas
# Script: nordvpn-country-codes.sh
# Date: 2019
# Depends: jq, curl
#
## 
## USAGE: nordvpn-country-codes
##  
## Retrieves all NordVPN .ovpn configuration files and stores them in
## /etc/openvpn/client/nordvpn. Determines the fastest avalible vpn
## server and symlinks this configuration to /etc/openvpn/nordvpn.conf.

curl --silent "https://api.nordvpn.com/v1/servers/countries" \
    | jq --raw-output '.[] | [.id, .name] | @tsv'
