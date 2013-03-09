#!/bin/sh

######
## This script runs after you've unzipped the patch cluster and want to
## start applying patches to a new BE.
##
## It does check to see if LiveUpgrade has been set up, and sets it up if
## it hasn't.
######

PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/sbin
export PATH

date

# import functions

scriptdir=`dirname $0`

. ${scriptdir}/lu-funcs.sh

# Obtain information about the type of machine and OS
douname

# Make sure there are no inactive BEs.  If there are, print an error and exit.
chk_inactive_be

# generate a name for the new be
name_new_be RC
if [ "X${NEW_BE}" != 'X' ]; then
  NEWBE=${NEW_BE}
fi


# Check to see if we're using ZFS or UFS for the root filesystem
POOL=`/bin/df -k / | awk -F/ '/ROOT/ {print $1}'`

if [ "X${POOL}" = 'X' ]; then
  # Our root filesystem is on a UFS partition

  # make sure the /lu partitions are umounted and commented out of /etc/vfstab
  prep_lu_mnts

  # Determine the current root and var partitions
  CURROOT=`/bin/df -k / | awk '/^\/dev/ {print $1}'`
  CURVAR=`/bin/df -k /var | awk '/^\/dev/ {print $1}'`

  # Check to see if there are any BEs configured at all
  chk_default_be

  # If not, determine the name for the default BE
  if [ "X${NOLU}" = 'X1' ]; then
    name_new_be JS
    if [ "X${NEW_BE}" != 'X' ]; then
      CURBE=${NEW_BE}
    fi
  fi

  # Determine what the new BE partitions for / and /var should be
  set_lu_partitions

  # create the new boot environment
  if [ -x /etc/lib/lu/lubootdevice ]; then
    LUROOT=`/etc/lib/lu/lubootdevice`
  elif [ -x /etc/lib/lu/lurootdev ]; then
    LUROOT=`/etc/lib/lu/lurootdev`
  else
    echo "Can not determine current root device"
    exit 1
  fi

  # perform the lucreate
  if [ ${NOLU} -eq 1 ]; then
    echo "lucreate -C ${LUROOT} -c ${CURBE} -m /:${NEWROOT}:ufs -m /var:${NEWVAR}:ufs -n ${NEWBE}"
    lucreate -C ${LUROOT} -c "${CURBE}" -m /:${NEWROOT}:ufs -m /var:${NEWVAR}:ufs -n "${NEWBE}" || exit 1
  else
    echo "lucreate -C - -m /:${NEWROOT}:ufs -m /var:${NEWVAR}:ufs -n ${NEWBE}"
    lucreate -m /:${NEWROOT}:ufs -m /var:${NEWVAR}:ufs -n "${NEWBE}" || exit 1
  fi
else
  # We're on a ZFS partition and ZFS has already set up an inital boot env
  lucreate -n ${NEWBE} -p ${POOL}
fi
  
date
