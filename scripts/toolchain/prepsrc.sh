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
    echo "INFO: Init and update repo $(basename $(pwd)) submodule"
    git submodule sync --recursive
    git submodule update --init --recursive ${gitopts}
}

function init_toolchain_repo() {
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
            git_submodule_update
        else
            echo "NOTICE: submodule repo is already initialized, will not update it!"
        fi
        show_repo_status
    fi
    popd
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
    echo "INFO: Clone nuclei c runtime library source code to libncrt"
    git_clone_repo ${libncrt_repo} ${toolsrcdir}/libncrt ${libncrt_branch}

    pushd $toolsrcdir/libncrt
    git_submodule_update
    show_repo_status
    popd
}

function init_libncrt_repo() {
    if [ -d $toolsrcdir/libncrt ] ; then
        echo "INFO: libncrt source code already exist!"
        return 0
    fi
    if check_gito ; then
        clone_libncrt
        return 0
    else
        return 1
    fi
}

echo "INFO: Prepare riscv toolchain source code"
init_toolchain_repo
init_libncrt_repo

echo "INFO: Toolchain source code is ready in $toolsrcdir"
exit 0
