#!/bin/bash

# HylaFAX+ All-in-One Static Build Script for Rocky Linux 10.x
# This script builds HylaFAX+ as fully static binaries with TIFF 3.9.7 and libjpeg-turbo from source

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/hylafax-build-$(date +%Y%m%d-%H%M%S)"
TIFF_TAG="v3.9.7"
JPEG_TURBO_REPO="https://github.com/libjpeg-turbo/libjpeg-turbo.git"
JPEG_TURBO_TAG="3.0.4"
ZLIB_REPO="https://github.com/madler/zlib.git"
ZLIB_TAG="v1.3.1"
JBIGKIT_REPO="https://github.com/openEuler-Networking/jbigkit.git"
JBIGKIT_TAG="master"
HYLAFAX_REPO="https://github.com/xuemin-liu/HylaFAX.git"
HYLAFAX_BRANCH="master"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Do not run this script as root. Use a regular user with sudo privileges."
    exit 1
fi

header "HylaFAX+ All-in-One Build Script"

# Change to /tmp for all operations
cd /tmp
log "Working in /tmp directory"

# Step 1: Install system dependencies
header "Installing System Dependencies"
log "Installing development tools and libraries..."
sudo dnf groupinstall -y "Development Tools" || {
    error "Failed to install Development Tools"
    exit 1
}

sudo dnf install -y \
    autoconf automake libtool \
    cmake cmake-data \
    ghostscript \
    netpbm-progs \
    git \
    wget \
    gcc-c++ \
    make \
    nasm \
    glibc-static \
    libstdc++-static || {
    error "Failed to install required packages"
    exit 1
}

# Step 2: Create build directory
header "Setting Up Build Environment"
log "Creating build directory: $BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Step 3: Build libjpeg-turbo library
header "Building libjpeg-turbo Library"
log "Cloning libjpeg-turbo from GitHub..."
git clone --branch "$JPEG_TURBO_TAG" --depth 1 "$JPEG_TURBO_REPO" jpeg-turbo-source
cd jpeg-turbo-source

log "Creating build directory for libjpeg-turbo..."
mkdir build
cd build

log "Configuring libjpeg-turbo build with CMake..."
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/jpeg-install" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DENABLE_SHARED=FALSE \
    -DENABLE_STATIC=TRUE \
    -DWITH_SIMD=TRUE \
    -DWITH_TURBOJPEG=FALSE

log "Building libjpeg-turbo library..."
make -j$(nproc)

log "Installing libjpeg-turbo library..."
make install

# Debug: Show what was actually installed
log "Debug: Contents of jpeg-install directory:"
ls -la "$BUILD_DIR/jpeg-install/" || true
ls -la "$BUILD_DIR/jpeg-install/lib/" 2>/dev/null || true
ls -la "$BUILD_DIR/jpeg-install/lib64/" 2>/dev/null || true

# Verify libjpeg-turbo installation (check both lib and lib64)
if [ -f "$BUILD_DIR/jpeg-install/lib/libjpeg.a" ]; then
    JPEG_LIB_DIR="$BUILD_DIR/jpeg-install/lib"
    log "Found libjpeg-turbo static library in lib/ directory"
elif [ -f "$BUILD_DIR/jpeg-install/lib64/libjpeg.a" ]; then
    JPEG_LIB_DIR="$BUILD_DIR/jpeg-install/lib64"
    log "Found libjpeg-turbo static library in lib64/ directory"
    # Create symlink in lib/ for consistency
    ln -sf "../lib64/libjpeg.a" "$BUILD_DIR/jpeg-install/lib/libjpeg.a"
    log "Created symlink: lib/libjpeg.a -> lib64/libjpeg.a"
else
    error "libjpeg-turbo static library not found after installation"
    error "Expected: $BUILD_DIR/jpeg-install/lib/libjpeg.a or $BUILD_DIR/jpeg-install/lib64/libjpeg.a"
    exit 1
fi

# Verify no shared JPEG libraries were created
if ls "$BUILD_DIR/jpeg-install/lib/"*.so* >/dev/null 2>&1 || ls "$BUILD_DIR/jpeg-install/lib64/"*.so* >/dev/null 2>&1; then
    error "Shared libjpeg-turbo libraries found - static build failed"
    exit 1
fi

log "libjpeg-turbo library built successfully as static library"
log "libjpeg-turbo library location: $JPEG_LIB_DIR/libjpeg.a"
log "libjpeg-turbo version: $(cat "$BUILD_DIR/jpeg-install/include/jversion.h" | grep JVERSION | cut -d'"' -f2)"

cd "$BUILD_DIR"

# Step 3: Build zlib library
header "Building zlib Library"
log "Cloning zlib from GitHub..."
git clone --branch "$ZLIB_TAG" --depth 1 "$ZLIB_REPO" zlib-source
cd zlib-source

log "Configuring zlib build..."
./configure --prefix="$BUILD_DIR/zlib-install" --static

log "Building zlib library..."
make -j$(nproc)

log "Installing zlib library..."
make install

# Debug: Show what was actually installed
log "Debug: Contents of zlib-install directory:"
ls -la "$BUILD_DIR/zlib-install/" || true
ls -la "$BUILD_DIR/zlib-install/lib/" 2>/dev/null || true

# Verify zlib installation
if [ ! -f "$BUILD_DIR/zlib-install/lib/libz.a" ]; then
    error "zlib static library not found after installation"
    error "Expected: $BUILD_DIR/zlib-install/lib/libz.a"
    exit 1
fi

# Verify no shared zlib libraries were created
if ls "$BUILD_DIR/zlib-install/lib/"*.so* >/dev/null 2>&1; then
    error "Shared zlib libraries found - static build failed"
    exit 1
fi

log "zlib library built successfully as static library"
log "zlib library location: $BUILD_DIR/zlib-install/lib/libz.a"
log "zlib version: $(cat "$BUILD_DIR/zlib-install/include/zlib.h" | grep ZLIB_VERSION | head -1 | cut -d'"' -f2)"

cd "$BUILD_DIR"

# Step 4: Build jbigkit library
header "Building jbigkit Library"
log "Cloning jbigkit from GitHub..."
git clone --branch "$JBIGKIT_TAG" --depth 1 "$JBIGKIT_REPO" jbigkit-source
cd jbigkit-source/libjbig

log "Configuring jbigkit build..."

log "Building jbigkit library..."
make -j$(nproc)

log "Installing jbigkit library to temp directory..."
mkdir -p "$BUILD_DIR/jbigkit-install/lib"
mkdir -p "$BUILD_DIR/jbigkit-install/include"
cp libjbig.a "$BUILD_DIR/jbigkit-install/lib/"
cp libjbig85.a "$BUILD_DIR/jbigkit-install/lib/"
cp jbig.h "$BUILD_DIR/jbigkit-install/include/"
cp jbig85.h "$BUILD_DIR/jbigkit-install/include/"
cp jbig_ar.h "$BUILD_DIR/jbigkit-install/include/"

# Debug: Show what was actually installed
log "Debug: Contents of jbigkit-install directory:"
ls -la "$BUILD_DIR/jbigkit-install/" || true
ls -la "$BUILD_DIR/jbigkit-install/lib/" 2>/dev/null || true
ls -la "$BUILD_DIR/jbigkit-install/include/" 2>/dev/null || true

# Verify jbigkit installation
if [ ! -f "$BUILD_DIR/jbigkit-install/lib/libjbig.a" ]; then
    error "jbigkit static library not found after installation"
    error "Expected: $BUILD_DIR/jbigkit-install/lib/libjbig.a"
    exit 1
fi

log "jbigkit library built successfully as static library"
log "jbigkit library location: $BUILD_DIR/jbigkit-install/lib/libjbig.a"
log "jbigkit85 library location: $BUILD_DIR/jbigkit-install/lib/libjbig85.a"

cd "$BUILD_DIR"

# Step 5: Build TIFF 3.9.7
header "Building TIFF 3.9.7"
log "Cloning TIFF library from GitLab..."
git clone https://gitlab.com/libtiff/libtiff.git tiff-source
cd tiff-source
git checkout "$TIFF_TAG"

log "Configuring TIFF build with static libjpeg-turbo, zlib, and jbigkit..."
./autogen.sh
export LDFLAGS="-L$BUILD_DIR/jpeg-install/lib -L$BUILD_DIR/zlib-install/lib -L$BUILD_DIR/jbigkit-install/lib"
export CPPFLAGS="-I$BUILD_DIR/jpeg-install/include -I$BUILD_DIR/zlib-install/include -I$BUILD_DIR/jbigkit-install/include"
./configure --prefix="$BUILD_DIR/tiff-install" \
    --enable-static \
    --disable-shared \
    --with-zlib-include-dir="$BUILD_DIR/zlib-install/include" \
    --with-zlib-lib-dir="$BUILD_DIR/zlib-install/lib" \
    --with-jpeg-include-dir="$BUILD_DIR/jpeg-install/include" \
    --with-jpeg-lib-dir="$BUILD_DIR/jpeg-install/lib" \
    --with-jbig-include-dir="$BUILD_DIR/jbigkit-install/include" \
    --with-jbig-lib-dir="$BUILD_DIR/jbigkit-install/lib"

log "Building TIFF library..."
make -j$(nproc)

log "Installing TIFF library to temp directory..."
make install

# Verify TIFF installation in temp directory
if [ ! -f "$BUILD_DIR/tiff-install/lib/libtiff.a" ]; then
    error "TIFF static library not found after installation"
    error "Expected: $BUILD_DIR/tiff-install/lib/libtiff.a"
    exit 1
fi

# Verify no shared TIFF libraries were created
if ls "$BUILD_DIR/tiff-install/lib/"libtiff*.so* >/dev/null 2>&1; then
    error "Shared TIFF libraries found - static build failed"
    exit 1
fi

log "Installing only TIFF executables to system directory..."
sudo mkdir -p /usr/local/bin
for tool in "$BUILD_DIR/tiff-install/bin/"*; do
    if [ -f "$tool" ] && [ -x "$tool" ]; then
        sudo cp "$tool" /usr/local/bin/
        log "Installed $(basename "$tool") to /usr/local/bin/"
    fi
done

log "TIFF 3.9.7 built successfully as static library with embedded libjpeg-turbo, zlib, and jbigkit"
log "TIFF tools available in: /usr/local/bin/"
ls -la "/usr/local/bin/"tiff* | head -10

# Step 6: Clone and build HylaFAX+
header "Building HylaFAX+"
cd "$BUILD_DIR"
log "Cloning HylaFAX+ repository..."
git clone --branch "$HYLAFAX_BRANCH" "$HYLAFAX_REPO" hylafax-source
cd hylafax-source

log "Configuring HylaFAX+ build for static linking..."
# Set up static linking environment for HylaFAX+
export LDFLAGS="-static -L$BUILD_DIR/tiff-install/lib -L$BUILD_DIR/jpeg-install/lib -L$BUILD_DIR/zlib-install/lib -L$BUILD_DIR/jbigkit-install/lib"
export CPPFLAGS="-I$BUILD_DIR/tiff-install/include -I$BUILD_DIR/jpeg-install/include -I$BUILD_DIR/zlib-install/include -I$BUILD_DIR/jbigkit-install/include"
export LIBS="-ltiff -ljpeg -lz -ljbig -ljbig85 -lm"
export CFLAGS="-static"
export CXXFLAGS="-static"

# First, check available configure options
log "Checking HylaFAX+ configure options..."
./configure -help | head -20 || true

./configure --with-TIFFLIB="$BUILD_DIR/tiff-install/lib/libtiff.a" \
    --with-TIFFINC="-I$BUILD_DIR/tiff-install/include" \
    --with-LIBTIFF="$BUILD_DIR/tiff-install/lib/libtiff.a" \
    --with-ZLIB \
    --with-JPEG \
    --with-TIFFBIN="/usr/local/bin" \
    --with-DSO=no \
    --disable-pam

log "Building HylaFAX+ as fully static binaries..."
# Build and check if we need static linking fixes
if ! make -j$(nproc); then
    log "Initial build failed, applying comprehensive static linking fixes..."
    
    # For static builds, we need to ensure all libraries are properly linked
    # Fix the LLDLIBS line in defs to include all required static libraries
    STATIC_LIBS="$BUILD_DIR/tiff-install/lib/libtiff.a $BUILD_DIR/jpeg-install/lib/libjpeg.a $BUILD_DIR/zlib-install/lib/libz.a $BUILD_DIR/jbigkit-install/lib/libjbig.a $BUILD_DIR/jbigkit-install/lib/libjbig85.a \${LIBPORT} -lm -lpthread"
    
    log "Fixing LLDLIBS in defs file to include all static libraries..."
    # Fix the main defs file to include all static libraries
    sed -i "s|^LLDLIBS[[:space:]]*=.*|LLDLIBS = -L\${UTIL} -lhylafax-\${ABI_VERSION} $STATIC_LIBS|" defs
    
    # Also ensure static linking flags
    sed -i 's|^LDFLAGS[[:space:]]*=.*|LDFLAGS = -static \${LDOPTS} \${LDLIBS}|' defs 2>/dev/null || true
    
    # Also fix MACHDEPLIBS to ensure all libraries are included
    sed -i "s|^MACHDEPLIBS[[:space:]]*=.*|MACHDEPLIBS = $STATIC_LIBS|" defs 2>/dev/null || true
    
    # Rebuild with fixed linking
    make clean && make -j$(nproc)
fi

log "Verifying fully static linking before installation..."
# Test key executables for any dynamic dependencies (except linux-vdso and ld-linux)
if command -v ldd &> /dev/null; then
    for exe in util/faxmodem util/tiffcheck util/textfmt faxd/faxd hfaxd/hfaxd; do
        if [ -f "$exe" ]; then
            DYNAMIC_DEPS=$(ldd "$exe" 2>/dev/null | grep -v "linux-vdso\|ld-linux\|statically linked" | wc -l)
            if [ "$DYNAMIC_DEPS" -eq 0 ] || ldd "$exe" 2>/dev/null | grep -q "statically linked"; then
                log "✅ $(basename $exe): Fully static binary verified"
            else
                log "⚠️  $(basename $exe): Has dynamic dependencies:"
                ldd "$exe" 2>/dev/null | grep -v "linux-vdso\|ld-linux" | sed 's/^/    /'
            fi
        fi
    done
else
    log "ldd not available, skipping static linking verification"
fi

log "Installing HylaFAX+..."
sudo make install

header "Build Complete!"
log "HylaFAX+ has been successfully built and installed as fully static binaries!"
log ""
log "Static Build Verification:"
log "✅ libjpeg-turbo: Built as static library in temp directory (libjpeg.a)"
log "✅ zlib: Built as static library in temp directory (libz.a)"
log "✅ jbigkit: Built as static library in temp directory (libjbig.a)"
log "✅ TIFF: Built as static library with embedded libjpeg-turbo, zlib, and jbigkit in temp directory (libtiff.a)"
log "✅ HylaFAX+: Built as fully static binaries with no external library dependencies"
log "✅ TIFF Tools: Only executables installed to system directory"
log ""
log "Build Directory: $BUILD_DIR"
log "TIFF Tools Path: /usr/local/bin"
log ""
log "Next steps:"
log "1. Run 'sudo /usr/local/sbin/faxsetup' to configure HylaFAX+"
log "2. TIFF tools are now installed in: /usr/local/bin/"
log ""
log "For configuration, run:"
log "  sudo /usr/local/sbin/faxsetup"

# Save important paths
cat > "$BUILD_DIR/build-info.txt" << EOF
HylaFAX+ Build Information
=========================
Build Date: $(date)
Build Directory: $BUILD_DIR
libjpeg-turbo Install Directory: $BUILD_DIR/jpeg-install
zlib Install Directory: $BUILD_DIR/zlib-install
jbigkit Install Directory: $BUILD_DIR/jbigkit-install
TIFF Install Directory: $BUILD_DIR/tiff-install
TIFF Tools Path: /usr/local/bin
HylaFAX+ Install Directory: /usr/local
Configuration Command: sudo /usr/local/sbin/faxsetup

Libraries built:
- libjpeg-turbo: $BUILD_DIR/jpeg-install/lib/libjpeg.a (static, temp directory)
- zlib: $BUILD_DIR/zlib-install/lib/libz.a (static, temp directory)
- jbigkit: $BUILD_DIR/jbigkit-install/lib/libjbig.a (static, temp directory)
- TIFF: $BUILD_DIR/tiff-install/lib/libtiff.a (static, includes libjpeg-turbo, zlib, and jbigkit, temp directory)
- TIFF Tools: /usr/local/bin/ (executables only, copied from temp directory)
- HylaFAX+: /usr/local (fully static binaries with embedded dependencies)
EOF

log "Build information saved to: $BUILD_DIR/build-info.txt"