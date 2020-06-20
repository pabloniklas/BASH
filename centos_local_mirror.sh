#!/bin/bash

RSYNC_HOST="rsync://mirrors.rit.edu/centos/"
RSYNC_PROXY=""

until rsync -avzSH --delete --exclude "local*" --exclude "isos" --exclude "/2*/" --exclude "/3*/" --exclude "/4*/" --exclude "/5*/" $RSYNC_HOST /u01/CentOS; do 
    sleep 1
done
