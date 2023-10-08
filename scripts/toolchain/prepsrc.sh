#!/usr/bin/env bash

SCRIPTDIR=$(dirname $(readlink -f $BASH_SOURCE))
SCRIPTDIR=$(readlink -f $SCRIPTDIR)

# arguments passed
# arg 1: libncrt branch, default master
# arg 2: toolchain source directory, default will find in ../../
# arg 3: toolchain branch
## sample usage:
## ./scripts/toolchain/prepsrc.sh master ~/rvtoolchain nuclei/2023
## it will clone master branch of libncrt, and clone repo to ~/rvtoolchain if not exist
## if toolchain source directory not exist, it will check out branch nuclei/2023
## If you want to specify where to clone toolchain, please set environment variable TOOLCHAIN_REPO
libncrt_branch=${1:-master}
toolsrcdir=${2:-$(readlink -f $SCRIPTDIR/../..)}
toolchain_branch=${3:-nuclei/2023}

## Environment Variables
# CLONE_DEPTH: clone depth, default all, if you want to clone minimal source code, set to 1
# TOOLCHAIN_REPO: riscv toolchain repo, default to nuclei internal repo
# LIBNCRT_REPO: nuclei c runtime library repo, not opensource, default internal server
# internal repo information
# libncrt repo will be cloned only when you have access to this repo
gitosrv=git@gito.corp.nucleisys.com
toolchain_repo=${TOOLCHAIN_REPO:-${gitosrv}:software/devtools/riscv-gnu-toolchain.git}
libncrt_repo=${LIBNCRT_REPO:-${gitosrv}:software/emrun/nuclei-emrun.git}
clone_depth=${CLONE_DEPTH:-}
fetch_jobs=${FETCH_JOBS:-4}
force_submodule=${FORCE_SUBMODULE:-}
force_recursive=${FORCE_RECURSIVE:-}

gitopts=""
if [ "x${clone_depth}" != "x" ] ; then
    echo "INFO: Clone depth set to ${clone_depth}"
    gitopts="$gitopts --depth ${clone_depth}"
else
    echo "INFO: Clone depth is not set!"
fi

if [ "x${fetch_jobs}" != "x" ] ; then
    echo "INFO: fetch jobs set to ${fetch_jobs}"
    gitopts="$gitopts --jobs ${fetch_jobs}"
fi

function show_repo_status() {
    echo "INFO: Show $(basename $(pwd)) repo and submodule status"
    git status -uno
    git submodule
}

function check_submodule() {
    if git submodule | grep -e "^[-|+]" ; then
        # submodule is not up to date or cloned
        return 1
    else
        return 0
    fi
}

function git_clone_repo() {
    local repo=${1}
    local repodir=${2}
    local branch=${3}
    local cloneopts=""
    if [ "x$repo" != "x" ] ; then
        if [ "x$branch" != "x" ] ; then
            cloneopts="-b ${branch} $gitopts"
        fi
        echo "INFO: Clone repo $repo to $repodir"
        git clone $cloneopts $repo $repodir
    else
        echo "No repo need to clone"
    fi
}

function git_submodule_update() {
    local otheropts=$@
    echo "INFO: Init and update repo $(basename $(pwd)) submodule"
    local rcsopts=""
    if [ "x${force_recursive}" == "x1" ] ; then
        echo "INFO: force do recursive submodule"
        rcsopts="--recursive"
    fi
    git submodule sync $rcsopts
    git submodule update -f --init ${rcsopts} ${otheropts} ${gitopts}
}

function init_toolchain_repo() {
    local retcode=0
    if [ ! -d $toolsrcdir ] ; then
        git_clone_repo ${toolchain_repo} ${toolsrcdir} ${toolchain_branch}
    else
        echo "INFO: toolchain source code ${toolsrcdir} already exist!"
    fi
    toolsrcdir=$(readlink -f $toolsrcdir)
    pushd $toolsrcdir
    if [ ! -d $toolsrcdir/.git ] ; then
        echo "WARN: Toolchain source directory is not a git repo, will not update submodule!"
    else
        local gitsubmodulestatus=$(git submodule foreach git status | grep Enter)
        if [ "x$gitsubmodulestatus" == "x" ] || [ "x${force_submodule}" == "x1" ] ; then
            echo "INFO: initialize submodule for riscv toolchain"
            # don't do recursive update submodule, especially for qemu
            git_submodule_update
        else
            echo "NOTICE: submodule repo is already initialized, will not update it!"
        fi
        show_repo_status
        if ! check_submodule ; then
            retcode=1
        fi
    fi
    popd
    return $retcode
}

function check_gito() {
    if ssh -T $gitosrv ; then
        echo "INFO: You have access to gito server!"
        return 0
    else
        echo "WARN: You don't have access to gito server, will not clone libncrt source code"
        return 1
    fi
}

function clone_libncrt() {
    local retcode=0
    echo "INFO: Clone nuclei c runtime library source code to libncrt"
    git_clone_repo ${libncrt_repo} ${toolsrcdir}/libncrt ${libncrt_branch}

    pushd $toolsrcdir/libncrt
    git_submodule_update
    show_repo_status
    if ! check_submodule ; then
        retcode=1
    fi
    popd
    return $retcode
}

function init_libncrt_repo() {
    if [ -d $toolsrcdir/libncrt ] ; then
        echo "INFO: libncrt source code already exist!"
        return 0
    fi
    if check_gito ; then
        clone_libncrt
        return $?
    else
        echo "No access right to libncrt source code!"
        return 0
    fi
}

echo "INFO: Prepare riscv toolchain source code"
retcode=0
if ! init_toolchain_repo ; then
    echo "Toolchain repo is not ready for use!"
    retcode=1
fi
if ! init_libncrt_repo ; then
    echo "Libncrt repo is not ready for use!"
    retcode=1
fi

if [ "$retcode" == "0" ] ; then
    echo "INFO: Toolchain source code is ready in $toolsrcdir"
else
    echo "ERROR: Toolchain source code is not ready in $toolsrcdir"
fi
exit $retcode
