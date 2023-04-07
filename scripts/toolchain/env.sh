#!/usr/bin/env bash

SCRIPTDIR=$(dirname $(readlink -f $BASH_SOURCE))
SCRIPTDIR=$(readlink -f $SCRIPTDIR)

tooltype=${TOOLTYPE:-}
toolhost=${TOOLHOST:-}
toolver=${TOOLVER:-}
vendor=${TOOLVENDOR:-nuclei}

# toolchain source directory
toolsrcdir=$(readlink -f $SCRIPTDIR/../..)
BUILDDATE=${BUILDDATE:-$(date -u +%Y%m%d_%H%M%S)}
TOOLNAME=gcc

maketarget="newlib"
if [ "$tooltype" == "xnewlibc" ] ; then
    maketarget="newlib"
elif [ "x$tooltype" == "xglibc" ] ; then
    maketarget="linux"
else
    tooltype="newlibc"
    maketarget="newlib"
fi

if [ "x$toolhost" != "xwin32" ] && [ "x$toolhost" != "xlinux64" ] ; then
    if cat /etc/issue | grep -i ubuntu ; then
        toolhost="win32"
    else
        toolhost="linux64"
    fi
fi

if [[ "$CI_PIPELINE_ID" =~ ^[0-9]+$ ]] ; then
    LocalBuilds=/work/toolchain/builds
    LocalInstalls=/work/toolchain/install
    if [ "x$doclean" == "x" ] ; then
        echo "Do clean build folder when sucessfully built"
        doclean=1
    fi
else
    LocalBuilds=$toolsrcdir/LocalBuilds
    LocalInstalls=$toolsrcdir/LocalInstall
    if [ "x$doclean" == "x" ] ; then
        echo "Don't clean build folder when sucessfully built"
        doclean=0
    fi
fi

LocalInstalls=${LocalInstalls}/${toolhost}/${tooltype}

if [ "x$toolver" != "x" ] ; then
    toolprefix=$LocalInstalls/$toolver/$TOOLNAME
    toolbuilddir=$LocalBuilds/${toolver}_$BUILDDATE
elif [ "x${CI_JOB_ID}" != "x" ] ; then
    toolprefix=$LocalInstalls/job${CI_JOB_ID}/$TOOLNAME
    toolbuilddir=$LocalBuilds/job${CI_JOB_ID}
else
    toolprefix=$LocalInstalls/$BUILDDATE/$TOOLNAME
    toolbuilddir=$LocalBuilds/$BUILDDATE
fi
toolbasedir="${toolprefix}/../"

function describe_repo {
    local repodir=${1}
    local repodesc=${2:-gitrepo.txt}

    if [ -d ${repodir}/.git ] ; then
        pushd ${repodir}
        echo "toolchain repo commit: $(git describe --always --abbrev=10 --dirty)" > ${repodesc}
        git log --oneline -1 >> ${repodesc}
        git submodule >> ${repodesc}
        if [ -d ${repodir}/libncrt/.git ] ; then
            pushd libncrt
            echo "libncrt repo commit: $(git describe --always --abbrev=10 --dirty)" >> ${repodesc}
            git log --oneline -1 >> ${repodesc}
            popd
        fi
        popd
    else
        echo "not a git repo" > ${repodesc}
    fi
}

function describe_build {
    local builddesc=${1:-build.txt}

    date --utc +%s > ${builddesc}
    date >> ${builddesc}
}

function gitarchive() {
    local repotgz=$1
    if which git-archive-all ; then
        git-archive-all ${repotgz}
    else
        git ls-files --recurse-submodules | tar --quoting-style=locale -czf ${repotgz} -T-
    fi
}

function archive_gitrepo() {
    local repodir=${1:-${toolsrcdir}}
    local repotgz=${2:-${toolbasedir}/source.tar.gz}
    if [ -d ${repodir}/.git ] ; then
        pushd ${repodir}
        command rm -f ${repotgz}
        echo "Archive source code to ${repotgz}"
        gitarchive $repotgz
        popd
    else
        echo "Not a git repo"
    fi
}

# TODO: need to check build is pass or fail
function build_libncrt() {
    local repodir=${1:-$toolsrcdir/libncrt}
    local bldcfg=${2:-riscv64-unknown-elf}
    local libncrtczf=${3}

    if [ -d $repodir ] ; then
        pushd $repodir
        echo "Clean previous build for libncrt"
        rm -rf build out
        echo "Build libncrt for conf $bldcfg, library generated into out, build objects into build"
        rake conf=$bldcfg build_dir="build" out_dir="out"
        if [ "x$libncrtczf" != "x" ] ; then
            libncrtdir=$(dirname $libncrtczf)
            mkdir -p $libncrtdir
            command rm -f $libncrtczf
            tar --owner=0 --group=0 --numeric-owner --transform "s/^out/libncrt/" -czf $libncrtczf out
        fi
        echo "Install libncrt library into desired toolchain folder"
        rake conf=$bldcfg build_dir="build" out_dir="out" install
        popd
    else
        echo "WARN: libncrt repo $repodir not exist!"
    fi
}

function install_libncrt_doc() {
    local repodir=${1:-$toolsrcdir/libncrt}
    local dstdir=${2:-$toolprefix/share/pdf}

    mkdir -p $dstdir

    echo "Install libncrt doc into $dstdir"
    command cp -f $repodir/doc/*.pdf $dstdir
}

function tar_toolchain() {
    local tooldir=$1

    if [ ! -d "$tooldir/bin" ] ; then
        echo "Prebuilt toolchain doesn't exist in $tooldir!"
        return
    fi
    local toolname=${2:-$(basename $tooldir)}
    echo "Archive toolchain in $tooldir to $toolname.tar.bz2"

    command rm -f ${toolname}.tar.bz2
    tar -jcf ${toolname}.tar.bz2 -C $(dirname $tooldir) $(basename $tooldir)
}

function zip_toolchain() {
    local tooldir=$1

    if [ ! -d "$tooldir/bin" ] ; then
        echo "Prebuilt toolchain doesn't exist in $tooldir!"
        return
    fi
    local toolname=${2:-$(basename $tooldir)}

    echo "Archive toolchain in $tooldir to $toolname.zip"

    pushd $(dirname $tooldir)
    command rm -f ${toolname}.zip
    zip -9 -q -r ${toolname}.zip $(basename $tooldir)
    popd
}

function archive_toolchain() {
    local tooldir=${toolprefix}
    local basedir=${toolbasedir}
    local toolname=$basedir/${vendor}_riscv_${tooltype}_prebuilt_${toolhost}_$(basename $basedir)

    if [ "x$toolhost" == "xwin32" ] ; then
        zip_toolchain $tooldir $toolname
    else
        tar_toolchain $tooldir $toolname
    fi
}
