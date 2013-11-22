#!/bin/sh
set -e

info()
{
    local green="\033[1;32m"
    local normal="\033[0m"
    echo "[${green}build${normal}] $1"
}

spushd()
{
    pushd "$1" > /dev/null
}

spopd()
{
    popd > /dev/null
}

#out="/dev/null"

npapiroot=`dirname $0`/../..
INTEL32ROOT="${npapiroot}/i686-build/VLC Plugin.plugin"
INTEL64ROOT="${npapiroot}/x86_64-build/VLC Plugin.plugin"
UBROOT="${npapiroot}/VLC Plugin.plugin"

info "checking for libvlc"

spushd ${npapiroot}/extras/macosx
if [ ! -e "vlc" ]; then
    info "vlc wasn't checked out, bailing out"
    exit -1
fi

if [ ! -e "vlc/64bit_install_dir" ]; then
    info "libvlc wasn't compiled for 64bit, bailing out"
    exit -1
fi

#if [ ! -e "vlc/32bit_install_dir" ]; then
#    info "libvlc wasn't compiled for 32bit, bailing out"
#    exit -1
#fi
spopd

spushd ${npapiroot}

if [ ! -e "${INTEL64ROOT}" ]; then
info "compiling x86_64 binary"
./extras/macosx/build-plugin.sh -a x86_64
fi

if [ ! -e "${INTEL32ROOT}" ]; then
info "compiling i686 binary"
./extras/macosx/build-plugin.sh -a i686
fi

info "Creating Universal Binary"
rm -Rf "$UBROOT"
cp -Rf "$INTEL64ROOT" "$UBROOT"

LIBS=Contents/MacOS/lib
PLUGINS=Contents/MacOS/plugins
rm -Rf $UBROOT/$LIBS/*
rm -Rf "$UBROOT/Contents/MacOS/VLC Plugin"
rm -Rf $UBROOT/$PLUGINS/*

function do_lipo {
    file="$1"
    files=""
    echo "..."$file
    if [ "x$INTEL32ROOT" != "x" ]; then
        if [ -e "$INTEL32ROOT/$file" ]; then
            files="$INTEL32ROOT/$file $files"
        fi
    fi
    if [ "x$INTEL64ROOT" != "x" ]; then
        if [ -e "$INTEL64ROOT/$file" ]; then
            files="$INTEL64ROOT/$file $files"
        fi
    fi
    if [ "x$files" != "x" ]; then
        lipo $files -create -output $UBROOT/$file
    fi;
}

info "Installing libs"
for i in `ls $INTEL32ROOT/$LIBS/ | grep .dylib`
do
    do_lipo $LIBS/$i
done

info "Installing modules"
for i in `ls $INTEL32ROOT/$PLUGINS/ | grep .dylib`
do
    do_lipo $PLUGINS/$i
done

info "Installing VLC Plugin"
do_lipo "Contents/MacOS/VLC\ Plugin"

info "Installing Extra modules"

if [ "x$INTEL32ROOT" != "x" ]; then
    cp "$INTELROOT/$PLUGINS/"*mmx* "$UBROOT/$PLUGINS/"
    cp "$INTELROOT/$PLUGINS/"*3dn* "$UBROOT/$PLUGINS/"
fi
if [ "x$INTEL64ROOT" != "x" ]; then
    cp -f "$INTEL64ROOT/$PLUGINS/"*sse* "$UBROOT/$PLUGINS/"
fi

info "Creation succeeded"
