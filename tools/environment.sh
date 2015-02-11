#!/bin/bash

if [ "X$VERBOSE" == "X1" ]; then
	set -x
fi

try () {
	"$@" || exit -1
}

# iOS SDK Environmnent (don't use name "SDKROOT"!!! it will break the compilation)

export SDKVER=`xcodebuild -showsdks | fgrep "iphoneos" | tail -n 1 | awk '{print $2}'`
# will return the latest iphoneos version, here e.g. "7.1"
export DEVROOT=`xcode-select -print-path`/Platforms/iPhoneOS.platform/Developer
# path relative to root, by default "/Applications/Xcode.app/Contents/Developer", and appends the path to the DEVROOT as seen
export IOSSDKROOT=$DEVROOT/SDKs/iPhoneOS$SDKVER.sdk
# path to the wanted iOS SDK folder.. here in Xcode 5.1.1 the only dir in $DEVROOT/SDKs/

# Xcode doesn't include /usr/local/bin
export PATH="$PATH":/usr/local/bin

if [ ! -d $DEVROOT ]; then
	echo "Unable to found the Xcode iPhoneOS.platform"
	echo
	echo "The path is automatically set from 'xcode-select -print-path'"
	echo " + /Platforms/iPhoneOS.platform/Developer"
	echo
	echo "Ensure 'xcode-select -print-path' is set."
	exit 1
fi

# version of packages
export IOS_PYTHON_VERSION=2.7.1
export SDLTTF_VERSION=2.0.10
export FT_VERSION=2.4.8
export XML2_VERSION=2.7.8
export XSLT_VERSION=1.1.26
export LXML_VERSION=2.3.1
export FFI_VERSION=3.0.13
export NUMPY_VERSION=1.9.1

# where the build will be located
export KIVYIOSROOT="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
export BUILDROOT="$KIVYIOSROOT/build"
export TMPROOT="$KIVYIOSROOT/tmp"
export DESTROOT="$KIVYIOSROOT/tmp/root"
export CACHEROOT="$KIVYIOSROOT/.cache"
export DISTROOT="$KIVYIOSROOT/dist"

# pkg-config for SDL and futures
try mkdir -p $BUILDROOT/pkgconfig
export PKG_CONFIG_PATH="$BUILDROOT/pkgconfig:$PKG_CONFIG_PATH"

# some tools
export CCACHE=$(which ccache)
export HOSTPYTHON="$DISTROOT/hostpython/bin/python"
for fn in cython-2.7 cython; do
	export CYTHON=$(which $fn)
	if [ "X$CYTHON" != "X" ]; then
		break
	fi
done
if [ "X$CYTHON" == "X" ]; then
	echo
	echo "Cython not found !"
	echo "Ensure your PATH contain access to 'cython' or 'cython-2.7'"
	echo
	echo "Current PATH: $PATH"
	echo
fi

# check basic tools
CONFIGURATION_OK=1
for tool in pkg-config autoconf automake libtool hg; do
	if [ "X$(which $tool)" == "X" ]; then
		echo "Missing requirement: $tool is not installed !"
		CONFIGURATION_OK=0
	fi
done
if [ $CONFIGURATION_OK -eq 0 ]; then
	echo "Install thoses requirements first, then restart the script."
	exit 1
fi


# flags for arm compilation
#export ARM_CC="$CCACHE $DEVROOT/usr/bin/arm-apple-darwin10-llvm-gcc-4.2"
#export ARM_AR="$DEVROOT/usr/bin/ar"
#export ARM_LD="$DEVROOT/usr/bin/ld"
export ARM_CC=$(xcrun -find -sdk iphoneos clang)
export ARM_AR=$(xcrun -find -sdk iphoneos ar)
export ARM_LD=$(xcrun -find -sdk iphoneos ld)

export ARM_CFLAGS="-arch armv7"
export ARM_CFLAGS="$ARM_CFLAGS -pipe -no-cpp-precomp"
export ARM_CFLAGS="$ARM_CFLAGS -isysroot $IOSSDKROOT"
export ARM_CFLAGS="$ARM_CFLAGS -miphoneos-version-min=$SDKVER"
export ARM_LDFLAGS="-arch armv7 -isysroot $IOSSDKROOT"
export ARM_LDFLAGS="$ARM_LDFLAGS -miphoneos-version-min=$SDKVER"

# uncomment this line if you want debugging stuff
export ARM_CFLAGS="$ARM_CFLAGS -O3"
#export ARM_CFLAGS="$ARM_CFLAGS -O0 -g"

# ensure byte-compiling is working
export PYTHONDONTWRITEBYTECODE=

# ensure that no current flags in the user env will be used
unset ARCHFLAGS
unset CFLAGS
unset LDFLAGS

# create build directory if not found
try mkdir -p $BUILDROOT
try mkdir -p $BUILDROOT/include
try mkdir -p $BUILDROOT/lib
try mkdir -p $CACHEROOT
try mkdir -p $TMPROOT
try mkdir -p $DESTROOT

# one method to deduplicate some symbol in libraries
function deduplicate() {
	fn=$(basename $1)
	echo "== Trying to remove duplicate symbol in $1"
	try mkdir ddp
	try cd ddp
	for var in "$@"; do
		echo "  - extracting $var"
		try ar x $var
	done
	echo "  - create the archive"
	try ar rc $fn *.o
	echo "  - finalize the archive"
	try ranlib $fn
	try mv -f $fn $1
	try cd ..
	try rm -rf ddp
	echo "  - done: $1 updated"
}
