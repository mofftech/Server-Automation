#!/bin/bash
#
# Version:  2016072800
#
# Certificate creation and reversion.

[[ -z $1 ]] && echo "Specify hostname." && exit 0

# Configure the next 7 lines carefully:

SSLDIR="/etc/ssl"
IPSECDIR="/etc/ipsec.d"
SERVERNAME="$HOSTNAME"
CAKEY="$IPSECDIR/private/caKey-$SERVERNAME.pem"
CACRT="$IPSECDIR/cacerts/caCert-$SERVERNAME.pem"
#CAKEY="$IPSECDIR/private/caKey-again.pem"
#CACRT="$IPSECDIR/certs/caCert-again.pem"
CRLDIR="$IPSECDIR/crls"
CRLFILE="$SERVERNAME.crl"
#
# You should be able to leave this as is:
#
WD="$(pwd)"
[[ $(echo "$1" | grep '^/') ]] && RCERT="$1" || RCERT="$WD/$1"
CRLOUT="$CRLDIR/$CRLFILE"
CERTNAME="$1-$(date +%s)"
CERTDIR="$IPSECDIR/clientcerts/$CERTNAME"
KEYP="$CERTDIR/$CERTNAME-Key.pem"
KEYR="$CERTDIR/$CERTNAME-Req.pem"
KEYC="$CERTDIR/$CERTNAME-Cert.pem"
KEYW="$CERTDIR/$CERTNAME-Key.p12"
#
cd $SSLDIR
#
if [ -f $RCERT ]; then
   echo -e "$RCERT exists. Do you want to revoke this Certificate? [y/N]: \c"
   read revoke
   if [ "$revoke" != "y" ]; then
      echo -e "Cancelled."
   else
      mkdir -p $CRLDIR
      openssl ca -revoke $RCERT -cert $CACRT -keyfile $CAKEY
      if [ "$?" == "0" ]; then
         mv $RCERT $RCERT-revoked
      else
         echo "Error detected. Cancelling."
         exit 2
      fi
      openssl ca -gencrl -cert $CACRT -keyfile $CAKEY -out $CRLOUT
      openssl crl -inform PEM -text -noout -in $CRLOUT
      echo -e "\nDone, check for errors above. YOU MUST RESTART IPSEC!"
      ls -la $RCERT-revoked
   fi
   exit 0
fi
#
mkdir -p $CERTDIR
#
# Create a private key and signing request
openssl req -newkey rsa:2048 -keyout $KEYP -out $KEYR
#
# Generate a signed public key
openssl ca -in $KEYR -days 3650 -out $KEYC -notext -cert $CACRT -keyfile $CAKEY
#
# Generate a windows friendly key
openssl pkcs12 -export -inkey $KEYP -in $KEYC -certfile $CACRT -out $KEYW -name "$i"
#
#
echo "Import $KEYW to your Windows client."
#
chmod 400 $CERTDIR/*
ls -la $CERTDIR
#
exit 0
