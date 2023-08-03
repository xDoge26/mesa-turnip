#!/bin/bash

# Preparing

echo "
deb http://ports.ubuntu.com/ubuntu-ports jammy main restricted universe multiverse
deb-src http://ports.ubuntu.com/ubuntu-ports jammy main restricted universe multiverse

deb http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted universe multiverse
deb-src http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted universe multiverse

deb http://ports.ubuntu.com/ubuntu-ports jammy-backports main restricted universe multiverse
deb-src http://ports.ubuntu.com/ubuntu-ports jammy-backports main restricted universe multiverse

deb http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted universe multiverse
deb-src http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted universe multiverse
" > /etc/apt/sources.list

sudo dpkg --add-architecture armhf
sudo apt update
sudo apt upgrade
sudo apt build-dep mesa 
apt install make cmake git wget vulkan-tools mesa-utils g++-arm-linux-gnueabihf g++-aarch64-linux-gnu
apt install zlib1g-dev:armhf libexpat1-dev:armhf libdrm-dev:armhf libx11-dev:armhf libx11-xcb-dev:armhf libxext-dev:armhf libxdamage-dev:armhf libxcb-glx0-dev:armhf libxcb-dri2-0-dev:armhf libxcb-dri3-dev:armhf libxcb-shm0-dev:armhf libxcb-present-dev:armhf libxshmfence-dev:armhf libxxf86vm-dev:armhf libxrandr-dev:armhf libwayland-dev:armhf wayland-protocols:armhf libwayland-egl-backend-dev:armhf 
apt install zlib1g-dev:arm64 libexpat1-dev:arm64 libdrm-dev:arm64 libx11-dev:arm64 libx11-xcb-dev:arm64 libxext-dev:arm64 libxdamage-dev:arm64 libxcb-glx0-dev:arm64 libxcb-dri2-0-dev:arm64 libxcb-dri3-dev:arm64 libxcb-shm0-dev:arm64 libxcb-present-dev:arm64 libxshmfence-dev:arm64 libxxf86vm-dev:arm64 libxrandr-dev:arm64 libwayland-dev:arm64 wayland-protocols:arm64 libwayland-egl-backend-dev:arm64  
cp /usr/include/libdrm/drm.h /usr/include/libdrm/drm_mode.h /usr/include/

# Download mesa
BUILD_PREFIX=~/Desktop
MESA_PREFIX=${BUILD_PREFIX}/mesa-main

wget --continue --directory-prefix ${BUILD_PREFIX} https://gitlab.freedesktop.org/mesa/mesa/-/archive/main/mesa-main.tar.gz
tar -xf ${BUILD_PREFIX}/*.tar.gz --directory ${BUILD_PREFIX}

# Set env var

MESA_VER=$(cat ${MESA_PREFIX}/VERSION)
DATE=$(date +"%F" | sed 's/-//g')

MESA_64=${BUILD_PREFIX}/mesa-vulkan-kgsl_${MESA_VER}-${DATE}_arm64
MESA_32=${BUILD_PREFIX}/mesa-vulkan-kgsl_${MESA_VER}-${DATE}_armhf

# Cross compile

echo "\
[binaries]
c = 'arm-linux-gnueabihf-gcc'
cpp = 'arm-linux-gnueabihf-g++'
ar = 'arm-linux-gnueabihf-ar'
strip = 'arm-linux-gnueabihf-strip'
pkgconfig = 'arm-linux-gnueabihf-pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'armv7l'
endian = 'little'
" > ${MESA_PREFIX}/arm.txt

# Build mesa 
cd ${MESA_PREFIX}

meson build64/ --prefix /usr --libdir lib/aarch64-linux-gnu/ -D platforms=x11 -D gallium-drivers=freedreno -D vulkan-drivers=freedreno -D freedreno-kmds=kgsl -D dri3=enabled -D buildtype=release -D glx=disabled -D egl=disabled -D gles1=disabled -D gles2=disabled -D gallium-xa=disabled -D opengl=false -D shared-glapi=false
meson compile -C build64/
meson install -C build64/ --destdir ${MESA_64}

meson build32/ --cross-file arm.txt --prefix /usr --libdir lib/arm-linux-gnueabihf/ -D platforms=x11 -D gallium-drivers=freedreno -D vulkan-drivers=freedreno -D freedreno-kmds=kgsl -D dri3=enabled -D buildtype=release -D glx=disabled -D egl=disabled -D gles1=disabled -D gles2=disabled -D gallium-xa=disabled -D opengl=false -D shared-glapi=false
meson compile -C build32/
meson install -C build32/ --destdir ${MESA_32}

# Build deb64
cd ${BUILD_PREFIX}


apt download mesa-vulkan-drivers:arm64
dpkg -e mesa-vulkan-drivers_*_arm64.deb $MESA_64/DEBIAN/
rm ${MESA_64}/DEBIAN/md5sums ${MESA_64}/DEBIAN/triggers
rm -rf ${MESA_64}/usr/share/drirc.d

mkdir ${MESA_64}/DEBIAN

echo "\
Package: mesa-vulkan-kgsl
Source: mesa
Version: ${MESA_VER}
Architecture: arm64
Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>
Original-Maintainer: Debian X Strike Force <debian-x@lists.debian.org>
Depends: libvulkan1, python3:any | python3-minimal:any, libc6, libdrm-amdgpu1, libdrm2, libelf1, libexpat1, libgcc-s1, libstdc++6, libwayland-client0, libx11-xcb1, libxcb-dri3-0, libxcb-present0, libxcb-randr0, libxcb-shm0, libxcb-sync1, libxcb-xfixes0, libxcb1, libxshmfence1, libzstd1, zlib1g
Replaces: mesa-vulkan-drivers 
Breaks: mesa-vulkan-drivers
Provides: vulkan-icd
Section: libs
Priority: optional
Multi-Arch: same
Homepage: https://mesa3d.org/
Description: Mesa Vulkan graphics drivers
 Vulkan is a low-overhead 3D graphics and compute API. This package
 includes Vulkan drivers provided by the Mesa project.
" > ${MESA_64}/DEBIAN/control

cp ${MESA_PREFIX}/build64/src/freedreno/vulkan/libvulkan_freedreno.so ${MESA_64}/usr/lib/aarch64-linux-gnu/
cp ${MESA_PREFIX}/build64/src/freedreno/vulkan/freedreno_icd.aarch64.json ${MESA_64}/usr/share/vulkan/icd.d/

dpkg-deb --build --root-owner-group ${MESA_64}


# Build deb32
cd ${HOME}

mkdir -p ${MESA_32}/usr/lib/arm-linux-gnueabihf/
mkdir -p ${MESA_32}/usr/share/vulkan/icd.d/
mkdir ${MESA_32}/DEBIAN

echo "\
Package: mesa-vulkan-kgsl
Source: mesa
Version: ${MESA_VER}
Architecture: armhf
Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>
Original-Maintainer: Debian X Strike Force <debian-x@lists.debian.org>
Depends: libvulkan1, python3:any | python3-minimal:any, libc6, libdrm-amdgpu1, libdrm2, libelf1, libexpat1, libgcc-s1, libstdc++6, libwayland-client0, libx11-xcb1, libxcb-dri3-0, libxcb-present0, libxcb-randr0, libxcb-shm0, libxcb-sync1, libxcb-xfixes0, libxcb1, libxshmfence1, libzstd1, zlib1g
Replaces: mesa-vulkan-drivers
Breaks: mesa-vulkan-drivers
Provides: vulkan-icd
Section: libs
Priority: optional
Multi-Arch: same
Homepage: https://mesa3d.org/
Description: Mesa Vulkan graphics drivers
 Vulkan is a low-overhead 3D graphics and compute API. This package
 includes Vulkan drivers provided by the Mesa project.
" > ${MESA_32}/DEBIAN/control

cp ${MESA_PREFIX}/build32/src/freedreno/vulkan/libvulkan_freedreno.so ${MESA_32}/usr/lib/arm-linux-gnueabihf/
cp ${MESA_PREFIX}/build32/src/freedreno/vulkan/freedreno_icd.armv7l.json ${MESA_32}/usr/share/vulkan/icd.d/

dpkg-deb --build --root-owner-group ${MESA_32}
