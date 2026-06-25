#!/bin/bash
# shellcheck disable=SC1091
# ********************************************************************************
# Copyright (c) 2018 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made
# available under the terms of the Apache Software License 2.0
# which is available at https://www.apache.org/licenses/LICENSE-2.0.
#
# SPDX-License-Identifier: Apache-2.0
# ********************************************************************************

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=sbin/common/constants.sh
source "$SCRIPT_DIR/../../sbin/common/constants.sh"
source "$SCRIPT_DIR/../../sbin/common/downloaders.sh"

export ANT_HOME=/cygdrive/C/Projects/OpenJDK/apache-ant-1.10.1
export DRAGONWELL8_BOOTSTRAP=/cygdrive/C/openjdk/dragonwell-bootstrap/jdk8u272-ga
export ALLOW_DOWNLOADS=true
export LANG=C
export OPENJ9_NASM_VERSION=2.13.03

TOOLCHAIN_VERSION=""
if [[ "${VARIANT}" == "${BUILD_VARIANT_DRAGONWELL}" && ("${JAVA_TO_BUILD}" = "jdk21u" || "${JAVA_TO_BUILD}" = "jdk25u") ]] || [ "${VARIANT}" != "${BUILD_VARIANT_DRAGONWELL}" ]; then
if [ "$ARCHITECTURE" == "aarch64" ] && [ "$JAVA_FEATURE_VERSION" == 16 ]; then
  # Windows aarch64 jdk16 cross compiles requires same version boot jdk
  BOOT_JDK_VERSION="$((JAVA_FEATURE_VERSION))"
else
  BOOT_JDK_VERSION="$((JAVA_FEATURE_VERSION-1))"
fi
BOOT_JDK_VARIABLE="JDK${JDK_BOOT_VERSION}_BOOT_DIR"
if [ ! -d "$(eval echo "\$$BOOT_JDK_VARIABLE")" ]; then
  bootDir="$PWD/jdk-$JDK_BOOT_VERSION"
  # Note we export $BOOT_JDK_VARIABLE (i.e. JDKXX_BOOT_DIR) here
  # instead of BOOT_JDK_VARIABLE (no '$').
  export "${BOOT_JDK_VARIABLE}"="$bootDir"
  if [ ! -x "$bootDir/bin/javac.exe" ]; then
    # Set to a default location as linked in the ansible playbooks
    if [ -x "/cygdrive/c/openjdk/jdk-${JDK_BOOT_VERSION}/bin/javac" ]; then
      echo "Could not use ${BOOT_JDK_VARIABLE} - using /cygdrive/c/openjdk/jdk-${JDK_BOOT_VERSION}"
      # shellcheck disable=SC2140
      export "${BOOT_JDK_VARIABLE}"="/cygdrive/c/openjdk/jdk-${JDK_BOOT_VERSION}"
    elif [ "$JDK_BOOT_VERSION" -ge 8 ]; then # Adoptium has no build pre-8
      downloadWindowsBootJDK "${ARCHITECTURE}" "${JDK_BOOT_VERSION}" "$bootDir"
    fi
  fi
fi
# shellcheck disable=SC2155
export JDK_BOOT_DIR="$(eval echo "\$$BOOT_JDK_VARIABLE")"
"$JDK_BOOT_DIR/bin/java" -version 2>&1 | sed 's/^/BOOT JDK: /'
"$JDK_BOOT_DIR/bin/java" -version > /dev/null 2>&1
executedJavaVersion=$?
if [ $executedJavaVersion -ne 0 ]; then
    echo "Failed to obtain or find a valid boot jdk"
    exit 1
fi
"$JDK_BOOT_DIR/bin/java" -version 2>&1 | sed 's/^/BOOT JDK: /'
fi
if [ "${ARCHITECTURE}" == "x86-32" ]
then
  export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache --with-target-bits=32 --target=x86"

  if [ "${VARIANT}" == "${BUILD_VARIANT_OPENJ9}" ]
  then
    export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-openssl=fetched --enable-openssl-bundling"
    if [ "${JAVA_TO_BUILD}" == "${JDK8_VERSION}" ]
    then
      # https://github.com/adoptium/temurin-build/issues/243
      export INCLUDE="C:\Program Files\Debugging Tools for Windows (x64)\sdk\inc;$INCLUDE"
      export PATH="/c/cygwin64/bin:/usr/bin:$PATH"
      TOOLCHAIN_VERSION="2013"
    elif [ "${JAVA_TO_BUILD}" == "${JDK11_VERSION}" ]
    then
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-freemarker-jar=/cygdrive/c/openjdk/freemarker.jar"

      # Next line a potentially tactical fix for https://github.com/adoptium/temurin-build/issues/267
      export PATH="/usr/bin:$PATH"
    fi
    # LLVM needs to be before cygwin as at least one machine has 64-bit clang in cygwin #813
    # NASM required for OpenSSL support as per #604
    export PATH="/cygdrive/c/Program Files (x86)/LLVM/bin:/cygdrive/c/openjdk/nasm-$OPENJ9_NASM_VERSION:$PATH"
  else
    if [ "${JAVA_TO_BUILD}" == "${JDK8_VERSION}" ]
    then
      export PATH="/cygdrive/c/openjdk/make-3.82/:$PATH"
    elif [ "${JAVA_TO_BUILD}" == "${JDK11_VERSION}" ]
    then 
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"
    elif [ "$JAVA_FEATURE_VERSION" -gt 11 ] && [ "$JAVA_FEATURE_VERSION" -lt 21 ]
    then
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"
    elif [ "$JAVA_FEATURE_VERSION" -ge 21 ]
    then
      if [ "${JAVA_TO_BUILD}" = "jdk21u" ];then
        TOOLCHAIN_VERSION="2022"
      else
        TOOLCHAIN_VERSION="2019"
      fi
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"
    fi
  fi
fi

if [ "${ARCHITECTURE}" == "x64" ]
then
  if [ "${VARIANT}" == "${BUILD_VARIANT_OPENJ9}" ]
  then
    export HAS_AUTOCONF=1
    export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-openssl=fetched --enable-openssl-bundling"
    export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"

    if [ "${JAVA_TO_BUILD}" == "${JDK8_VERSION}" ]
    then
      export INCLUDE="C:\Program Files\Debugging Tools for Windows (x64)\sdk\inc;$INCLUDE"
      export PATH="$PATH:/c/cygwin64/bin"
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"
      export BUILD_ARGS="${BUILD_ARGS} --skip-freetype"
      TOOLCHAIN_VERSION="2013"
    elif [ "${JAVA_TO_BUILD}" == "${JDK9_VERSION}" ]
    then
      TOOLCHAIN_VERSION="2013"
      export BUILD_ARGS="${BUILD_ARGS} --freetype-version 2.5.3"
    elif [ "${JAVA_TO_BUILD}" == "${JDK10_VERSION}" ]
    then
      export BUILD_ARGS="${BUILD_ARGS} --freetype-version 2.5.3"
    elif [ "$JAVA_FEATURE_VERSION" -ge 11 ]
    then
      if [ "${JAVA_TO_BUILD}" = "jdk21u" ];then
        TOOLCHAIN_VERSION="2022"
      else
        TOOLCHAIN_VERSION="2019"
      fi
      export BUILD_ARGS="${BUILD_ARGS} --skip-freetype"
    fi

    CUDA_VERSION=9.1
    CUDA_HOME_FULL="C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v$CUDA_VERSION"
    # use cygpath to map to 'short' names (without spaces)
    CUDA_HOME=$(cygpath -ms "$CUDA_HOME_FULL")
    if [[ $CUDA_HOME == *" "* ]]; then
      echo "[ERROR] All CUDA_HOME path folders must have either (a) no spaces, or (b) a shortened version configured in the environment."
      echo "CUDA_HOME unshortened: ${CUDA_HOME_FULL}"
      echo "CUDA_HOME shortened: ${CUDA_HOME}"
      exit 1
    fi
    if [ -f "$(cygpath -u "$CUDA_HOME"/include/cuda.h)" ]
    then
      export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --enable-cuda --with-cuda=$CUDA_HOME"
    else
      echo "[ERROR] The following file could not be found: $CUDA_HOME/include/cuda.h"
      echo "Please check that CUDA is correctly installed."
      exit 1
    fi

    # LLVM needs to be before cygwin as at least one machine has clang in cygwin #813
    # NASM required for OpenSSL support as per #604
    export PATH="/cygdrive/c/Program Files/LLVM/bin:/usr/bin:/cygdrive/c/openjdk/nasm-$OPENJ9_NASM_VERSION:$PATH"
  else
    export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache"
    if [ "${JAVA_TO_BUILD}" == "${JDK8_VERSION}" ]
    then
      export BUILD_ARGS="${BUILD_ARGS} --freetype-version 39ce3ac499d4cd7371031a062f410953c8ecce29" # 2.8.1
      export PATH="/cygdrive/c/openjdk/make-3.82/:$PATH"
    elif [ "$JAVA_FEATURE_VERSION" -ge 11 ]
    then
      if [ "${JAVA_TO_BUILD}" = "jdk21u" ];then
        TOOLCHAIN_VERSION="2022"
      else
        TOOLCHAIN_VERSION="2019"
      fi
    fi
  fi

  if [ "${VARIANT}" == "${BUILD_VARIANT_DRAGONWELL}" ] && [ "${JAVA_TO_BUILD}" == "${JDK8_VERSION}" ]
  then
    if [[ -d "${DRAGONWELL8_BOOTSTRAP}" ]]; then
      export JDK_BOOT_DIR="${DRAGONWELL8_BOOTSTRAP}"
    fi
    TOOLCHAIN_VERSION="2013"
  fi

  if [ "${VARIANT}" == "${BUILD_VARIANT_DRAGONWELL}" ] && [ "${JAVA_TO_BUILD}" == "${JDK11_VERSION}" ]
  then
    export JDK_BOOT_DIR=/cygdrive/c/Jenkins/jdk11/
    TOOLCHAIN_VERSION="2017"
  fi
fi

if [ "${VARIANT}" == "${BUILD_VARIANT_DRAGONWELL}" ] && [ "${JAVA_TO_BUILD}" == "jdk17" ]
then
  echo "set dragonwell 17 boot dir"
  export JDK_BOOT_DIR="/cygdrive/c/Jenkins/workspace/zulu17/"
fi

if [ "${VARIANT}" == "${BUILD_VARIANT_DRAGONWELL}" ] && [ "${JAVA_TO_BUILD}" == "jdk25u" ]; then
  echo "set download devkit and setup"
  rm -rf /devkit
  mkdir -p /devkit
  wget -q https://github.com/adoptium/devkit-binaries/releases/download/vs2022_redist_14.40.33807_10.0.26100.1742/vs2022_redist_14.40.33807_10.0.26100.1742.zip -O vs.zip
  unzip vs.zip -d /devkit/
  rm -rf vs.zip
  CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-ucrt-dll-dir=/devkit/ucrt/DLLs/x64"
  CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-msvcr-dll=/devkit/x64/vcruntime140.dll"
  CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-vcruntime-1-dll=/devkit/x64/vcruntime140_1.dll"
  CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-msvcp-dll=/devkit/msvcp140.dll"
  #CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-devkit=/devkit"
  export LD_LIBRARY_PATH=/devkit/lib64/:/devkit/lib:${LD_LIBRARY_PATH}
  TOOLCHAIN_VERSION="2022"
fi

if [[ "$JAVA_FEATURE_VERSION" -ge 21 ]]; then
  # jdk-21+ uses "bundled" FreeType
  export BUILD_ARGS="${BUILD_ARGS} --freetype-dir bundled"
fi

if [ "${ARCHITECTURE}" == "aarch64" ]; then
  export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --disable-ccache --openjdk-target=aarch64-unknown-cygwin"
fi


if [ -n "${TOOLCHAIN_VERSION}" ]; then
    export CONFIGURE_ARGS_FOR_ANY_PLATFORM="${CONFIGURE_ARGS_FOR_ANY_PLATFORM} --with-toolchain-version=${TOOLCHAIN_VERSION}"
fi
