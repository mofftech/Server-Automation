# Server-Automation
Server scripts to speed up mundane tasks. No Puppet, Ansible or Chef here sorry, just some one off scripts that get odd jobs done!

## backup-server.sh

Backup critical server directories (Debian focussed) to a remote server with scp.

## ipsec-cert-management.sh

Create or revoke certificates for IPsec.

## letsencrypt-handle-certs.sh

Let's Encrypt automates the process of getting a cert and installing it to apache easy. The complication is when you want to reuse that certificate for mail handling.

This script automates the process of renewing the letsencrypt certificate for apache2 and additionally updating exim4 and dovecot with the new certs.

## scan_zip.sh

Script called by Exim to to inspect the contents of zip attachments.
