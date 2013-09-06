#!/bin/bash

# PiBowl -- www.chokepoint.net
# This is an auto setup script for Asterisk to be setup on a Raspberry Pi
# Using a baseline Raspbian installation, just run this script to get started
# You'll be prompted to enter a password while generating server keys.
# You can also create as many initial client keys as you like.

AST_IP=192.168.77.1 # Change me to match your VPN settings. 
AST_NAME='PiBowl_Communications' # Used as the organization name in certificates
ALLOW_CONTACT=192.168.77.0\\/255.255.255.0 # Change me based on your VPN config to only allow local calls
EXTEN=100 	# First client generated will be extension 100

# Install a couple of dependencies so that we can compile Asterisk.
apt-get install libncurses5-dev libxml2-dev libsqlite3-dev libssl-dev libsrtp0-dev

# Pull the latest Asterisk v 11 tarball
wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-11-current.tar.gz
tar -xvf asterisk-11-current.tar.gz

# Stupid hack, but unless you have multiple versions it works
cd asterisk-11.*

# Ensure we aren't missing any dependencies
./configure

# Grab makeopts.dep files and insert them so we don't need to make menuconfig again.
cp ../menuselect.make* ./

# Compile Asterisk & install
make
# make menuconfig # uncomment if you require special modules
make install
make samples

cp ../sip.conf /etc/asterisk/sip.conf

mkdir /etc/asterisk/keys

echo '[-] Generating Server Keys'
echo '[-] When prompted, come up with a password that will be used for signing keys in the future'

./contrib/scripts/ast_tls_cert -d /etc/asterisk/keys -C $AST_IP -O $AST_NAME

echo '[-] Enter client name one per line in order to generate keys.'
echo '[-] Use ^d when you are done entering clients.'

echo '[pibowl]' >> /etc/asterisk/extensions.conf

# Continue to get user input until they're done adding clients
while read -p "Client: " CLIENT; do
		echo '[-] Generating Client Key for' $CLIENT
        ./contrib/scripts/ast_tls_cert -m client -c /etc/asterisk/keys/ca.crt -k /etc/asterisk/keys/ca.key -C $CLIENT -O $AST_NAME -d /etc/asterisk/keys -o $CLIENT
        
        # Add the user to sip.conf so they can actually log in.
        # PiBowl1532 is not a secure password, please change it later.
        CLIENT_PW='PiBowl'$RANDOM
        echo '['$CLIENT']' >> /etc/asterisk/sip.conf
        echo 'type=peer' >> /etc/asterisk/sip.conf
        echo 'secret='$CLIENT_PW >> /etc/asterisk/sip.conf
        echo 'host=dynamic' >> /etc/asterisk/sip.conf
        echo 'context=pibowl' >> /etc/asterisk/sip.conf
        echo 'dtmfmode=rfc2833' >> /etc/asterisk/sip.conf
        echo 'disallow=all' >> /etc/asterisk/sip.conf
        echo 'allow=g722' >> /etc/asterisk/sip.conf
        echo 'transport=tls' >> /etc/asterisk/sip.conf
        echo 'encryption=yes' >> /etc/asterisk/sip.conf
        echo '' >> /etc/asterisk/sip.conf
         
        # Add the user's extension to extensions.conf
        echo 'exten => '$EXTEN',1,Dial(SIP/'$CLIENT')' >> /etc/asterisk/extensions.conf
        
        echo '[-] Client '$CLIENT' generated using Extension '$EXTEN' and SIP password is '$CLIENT_PW
        
        EXTEN=$[EXTEN+1] # Increase extension by one for next client
done

echo '[-] Setting TLS Bind Address to '$AST_IP
sed -i "s/192.168.77.1/$AST_IP/g" /etc/asterisk/sip.conf
echo '[-] Whitelisting call range to the following IPs '$ALLOW_CONTACT
sed -i "s/192.168.77.0\/255.255.255.0/$ALLOW_CONTACT/g" /etc/asterisk/sip.conf

echo '[-] To start Asterisk in a console with verbose mode on use the following.'
echo 'sudo asterisk -vvvc'
