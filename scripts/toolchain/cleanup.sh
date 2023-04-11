#!/usr/bin/env bash

SCRIPTDIR=$(dirname $(readlink -f $BASH_SOURCE))
SCRIPTDIR=$(readlink -f $SCRIPTDIR)

cleaninstall=${CLEANINSTALL:-}

if [ "x$TOOLVER" == "x" ] ; then
    echo "INFO: cleanup last build version toolchain"
    DOREBUILD=1 source $SCRIPTDIR/utils.sh
else
    echo "INFO: cleanup toolchain version $TOOLVER"
    source $SCRIPTDIR/utils.sh
fi

sleep 3
cleanup_build $cleaninstall
exit 1
