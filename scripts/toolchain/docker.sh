#!/usr/bin/env bash

SCRIPTDIR=$(dirname $(readlink -f $BASH_SOURCE))
SCRIPTDIR=$(readlink -f $SCRIPTDIR)

# enviroment variables
dockerrepo=${DOCKERREPO:-}
pullfirst=${PULLFIRST:-}

# arguments
# arg 1: toolchain to be built for, default linux64, otherwise will be win32
# arg 2: docker image tag, default latest
toolhost=${1:-linux64}
imgtag=${2:-latest}

# toolchain source directory
toolsrcdir=$(readlink -f $SCRIPTDIR/../..)

winbuildimg=gnutoolchain-ubuntu18.04
linbuildimg=gnutoolchain-centos6

if [ "x$dockerrepo" == "x" ] ; then
    if ping -qc 2 rego > /dev/null 2>&1; then
        dockerrepo=rego.corp.nucleisys.com/software
    else
        dockerrepo=docker.io/nucleisoftware
    fi
fi

dockercmd=podman
if which docker > /dev/null 2>&1 ; then
    dockercmd=docker
fi

echo "INFO: Using docker server: $dockerrepo"

function pull_image() {
    local imgrepo=$1
    echo "INFO: Pull image $imgrepo"
    $dockercmd pull $imgrepo
}

function run_image() {
    local imgrepo=$1
    shift
    local runcmd=$@
    echo "INFO: Run image $imgrepo, with $toolsrcdir mapping to /work, run command: $runcmd"
    local execmd="$dockercmd run -it -v ${toolsrcdir}:/work $imgrepo $runcmd"
    echo "CMD: $execmd"
    $execmd
}


img2run=$dockerrepo/$linbuildimg:$imgtag
runcmd="scl enable devtoolset-7 rh-python36 bash"

if [ "x$toolhost" == "xwin32" ] ; then
    echo "WARN: If you are build win32 toolchain, you need to add linux prebuilt riscv toolchain to PATH in docker enviroment!"
    img2run=$dockerrepo/$winbuildimg:$imgtag
    runcmd="bash"
else
    toolhost="linux64"
fi

if [ "x$pullfirst" == "x1" ] ; then
    echo "INFO: pull $img2run first!"
    pull_image $img2run
fi

echo "INFO: Run docker image for build toolchain for $toolhost environment"
run_image $img2run $runcmd
