#!/bin/bash
#Changes owner of Search Dashboard
PARCEL_DIR=/opt/cloudera/parcels/CDH

USAGE="usage: $0"

OVERRIDE=$1

if [[ ! ${USER} =~ .*root* ]]
then
  if [[ -z ${OVERRIDE} ]]
  then
    echo "Script must be run as root: exiting"
    exit 1
  fi
fi

if [ ! -d "/usr/lib/hadoop" ]
then
   CDH_HOME=$PARCEL_DIR
else
   CDH_HOME=/usr
fi

if [[ -z ${HUE_CONF_DIR} ]]
then
   if [ -d "/var/run/cloudera-scm-agent/process" ]
   then
      HUE_CONF_DIR="/var/run/cloudera-scm-agent/process/`ls -1 /var/run/cloudera-scm-agent/process | grep HUE_SERVER | sort -n | tail -1 `"
   else
      HUE_CONF_DIR="/etc/hue/conf"
   fi
   export HUE_CONF_DIR
fi

if [ -d "${CDH_HOME}/lib/hue/build/env/bin" ]
then
   COMMAND="${CDH_HOME}/lib/hue/build/env/bin/hue shell"
else
   COMMAND="${CDH_HOME}/share/hue/build/env/bin/hue shell"
fi

if [[ -z ${ORACLE_HOME} ]]
then
   ORACLE_HOME=/opt/cloudera/parcels/ORACLE_INSTANT_CLIENT/instantclient_11_2/
   LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${ORACLE_HOME}
   export ORACLE_HOME LD_LIBRARY_PATH
fi
HUE_IGNORE_PASSWORD_SCRIPT_ERRORS=1
export CDH_HOME COMMAND HUE_IGNORE_PASSWORD_SCRIPT_ERRORS

echo "HUE_CONF_DIR: ${HUE_CONF_DIR}"
echo "COMMAND: ${COMMAND}"

${COMMAND} <<EOF
from datetime import datetime
from django.db import models
from desktop.models import Document, Document2
from django.contrib.auth.models import User

for user in User.objects.filter():
#  print user.username
  last_modified=datetime.now()
  oldest_doc=0L
  movecount=1
  homedir_count=0
  for document in Document2.objects.filter(owner=user, parent_directory=None, name=Document2.HOME_DIR):
    homedir_count=homedir_count + 1
  if homedir_count > 1:
    print "%s has more than 1 homedir" % user.username
    print "Fixing by moving newer ones to subdirectories"
    for document in Document2.objects.filter(owner=user, parent_directory=None, name=Document2.HOME_DIR):
      homedir_count=homedir_count + 1
      if document.last_modified < last_modified:
        last_modified=document.last_modified
        oldest_doc_id=document.id 
    print "Oldest doc is %s" % oldest_doc_id
    oldest_doc = Document2.objects.get(id=oldest_doc_id)
    for document in Document2.objects.filter(owner=user, parent_directory=None, name=Document2.HOME_DIR):
      if document.id != oldest_doc_id:
        document.name="scriptmoved%s" % movecount
        document.parent_directory=oldest_doc
        document.save()
        movecount=movecount + 1


EOF
