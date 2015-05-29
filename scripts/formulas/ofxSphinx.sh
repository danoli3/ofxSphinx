#! /bin/bash
#
# Sphinx

# Important. This script requires some external make dependancies that need you can use homebrew to install.
# ---- See http://brew.sh to install
# depends on:
#   brew install autoconf
#   brew install automake
#
# uses a CMake build system
 
FORMULA_TYPES=( "osx" "ios" )

CSTANDARD=c11 # c89 | c99 | c11 | gnu11
COMPILER_TYPE=clang # clang, gcc
SCRATCH="scratch"

 
# define the version
VER=master
 
# tools for git use
GIT_URL=https://github.com/cmusphinx/sphinxbase
GIT_TAG=$VER

GIT_URL_POCKET=https://github.com/cmusphinx/pocketsphinx
GIT_TAG_POCKET=$VER

 
# download the source code and unpack it into LIB_NAME
function download() {

  mkdir -p ofxSphinx
  
  curl -Lk https://github.com/cmusphinx/sphinxbase/archive/$VER.tar.gz -o sphinxbase-$VER.tar.gz
  tar -xf sphinxbase-$VER.tar.gz
  mv sphinxbase-$VER sphinxbase
  mv sphinxbase ofxSphinx/
  rm sphinxbase*.tar.gz

  curl -Lk https://github.com/cmusphinx/pocketsphinx/archive/$VER.tar.gz -o pocketsphinx-$VER.tar.gz
  tar -xf pocketsphinx-$VER.tar.gz
  mkdir -p ofxSphinx/pocketsphinx
  mv pocketsphinx-$VER pocketsphinx
  mv pocketsphinx ofxSphinx/
  rm pocketsphinx*.tar.gz
}
 
# prepare the build environment, executed inside the lib src dir
function prepare() {
  : # noop

  echo "Important. This script requires some external make dependancies that need you can use homebrew to install."
  echo " ---- See http://brew.sh to install homebrew on osx"
  echo "This script depends on:"
  echo "---- brew install autoconf"
  echo "---- brew install automake"
}

function build() {
  
  if [ "$TYPE" == "osx" ] ; then
    echo "not implemented"
  elif [ "$TYPE" == "ios" ] ; then

    # This was quite helpful as a reference: https://github.com/x2on/OpenSSL-for-iPhone
    # Refer to the other script if anything drastic changes for future versions
    SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version` 
    set -e
    CURRENT=`pwd`
    
    DEVELOPER=$XCODE_DEV_ROOT
    TOOLCHAIN=${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain
    VERSION=$VER

    local IOS_ARCHS="i386 x86_64 armv7 arm64" #armv7s
    local SPHINX_TYPES="sphinxbase pocketsphinx"
    local STDLIB="libc++"


    # Validate environment
    case $XCODE_DEV_ROOT in  
         *\ * )
               echo "Your Xcode path contains whitespaces, which is not supported."
               exit 1
              ;;
    esac


    case $CURRENT in  
         *\ * )
               echo "Your path contains whitespaces, which is not supported by 'make install'."
               exit 1
              ;;
    esac 

    for SPHINX_TYPE in ${SPHINX_TYPES}
    do
        
        CURRENTPATH=`pwd`
        CURRENTPATH="$CURRENTPATH/$SPHINX_TYPE"
        cd $CURRENTPATH

        echo "First Run... Run Autogen"
        echo "Current Path: $CURRENTPATH"

        echo "Autogen.sh"
        echo "------------------------"
        ./autogen.sh
        echo "Finished Autogen.sh"
        echo "------------------------"
        make distclean
        echo "Finished `make distclean`"
        echo "------------------------"


        DEST=`pwd`/"bin"

        # loop through architectures! yay for loops!
        for IOS_ARCH in ${IOS_ARCHS}
        do
          # make sure backed up

          if [ "${COMPILER_TYPE}" == "clang" ]; then
            export THECOMPILER=$TOOLCHAIN/usr/bin/clang
          else
            export THECOMPILER=`xcrun -find gcc`
          fi
          echo "The compiler: $THECOMPILER"

          if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]];
          then
            PLATFORM="iPhoneSimulator"
          else
           PLATFORM="iPhoneOS"
          fi

          export DEVELOPER=`xcode-select --print-path`
          export DEVROOT="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
          export SDKROOT="${DEVROOT}/SDKs/${PLATFORM}.sdk"
          
          echo "Cleaning first"
          # CONFIG_DISTCLEAN_FILES=""
          rm -f config.status config.cache config.log configure.lineno config.status.lineno
          rm -f Makefile

          mkdir -p "$SCRATCH/$IOS_ARCH"
          SPHINXBASE_DIR="$CURRENTPATH/../sphinxbase/bin/$IOS_ARCH"
          echo "--------------------------"
          echo "SPHINXBASE_DIR is $SPHINXBASE_DIR"
          cd "$SCRATCH/$IOS_ARCH"
          
          MIN_IOS_VERSION=$IOS_MIN_SDK_VER
            # min iOS version for arm64 is iOS 7
        
            if [[ "${IOS_ARCH}" == "arm64" || "${IOS_ARCH}" == "x86_64" ]]; then
              MIN_IOS_VERSION=7.0 # 7.0 as this is the minimum for these architectures
            elif [ "${IOS_ARCH}" == "i386" ]; then
              MIN_IOS_VERSION=6.0 # 6.0 to prevent start linking errors
              #CC="${CC} -m32"
            fi
            MIN_TYPE=-miphoneos-version-min=
            if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]]; then
              MIN_TYPE=-mios-simulator-version-min=
            fi


          IOS_CFLAGS="-arch $IOS_ARCH $MIN_TYPE$MIN_IOS_VERSION "
          export CC=`xcrun -find clang`
          export LD=`xcrun -find ld`
          export CFLAGS="-O3 ${IOS_CFLAGS} -isysroot ${SDKROOT}"
          export LDFLAGS="${IOS_CFLAGS} -isysroot ${SDKROOT}  -stdlib=libc++ "
          export CPPFLAGS="${CFLAGS} -stdlib=libc++"

          echo "Compiler: $CC"
          echo "Building Sphinx-${VER} for ${PLATFORM} ${SDKVERSION} ${IOS_ARCH} : iOS Minimum=$MIN_IOS_VERSION"

          set +e

          
          

          echo "--------------------------"
          echo "Running make for ${IOS_ARCH}"
          echo "Please stand by..."
          # Must run at -j 1 (single thread only else will fail)

          

          
          echo "--------------------------"
          echo "Configure"
          echo "--------------------------"

          HOSTTYPE="${IOS_ARCH}-apple-darwin"
          if [ "${IOS_ARCH}" == "arm64" ]; then
              # Fix unknown type for arm64 cpu (which is aarch64)
              HOSTTYPE="aarch64-apple-darwin"
          fi

          $CURRENTPATH/configure \
              --host="${HOSTTYPE}" \
              --prefix="$DEST/$IOS_ARCH" \
              --without-lapack \
              --without-python \
              --with-sphinxbase="$SPHINXBASE_DIR" \
          || exit 1
              

          echo "--------------------------"
          echo "Make Install"
          echo "--------------------------"
         
          make -j3 install $EXPORT || exit 1

          unset CC CFLAG CFLAGS EXTRAFLAGS THECOMPILER
          cd $CURRENTPATH


        done

        unset CC CFLAG CFLAGS 
        unset PLATFORM CROSS_TOP CROSS_SDK BUILD_TOOLS
        unset IOS_DEVROOT IOS_SDKROOT 

        mkdir -p output
        mkdir -p output/include

        cd $CURRENTPATH/bin

        if [ "${SPHINX_TYPE}" == "sphinxbase" ]; then
        
          echo "Creating fat lib for sphinxbase"
          lipo -create armv7/lib/libsphinxbase.a \
                arm64/lib/libsphinxbase.a \
                i386/lib/libsphinxbase.a \
                x86_64/lib/libsphinxbase.a \
                -output $CURRENTPATH/output/sphinxbase.a
          echo "Creating fat lib for sphinxad"
          lipo -create armv7/lib/libsphinxad.a \
                arm64/lib/libsphinxad.a \
                i386/lib/libsphinxad.a \
                x86_64/lib/libsphinxad.a \
                -output $CURRENTPATH/output/sphinxad.a

          cp -R arm64/include/ $CURRENTPATH/output/include

          lipo -info $CURRENTPATH/output/sphinxbase.a
          lipo -info $CURRENTPATH/output/sphinxad.a

          strip -x $CURRENTPATH/output/sphinxbase.a
          strip -x $CURRENTPATH/output/sphinxad.a

        elif [ "${SPHINX_TYPE}" == "pocketsphinx" ]; then
        
          echo "Creating fat lib for pocketsphinx"
          lipo -create armv7/lib/libpocketsphinx.a \
                arm64/lib/libpocketsphinx.a \
                i386/lib/libpocketsphinx.a \
                x86_64/lib/libpocketsphinx.a \
                -output $CURRENTPATH/output/pocketsphinx.a

          cp -R arm64/include/ $CURRENTPATH/output/include

          lipo -info $CURRENTPATH/output/pocketsphinx.a
          
          strip -x $CURRENTPATH/output/pocketsphinx.a

        fi
        cd ../
        echo "------------------------"
        echo "Completed Build for $SPHINX_TYPE for $IOS_ARCHS"
        echo "------------------------"
        
        # get back to root ofxSphinx Dir
        cd ../ 
        sleep 1

    done

        echo "------------------------"
        echo "Completed All"
        echo "------------------------"

    unset TOOLCHAIN DEVELOPER
  fi
 
 }

 
# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

  LIB_FOLDER="$BUILD_ROOT_DIR/$TYPE"

  # prepare headers directory if needed
  mkdir -p $1/include

  mkdir -p $1/license
 
  # prepare libs directory if needed
  mkdir -p $1/lib/$TYPE
 
  if [ "$TYPE" == "osx" ] ; then
    echo "not implemented"
    # Standard *nix style copy.
    # copy headers
    #cp -R $LIB_FOLDER/include/ $1/include/
 
    # copy lib
    #cp -R $LIB_FOLDER/lib/*.a $1/lib/$TYPE/
  fi

  if [ "$TYPE" == "ios" ] ; then
    # Standard *nix style copy.
    echo "copy headers"
    cp -R sphinxbase/output/include/ $1/include
    cp -R pocketsphinx/output/include/ $1/include

    # copy lib
    echo "copy libs"
    cp -R sphinxbase/output/*.a $1/lib/ios/
    cp -R pocketsphinx/output/*.a $1/lib/ios/
    #cp -R $LIB_FOLDER/lib/*.a $1/lib/$TYPE/
  fi

  cp -R sphinxbase/LICENSE $1/license/

}
 
# executed inside the lib src dir
function clean() {
  if [ "$TYPE" == "osx" ] ; then
    make clean;
  fi
}