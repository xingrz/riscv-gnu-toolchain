#!/usr/bin/env bash

SCRIPTDIR=$(dirname $(readlink -f $BASH_SOURCE))
SCRIPTDIR=$(readlink -f $SCRIPTDIR)

tooltype=${TOOLTYPE:-}
toolhost=${TOOLHOST:-}
toolver=${TOOLVER:-}
vendor=${TOOLVENDOR:-nuclei}
dorebuild=${DOREBUILD:-}
dorelease=${DORELEASE:-}

# toolchain source directory
toolsrcdir=$(readlink -f $SCRIPTDIR/../..)
# BUILDDATE is used to set toolver when TOOLVER is not specified
builddate=${BUILDDATE:-$(date -u +%Y%m%d)}
# If you want to fix the build directory name, you can set BUILDTAG variable
buildtag=${BUILDTAG:-$(date -u +%Y%m%d_%H%M%S)}
TOOLNAME=gcc

# share toolchain location for nuclei server to access
ShareLoc=${SHARELOC:-/home/share/devtools/toolchain/nuclei_gnu}

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
    if [ "x$dorelease" != "x1" ] ; then
        if cat /etc/issue | grep -i ubuntu ; then
            toolhost="win32"
        else
            toolhost="linux64"
        fi
    else
        toolhost="linux64"
    fi
fi

if [[ "$CI_PIPELINE_ID" =~ ^[0-9]+$ ]] ; then
    workroot=/Local/gitlab-runner/work
    if [ ! -d $workroot ] ; then
        echo "INFO: Maybe in docker environment now!"
        workroot=/work
    fi
    LocalBuilds=$workroot/toolchain/builds
    LocalInstalls=$workroot/toolchain/install
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
LocalLinInstalls=${LocalInstalls}/linux64/${tooltype}
ShareInstalls=${ShareLoc}/${toolhost}/${tooltype}

tooltag=${toolhost}_${tooltype}
savebldenv=$(pwd)/lastbuild_${tooltag}.env
if [ "x$dorebuild" == "x1" ] ; then
    if [ ! -f $savebldenv ] ; then
        echo "ERROR: Could not find last build save variable file $savebldenv, please check!"
        exit 1
    fi
    echo "INFO: Source last build environment file $savebldenv"
    set -a
    source $savebldenv
    set +a
    if [ "x$toolprefix" == "x" ] || [ "x$toolbuilddir" == "x" ] ; then
        echo "ERROR: toolprefix or toolbuilddir is not provided in $savebldenv, please check!"
        exit 1
    fi
    if [ ! -f $toolbuilddir/Makefile ] ; then
        echo "ERROR: There is no Makefile in $toolbuilddir, please check!"
        exit 1
    fi
else
    if [ "x${CI_JOB_ID}" != "x" ] ; then
        toolbuildtag=pipeline${CI_PIPELINE_ID}_job${CI_JOB_ID}
    else
        toolbuildtag=$buildtag
    fi
    if [ "x$toolver" != "x" ] ; then
        toolver=$toolver
    elif [ "x${CI_JOB_ID}" != "x" ] ; then
        toolver=pipeline${CI_PIPELINE_ID}
    else
        toolver=$builddate
    fi
    builddirname=${toolver}_${tooltag}_${toolbuildtag}
    toolprefix=$LocalInstalls/${toolver}/$TOOLNAME
    lintoolprefix=$LocalLinInstalls/${toolver}/${TOOLNAME}
    toolbuilddir=$LocalBuilds/${builddirname}
    # only save environment when no do release
    if [ "x$dorelease" != "x1" ] ; then
        echo "INFO: Save build prefix and build directory environment variable to $savebldenv"
        echo "toolprefix=${toolprefix}" > $savebldenv
        echo "toolbuilddir=${toolbuilddir}" >> $savebldenv
        echo "toolver=${toolver}" >> $savebldenv
        echo "lintoolprefix=${lintoolprefix}" >> $savebldenv
        echo "builddirname=${builddirname}" >> $savebldenv
        echo "toolbuildtag=${toolbuildtag}" >> $savebldenv
    fi
fi
toolbasedir="${toolprefix}/.."

function prepare_buildenv() {
    if [ "x$toolhost" == "xwin32" ] ; then
        echo "INFO: Add prebuilt linux host riscv toolchain $lintoolprefix into PATH"
        export PATH=$lintoolprefix/bin:$PATH
    fi
}

function describe_repo() {
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

function describe_build() {
    local builddesc=${1:-build.txt}

    date --utc +%s > ${builddesc}
    date >> ${builddesc}
}

function cleanup_build() {
    local cleaninstall=${1:-}
    local dir2rm=$LocalBuilds/${toolver}_${tooltag}_*
    echo "INFO: Remove all build related directories for $toolver, ${toolhost}, ${tooltype} in $dir2rm"
    rm -rf $dir2rm
    local tooldir=$(readlink -f $toolbasedir)
    if [ "x$tooldir" != "x" ] && [ "x$cleaninstall" == "x1" ] ; then
        echo "INFO: Remove all installed toolchain for $toolver in $tooldir"
        rm -rf $tooldir
    else
        echo "INFO: Will not remove installed toolchain for $toolver in $tooldir"
    fi
    return 0
}

function gitarchive() {
    local repotgz=$1
    if which git-archive-all > /dev/null 2>&1 ; then
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

    pushd $(dirname $tooldir)
    echo "Archive toolchain in $tooldir to $toolname.zip"
    command rm -f ${toolname}.zip
    zip -9 -q -r ${toolname}.zip $(basename $tooldir)
    popd
}

function archive_toolchain() {
    local tooldir=${toolprefix}
    local basedir=$(readlink -f ${toolbasedir})
    local toolname=$basedir/${vendor}_riscv_${tooltype}_prebuilt_${toolhost}_$(basename $basedir)

    if [ "x$toolhost" == "xwin32" ] ; then
        zip_toolchain $tooldir $toolname
    else
        tar_toolchain $tooldir $toolname
    fi
}

function show_toolchain() {
    local basedir=$(readlink -f ${toolbasedir})

    echo "INFO: Show installed toolchain content."
    ls -lh ${basedir}
}

function sync_toolchain() {
    local localinstall=${1:-${toolbasedir}}
    local symlink=${2:-}
    if [ ! -d ${localinstall} ] ; then
        echo "ERROR: local toolchain directory ${localinstall} not exist!"
        return 1
    else
        localinstall=$(readlink -f $localinstall)
    fi

    if [ ! -d ${ShareLoc} ] ; then
        echo "ERROR: $ShareLoc directory not exist, maybe you are in docker environment!"
        return 1
    fi

    if [ ! -d ${ShareInstalls} ] ; then
        echo "INFO: Create share toolchain install directory ${ShareInstalls}"
        mkdir -p ${ShareInstalls}
    fi
    local basedir=$(basename ${localinstall})
    if [ -d ${ShareInstalls}/${basedir} ] ; then
        echo "INFO: Removing existing ${ShareInstalls}/${basedir}"
        rm -rf ${ShareInstalls}/${basedir}
    fi
    echo "INFO: Copy $localinstall to $ShareInstalls"
    command cp -rf ${localinstall} ${ShareInstalls}
    echo "INFO: Toolchain copied to ${ShareInstalls}/${basedir}"
    if [ "x$symlink" != "x" ] ; then
        pushd ${ShareInstalls}
        echo "INFO: Symbolic link from ${basedir} -> ${symlink} in ${ShareInstalls}"
        rm -f $symlink
        command ln -sf $basedir $symlink
        popd
    fi
    return 0
}
