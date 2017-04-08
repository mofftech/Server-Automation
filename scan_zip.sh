#!/bin/sh
#
# sh script to scan zip attachments with Exim
#
# http://www.moff.tech/
# https://github.com/mofftech/Server-Automation
#
# Version:  2016121800
# Requires: logger, grep, unzip, ls
#
# First insert this stanza into conf.d/acl/40_exim4-config_check_data:
#
#  deny message = Please don't email me attachments, send them via google docs or some such
#       log_message = DENY: zip with blocked content
#       demime      = zip
#       condition   = ${run{/etc/exim4/scan_zip.sh $message_id}{0}{1}}

ID="$1" # $1 must be $message_id from Exim

# Check these settings:

LOGGER="/usr/bin/logger"
cmd_logger="$LOGGER -p local0.notice"
cmd_grep='/bin/grep'
cmd_unzip='/usr/bin/unzip'
cmd_ls='/bin/ls'
DIRSCAN="/var/spool/exim4/scan/$ID"
UNSAFE='\.exe$|\.com$|\.js$|\.cmd$|\.pif$|\.bat$|\.btm$|\.cpl$|\.dll$|\.lnk$|\.msi$|\.prf$|\.zip$|\.7z$|\.gz$|\.reg$|\.scr$|\.vbs$|\.rar$|\.url$|\.wsf$|\.docm|\.hta$|\.jse$|\.ace$|\.dzip$'

# Nothing under here should need to be changed

cd "$DIRSCAN" || exit 0

for a in $($cmd_ls | $cmd_grep -iE '\.zip$'); do
 FLIST="$($cmd_unzip -ql "$a" | $cmd_grep -iE "$UNSAFE")"
 if [ ! -z "$FLIST" ]; then
    #$cmd_logger "Exim fail on $ID for $a found $FLIST"
    exit 1
 fi
done

#$cmd_logger "Exim pass $ID"

exit 0
