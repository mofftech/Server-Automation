#!/bin/bash
#
# https://github.com/mofftech/Server-Automation
#
# Version: 2016071200
#
# Backup this server to a remote server (via scp).
# This will not run well in cron due to missing paths.
# Use ssh-genkey and ssh-copy-id for passwordless scp.

# Customise these
backupdir="/backup/"                               # Working dir on this server
remoteserver="10.1.1.1"                            # IP or FQDN of remote storage
#remoteserver="$(curl http://some-dyn-dns/?=etc)"  # Dyndns could be done here
destbackupdir="/storage/nobackup/backups-remote/"  #  -> Dir on remote storage
sshuser="you"                                      # SSH user on remote server
mailto="root"                                      # Script's email goes to this user

# Recommended defaults
date=$(date +%F)
prefix=$date-$HOSTNAME
sshopt="-oStrictHostKeyChecking=no"
rsakey="/home/$sshuser/.ssh/id_rsa"
testfile="$prefix-scp_test"
msg=""

[ ! -r $backupdir ] && echo -e "$backupdir does not exist." && exit 0

scptest()
{
 touch $testfile
 scp -i $rsakey $sshopt $testfile $sshuser@$remoteserver:$destbackupdir
 [ $? -ne 0 ] && echo -e "$remoteserver not responding to ssh. Exiting." && exit 0
 [ -f $testfile ] && rm -f $testfile
 # If the remote server needs to have the backup dir mounted first:
 #ssh -i $rsakey $sshopt $sshuser@$remoteserver "mount $destbackupdir"
}

scpcopy() 
{
 echo -e "Copy files to remote server..."
 for m in $(ls $backupdir$date*); do
  #echo "$backupdir$date"; exit 0
  LM="$(md5sum $m)"
  echo -e "$LM"
  bname="$(basename $m)"
  scp -i $rsakey $sshopt $m $sshuser@$remoteserver:$destbackupdir
  [ $? -ne 0 ] && echo "Failed. Exiting." && exit 0
  RM=$(ssh -i $rsakey $sshopt $sshuser@$remoteserver "md5sum $destbackupdir$bname")
  echo "$RM"
  if [ "$(echo $LM | awk '{print $1}')" == "$(echo $RM | awk '{print $1}')" ]; then
   echo "Copy okay."
  else
   echo "Copy failed."
   exit 0
  fi
 done
 #scp -i $rsakey $sshopt $backupdir/date* $sshuser@$remoteserver:$destbackupdir
 #[ $? -ne 0 ] && echo "Failed. Exiting." && exit 0
 echo -e " done."
}

clearbackups()
{
 echo -e "Clear out $backupdir..."
  if [ "$backupdir" != "" ] && [ -d "$backupdir" ]; then
   df -h
   ls -la $backupdir
   rm -f $backupdir/*
   [ $? -ne 0 ] && echo -e "\nFailed. Exiting script." && exit 0
   df -h
   ls -la $backupdir
  else
   echo -e "\"$backupdir\" is not dir or string is empty. Exit."
   exit 0
  fi
}

[ $(whoami) != "root" ] && echo "You must be root or run as sudo." && exit 0

[ -z $remoteserver ] && echo "Unable to determine remote server. scp will fail later."
echo -e "Backup destination server: $remoteserver.\n"

scptest

msg="$(date) - $0 started."

echo -e "Working in $backupdir."
 cd $backupdir
 clearbackups
 [ $? -ne 0 ] && echo -e "\nFailed to change directory. Exiting." && exit 0
if [ "$1" == "scponly" ]; then
 echo "scp copy only."
 scpcopy
 exit 0
fi

echo -e "Configuration files...\c"
 tar jcf $prefix-etc.tar.bz /etc/
 [ $? -ne 0 ] && echo " failed. Exiting." && exit 0
echo -e " done."

scpcopy
clearbackups

echo -e "Webpages...\c"
 tar jcf $prefix-www.tar.bz /var/www/
 [ $? -ne 0 ] && echo " failed. Exiting." && exit 0
 tar jcf $prefix-cgi-bin.tar.bz /usr/lib/cgi-bin/
 [ $? -ne 0 ] && echo " failed. Exiting." && exit 0
echo -e " done."

scpcopy
clearbackups

echo -e "Home directories...\c"
 for h in $(ls /home); do
  echo -e "Stop exim and dovecot."
  /etc/init.d/exim4 stop
  /etc/init.d/dovecot stop
  tar jcf $prefix-home-$h.tar.bz /home/$h/
  #
  # May run out of local storage, scp now and delete
  #
  echo -e "Start exim and dovecot again."
  /etc/init.d/exim4 start
  /etc/init.d/dovecot start
  scpcopy
  clearbackups
 done
 [ $? -ne 0 ] && echo " failed. Exiting." && exit 0
echo -e " done."

echo -e "Mail files... temporarily stop exim and dovecot...\c"
 echo -e "Stop exim and dovecot."
 /etc/init.d/exim4 stop
 /etc/init.d/dovecot stop
 tar jcf $prefix-mail.tar.bz /var/mail/
 echo -e "Start exim and dovecot again."
 /etc/init.d/exim4 start
 /etc/init.d/dovecot start
 [ $? -ne 0 ] && echo " failed. Exiting." && exit 0
echo -e " done."

echo -e "$(ls -l $date*)"

scpcopy
clearbackups

msg="$msg\r$(date) - $0 finished."
echo -e "$msg\r$(ls -la;df -h)" | mail -s "$0" $mailto

exit 0
