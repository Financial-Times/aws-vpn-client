#!/bin/bash

set -e

# path to the patched openvpn
OVPN_BIN="./openvpn"
OVPN_CONF="FT Default VPN.ovpn"
OVPN_CONF_TMP="$OVPN_CONF.tmp"
PORT=1194
PROTO=udp

wait_file() {
  local file="$1"; shift
  local wait_seconds="${1:-10}"; shift # 10 seconds as default timeout
  until test $((wait_seconds--)) -eq 0 -o -f "$file" ; do sleep 1; done
  ((++wait_seconds))
}

cp "$OVPN_CONF" "$OVPN_CONF_TMP"
VPN_HOST=$(cat "$OVPN_CONF_TMP" | sed -n "s/^remote\s\(.*\)\s443.*$/\1/p")
# create random hostname prefix for the vpn gw
RAND=$(openssl rand -hex 12)
# resolv manually hostname to IP, as we have to keep persistent ip address. Hardcoded to get the third result
SRV=$(dig a +short "${RAND}.${VPN_HOST}"|sed -n '3p')
# Replace hostname with IP in ovpn file
sed -i "/^remote\s\(.*\)\s443.*$/c\remote $SRV 443" "$OVPN_CONF_TMP"

# cleanup
rm -f saml-response.txt

# start go subprocess to capture saml response
go run ./server.go &
go_server_pid=$!

echo "Getting SAML redirect URL from the AUTH_FAILED response (host: ${SRV}:${PORT})"
OVPN_OUT=$($OVPN_BIN --config "${OVPN_CONF_TMP}" \
     --proto "$PROTO" --remote $SRV $PORT \
     --auth-user-pass <( printf "%s\n%s\n" "N/A" "ACS::35001" ) \
    2>&1 | grep AUTH_FAILED,CRV1)

echo "Opening browser and wait for the response file..."
URL=$(echo "$OVPN_OUT" | grep -Eo 'https://.+')
xdg-open "$URL"

wait_file "saml-response.txt" 30 || {
  echo "SAML Authentication time out"
  exit 1
}

# kill go subprocess as it is no longer needed
pkill -P $go_server_pid

# get SID from the reply
VPN_SID=$(echo "$OVPN_OUT" | awk -F : '{print $7}')

echo "Running OpenVPN with sudo. Enter password if requested"

# Finally OpenVPN with a SAML response we got
# Delete saml-response.txt after connect
sudo bash -c "$OVPN_BIN --config '${OVPN_CONF_TMP}' \
    --verb 3 --auth-nocache --inactive 3600 \
    --proto "$PROTO" --remote $SRV $PORT \
    --script-security 2 \
    --route-up '/bin/rm saml-response.txt' \
    --auth-user-pass <( printf \"%s\n%s\n\" \"N/A\" \"CRV1::${VPN_SID}::$(cat saml-response.txt)\" )"

# cleanup
rm -f saml-response.txt
rm -f "$OVPN_CONF_TMP"
