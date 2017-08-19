#!/bin/bash
# 
# Version: 2016090300
# 
# https://github.com/mofftech/Server-Automation
# http://www.moff.tech/
#
# Auto renewal of lentsencrypt certs and handle exim special permissions.
# Restart exim4, dovecot and apache2. Designed to be cron friendly.
# Warning! Exim, Dovecot and Apache2 are reloaded at the end.
#
# Add to crontab similar to the following:
# 1       0       2       MAR,JUN,SEP,DEC *       some_path/letsencrypt-handle-certs.sh
#
# Be aware that the next certificate will expire on the preceding day

###                                                 ###
### Below, set LEDOMAIN,LEINSTALLPATH, check others ###
###                                                 ###

LEBASE="/etc/letsencrypt"             # LE base config path
LEDOMAIN=""                           # The domain in the LEBASE path
LELIVEDIR="$LEBASE/live/$LEDOMAIN"    # Your LE live certs dir
LEARCHDIR="$LEBASE/archive/$LEDOMAIN" # Your LE archive certs dir
LEFILES="fullchain.pem privkey.pem"   # The names of the LE certs
LEINSTALLPATH="some_path/letsencrypt" # Where you run the LE cmds (like "renew) from
EXIMDIR="/etc/exim4"                  # Exim config path
EXIMPERMS="root.Debian-exim"          # user.group of Exim certs

###                                                 ###
### Nothing below here should need to be customised ###
###                                                 ###

# letsencrypt scripts require $PATH to be set
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# cron has a restricted $PATH. echo should be a builtin.
# This is actually redundant due to PATH export above.
cmd_date="/bin/date"
cmd_service="/usr/sbin/service"
cmd_ls="/bin/ls"
cmd_mv="/bin/mv"
cmd_cp="/bin/cp"
cmd_chown="/bin/chown"
cmd_chmod="/bin/chmod"
cmd_grep="/bin/grep"
cmd_renew="$LEINSTALLPATH/letsencrypt-auto"

# Test existence of cmds
for b in $cmd_date $cmd_service $cmd_ls $cmd_mv $cmd_cp $cmd_chown $cmd_chmod $cmd_grep $cmd_renew; do
   if [ ! -f "$b" ]; then
      echo -e "$b not installed, or wrong path."
      exit 1
   fi
done

# Test existence of dirs
for d in $LELIVEDIR $LEARCHDIR $LEINSTALLPATH $EXIMDIR; do
   if [ ! -d "$d" ]; then
      echo -e "$d not present, cannot continue."
      exit 1
   fi
done

if [ "$1" == "-d" ]; then
   DEBUG="y"
fi
DEBUG="y" # Always debug mode

showledirs() {
   echo -e "\n$LELIVEDIR"
   $cmd_ls -la "$LELIVEDIR/"
   echo -e "\n$LEARCHDIR"
   $cmd_ls -la "$LEARCHDIR/"
}
showeximdir() {
   echo -e "\n$EXIMDIR"
   $cmd_ls -la "$EXIMDIR"
}

[[ ! -z "$DEBUG" ]] && showledirs

DATE="$($cmd_date +%s)"

LEOUTPUT="$($cmd_renew renew)"
if [ "$?" != "0" ]; then
   showledirs
   echo -e "\nLooks like letsencrypt failed. Exiting."
   exit 1
fi

echo -e "$LEOUTPUT"

if [ ! -z "$(echo -e "$LEOUTPUT" | $cmd_grep 'not due for renewal yet')" ]; then
   [[ ! -z "$DEBUG" ]] && echo -e "\nHmm, looks like letsencrypt did nothing. Exiting."
   exit 0
fi

if [ ! -z "$(echo -e "$LEOUTPUT" | $cmd_grep 'No renewals were attempted')" ]; then
   echo -e "\nHmm, looks like letsencrypt did nothing. Exiting."
   exit 0
fi

[[ ! -z "$DEBUG" ]] && showledirs
[[ ! -z "$DEBUG" ]] && showeximdir

# Check the certs exist
for f in $LEFILES; do
   if [ -f "$LELIVEDIR/$f" ]; then
      [[ ! -z "$DEBUG" ]] && echo -e "\n$LELIVEDIR/$f exists."
   else
      echo -e "\n$LELIVEDIR/$f does not exist! Exiting."
      exit 1
   fi
done

for f in $LEFILES; do
   [[ ! -z "$DEBUG" ]] && echo -e "\nBackup exim cert, copy in the new one."
   $cmd_mv "$EXIMDIR/$f" "$EXIMDIR/$f-$DATE"
   $cmd_cp "$LELIVEDIR/$f" "$EXIMDIR/"
   $cmd_chown "$EXIMPERMS" "$EXIMDIR/$f"
   $cmd_chmod 640 "$EXIMDIR/$f"
   [[ ! -z "$DEBUG" ]] && $cmd_ls -la "$EXIMDIR/$f"
done

[[ ! -z "$DEBUG" ]] && showeximdir

# Reload new certs 
$cmd_service exim4   reload
$cmd_service dovecot reload
$cmd_service apache2 reload

exit 0
