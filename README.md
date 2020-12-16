# aws-vpn-client

This is PoC to connect to the AWS Client VPN with OSS OpenVPN using SAML
authentication. Tested on macOS and Linux, should also work on other POSIX OS with a minor changes.

See [my blog post](https://smallhacks.wordpress.com/2020/07/08/aws-client-vpn-internals/) for the implementation details.

## Content of the repository

- [openvpn-v2.4.9-aws.patch](openvpn-v2.4.9-aws.patch) - patch required to build
AWS compatible OpenVPN v2.4.9, based on the
[AWS source code](https://amazon-source-code-downloads.s3.amazonaws.com/aws/clientvpn/wpf-v1.2.0/openvpn-2.4.5-aws-1.tar.gz) (thanks to @heprotecbuthealsoattac) for the link.
- [server.go](server.go) - Go server to listed on http://127.0.0.1:35001 and save
SAML Post data to the file
- [aws-connect.sh](aws-connect.sh) - bash wrapper to run OpenVPN. It runs OpenVPN first time to get SAML Redirect and open browser and second time with actual SAML response

## How to use

1. Download openvpn source, patch, and build
```bash
git clone https://github.com/samm-git/aws-vpn-client
cd aws-vpn-client
wget https://swupdate.openvpn.org/community/releases/openvpn-2.4.9.zip
unzip openvpn-2.4.9.zip
cd openvpn-2.4.9
patch -p1 < ../openvpn-v2.4.9-aws.patch
./configure --prefix="$(pwd)/bin"
make
make install
cp bin/sbin/openvpn ../
cd ../
```
2. Download `FT Default VPN.ovpn` from Google Drive and include it in this directory
3. Remove `auth-federate` and `auth-retry interact` options from `.ovpn` file
4. Run `./aws-connect.sh`
