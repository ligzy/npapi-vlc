#!/bin/sh
set -e

info()
{
    local green="\033[1;32m"
    local normal="\033[0m"
    echo "[${green}build${normal}] $1"
}

OSX_VERSION="10.8"
ARCH="x86_64"
MINIMAL_OSX_VERSION="10.6"
SDKROOT=`xcode-select -print-path`/Platforms/MacOSX.platform/Developer/SDKs/MacOSX$OSX_VERSION.sdk

usage()
{
cat << EOF
usage: $0 [-v] [-d]

OPTIONS
   -v            Be more verbose
   -k <sdk>      Use the specified sdk (default: $SDKROOT for $ARCH)
   -a <arch>     Use the specified arch (default: $ARCH)
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

while getopts "hva:k:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             VERBOSE=yes
             ;;
         a)
             ARCH=$OPTARG
             ;;
         k)
             SDKROOT=$OPTARG
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

if [ "$ARCH" = "i686" ]; then
    MINIMAL_OSX_VERSION="10.5"
fi

export OSX_VERSION
export SDKROOT

# Get root dir
spushd .
npapi_root_dir=`pwd`
spopd

info $npapi_root_dir

info "Preparing build dirs"

spushd extras/macosx

if ! [ -e vlc ]; then
git clone git://git.videolan.org/vlc.git vlc
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

if ! [ -e ${ARCH}-npapi ]; then
mkdir ${ARCH}-npapi
cd ${ARCH}-npapi
../bootstrap --build=${ARCH}-apple-darwin10 --disable-disc \
 --disable-sout --disable-gpl --disable-sdl --disable-sparkle \
 --disable-bghudappkit --disable-growl --disable-goom \
 --disable-SDL_image --disable-lua --disable-chromaprint \
 --disable-caca --disable-upnp --disable-vncserver \
 --disable-ncurses
make fetch
make .gettext && make
fi

spopd

export CC="xcrun clang"
export CXX="xcrun clang++"
export OBJC="xcrun clang"
PREFIX="${npapi_root_dir}/extras/macosx/vlc/${ARCH}-install"

info "Configuring VLC"

if ! [ -e ${PREFIX} ]; then
    mkdir ${PREFIX}
fi

spushd extras/macosx/vlc
if ! [ -e configure ]; then
    ./bootstrap > ${out}
fi
if ! [ -e ${ARCH}-build ]; then
    mkdir ${ARCH}-build
fi

CONFIG_OPTIONS=""
if [ "$ARCH" = "i686" ]; then
    CONFIG_OPTIONS="--disable-vda"
    export LDFLAGS="-Wl,-read_only_relocs,suppress"
fi

cd ${ARCH}-build
../configure \
        --build=${ARCH}-apple-darwin10 \
        --disable-lua --disable-httpd --disable-vlm --disable-sout \
        --disable-vcd --disable-dvdnav --disable-dvdread --disable-screen \
        --disable-debug \
        --disable-macosx \
        --disable-notify \
        --disable-projectm \
        --enable-merge-ffmpeg \
        --disable-growl \
        --disable-faad \
        --disable-bluray \
        --enable-flac \
        --enable-theora \
        --enable-shout \
        --disable-ncurses \
        --disable-twolame \
        --disable-a52 \
        --enable-realrtsp \
        --enable-libass \
        --enable-macosx-audio \
        --disable-macosx-avfoundation \
        --disable-macosx-dialog-provider \
        --disable-macosx-eyetv \
        --disable-macosx-qtkit \
        --disable-macosx-quartztext \
        --disable-macosx-vlc-app \
        --enable-macosx-vout \
        --disable-skins2 \
        --disable-xcb \
        --disable-caca \
        --disable-sdl \
        --disable-samplerate \
        --disable-upnp \
        --disable-goom \
        --disable-nls \
        --disable-mad \
        --disable-sdl \
        --disable-sdl-image \
        --enable-coregraphicslayer-vout \
        --with-macosx-sdk=$SDKROOT \
        --with-macosx-version-min=${MINIMAL_OSX_VERSION} \
        ${CONFIG_OPTIONS} \
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
"

for i in ${blacklist}
do
    find ${PREFIX}/lib/vlc/plugins -name *$i* -type f -exec rm '{}' \;
done

spopd

info "Build completed"
