#!/bin/sh

set -e

usage()
{
cat << EOF
usage: $0 [-v] [-d]

OPTIONS
   -v       Be more verbose
   -d       Enable Debug
EOF
}

spushd()
{
     pushd "$1" 2>&1> /dev/null
}

spopd()
{
     popd 2>&1> /dev/null
}

info()
{
     local green="\033[1;32m"
     local normal="\033[0m"
     echo "[${green}info${normal}] $1"
}

while getopts "hvsdk:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             VERBOSE=yes
             ;;
         d)  CONFIGURATION="--enable-debug"
             ;;
         ?)
             usage
             exit 1
             ;;
     esac
done
shift $(($OPTIND - 1))

out="/dev/null"
if [ "$VERBOSE" = "yes" ]; then
   out="/dev/stdout"
fi

if [ "x$1" != "x" ]; then
    usage
    exit 1
fi

# Get root dir
spushd .
npapi_root_dir=`pwd`
spopd

info $npapi_root_dir

info "Preparing build dirs"

spushd extras/macosx

if ! [ -e vlc ]; then
git clone git://git.videolan.org/vlc/vlc-2.0.git vlc
fi

spopd #extras/macosx

#
# Build time
#

info "Building tools"
spushd extras/macosx/vlc/extras/tools
if ! [ -e build ]; then
./bootstrap && make
fi
spopd

info "Fetching contrib"

spushd extras/macosx/vlc/contrib

if ! [ -e 64bit-npapi ]; then
mkdir 64bit-npapi
cd 64bit-npapi
../bootstrap --build=x86_64-apple-darwin10
make prebuilt
fi

spopd

export CC="xcrun clang"
export CXX="xcrun clang++"
export OBJC="xcrun clang"
PREFIX="${npapi_root_dir}/extras/macosx/vlc/64bit_install_dir"

info "Configuring VLC"

if ! [ -e ${PREFIX} ]; then
    mkdir ${PREFIX}
fi

spushd extras/macosx/vlc
if ! [ -e configure ]; then
    ./bootstrap > ${out}
fi
if ! [ -e 64build ]; then
    mkdir 64build
fi
cd 64build
../configure \
        --build=x86_64-apple-darwin10 \
        --disable-lua --disable-httpd --disable-vlm --disable-sout \
        --disable-vcd --disable-dvdnav --disable-dvdread --disable-screen \
        --disable-macosx \
        --enable-merge-ffmpeg \
        --disable-growl \
        --enable-minimal-macosx \
        --enable-faad \
        --enable-flac \
        --enable-theora \
        --enable-shout \
        --enable-ncurses \
        --enable-twolame \
        --enable-realrtsp \
        --enable-libass \
        --enable-macosx-audio \
        --disable-macosx-eyetv \
        --disable-macosx-qtkit \
        --enable-macosx-vout \
        --disable-skins2 \
        --disable-xcb \
        --disable-caca \
        --disable-sdl \
        --disable-samplerate \
        --disable-upnp \
        --disable-goom \
        --disable-macosx-dialog-provider \
        --disable-nls \
        --disable-sdl \
        --disable-sdl-image \
        --disable-macosx-vlc-app \
	--with-macosx-sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.6.sdk \
        --with-macosx-version-min=10.6 \
        --prefix=${PREFIX} > ${out}

info "Compiling VLC"

CORE_COUNT=`sysctl -n machdep.cpu.core_count`
let MAKE_JOBS=$CORE_COUNT+1

if [ "$VERBOSE" = "yes" ]; then
    make V=1 -j$MAKE_JOBS > ${out}
else
    make -j$MAKE_JOBS > ${out}
fi

info "Installing VLC"
make install > ${out}
cd ..

find ${PREFIX}/lib/vlc/plugins -name *.dylib -type f -exec cp '{}' ${PREFIX}/lib/vlc/plugins \;

info "Removing unneeded modules"
blacklist="
stats
access_bd
shm
access_imem
oldrc
real
hotkeys
gestures
sap
dynamicoverlay
rss
ball
magnify
audiobargraph_
clone
mosaic
osdmenu
puzzle
mediadirs
t140
ripple
motion
sharpen
grain
posterize
mirror
wall
scene
blendbench
psychedelic
alphamask
netsync
audioscrobbler
motiondetect
motionblur
export
smf
podcast
bluescreen
erase
stream_filter_record
speex_resampler
remoteosd
magnify
gradient
logger
visual
fb
aout_file
yuv
dummy
invert
sepia
wave
hqdn3d
headphone_channel_mixer
gaussianblur
gradfun
extract
colorthres
antiflicker
anaglyph
remap
bluray
"

for i in ${blacklist}
do
    find ${PREFIX}/lib/vlc/plugins -name *$i* -type f -exec rm '{}' \;
done

spopd

info "Build completed"
