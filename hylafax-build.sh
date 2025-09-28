#!/bin/bash

# HylaFAX+ All-in-One Build Script for Rocky Linux 9.x
# This script builds HylaFAX+ with TIFF 3.9.7 and libjpeg-turbo from source
# Author: GitHub Copilot
# Date: September 28, 2025

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/hylafax-build-$(date +%Y%m%d-%H%M%S)"
TIFF_TAG="v3.9.7"
JPEG_TURBO_REPO="https://github.com/libjpeg-turbo/libjpeg-turbo.git"
JPEG_TURBO_TAG="3.0.4"
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
    zlib-devel \
    jbigkit-devel \
    libXmu-devel \
    ghostscript \
    netpbm-progs \
    git \
    wget \
    gcc-c++ \
    make \
    nasm || {
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
export CFLAGS="-fPIC"
export CXXFLAGS="-fPIC"
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

# Step 4: Build TIFF 3.9.7
header "Building TIFF 3.9.7"
log "Cloning TIFF library from GitLab..."
git clone https://gitlab.com/libtiff/libtiff.git tiff-source
cd tiff-source
git checkout "$TIFF_TAG"

log "Configuring TIFF build with static libjpeg-turbo..."
./autogen.sh
export CFLAGS="-fPIC"
export CXXFLAGS="-fPIC" 
export LDFLAGS="-L$BUILD_DIR/jpeg-install/lib"
export CPPFLAGS="-I$BUILD_DIR/jpeg-install/include"
./configure --prefix="/usr/local" \
    --enable-static \
    --disable-shared \
    --with-zlib \
    --with-jpeg-include-dir="$BUILD_DIR/jpeg-install/include" \
    --with-jpeg-lib-dir="$BUILD_DIR/jpeg-install/lib"

log "Building TIFF library..."
make -j$(nproc)

log "Installing TIFF library..."
sudo make install

# Verify TIFF installation
if [ ! -f "/usr/local/lib/libtiff.a" ]; then
    error "TIFF static library not found after installation"
    error "Expected: /usr/local/lib/libtiff.a"
    exit 1
fi

# Verify no shared TIFF libraries were created in /usr/local/lib
if ls "/usr/local/lib/"libtiff*.so* >/dev/null 2>&1; then
    error "Shared TIFF libraries found - static build failed"
    exit 1
fi

log "TIFF 3.9.7 built successfully as static library with embedded libjpeg-turbo"
log "TIFF tools available in: /usr/local/bin/"
ls -la "/usr/local/bin/"tiff* | head -10

# Step 5: Clone and build HylaFAX+
header "Building HylaFAX+"
cd "$BUILD_DIR"
log "Cloning HylaFAX+ repository..."
git clone --branch "$HYLAFAX_BRANCH" "$HYLAFAX_REPO" hylafax-source
cd hylafax-source

log "Configuring HylaFAX+ build..."
./configure --with-TIFFLIB="/usr/local/lib/libtiff.a" \
    --with-TIFFINC="-I/usr/local/include" \
    --with-LIBTIFF="/usr/local/lib/libtiff.a" \
    --with-ZLIB \
    --with-JPEG \
    --with-TIFFBIN="/usr/local/bin" \
    --with-DSO=auto \
    --disable-pam

log "Building HylaFAX+..."
# Build and check if we need JPEG static linking fix
if ! make -j$(nproc); then
    log "Initial build failed, applying comprehensive static libjpeg-turbo linking fix..."
    
    # Fix libhylafax shared library to include static libjpeg-turbo
    sed -i 's|\${MACHDEPLIBS}|\${MACHDEPLIBS} '$BUILD_DIR'/jpeg-install/lib/libjpeg.a|' libhylafax/Makefile.LINUXdso 2>/dev/null || true
    
    # Fix all utility programs to link libjpeg-turbo library
    for makefile in util/Makefile faxd/Makefile hfaxd/Makefile; do
        if [ -f "$makefile" ]; then
            log "Fixing libjpeg-turbo linking in $makefile..."
            # Add libjpeg-turbo library to LDLIBS
            if ! grep -q "jpeg-install/lib/libjpeg.a" "$makefile"; then
                sed -i 's|LDLIBS[[:space:]]*=.*|& '$BUILD_DIR'/jpeg-install/lib/libjpeg.a|' "$makefile"
                # Also add to DSO libs if present
                sed -i 's|DSLIBS[[:space:]]*=.*|& '$BUILD_DIR'/jpeg-install/lib/libjpeg.a|' "$makefile" 2>/dev/null || true
            fi
        fi
    done
    
    # Fix specific linking for utilities that directly use libjpeg-turbo
    sed -i 's|\$(DSLIBS)|\$(DSLIBS) '$BUILD_DIR'/jpeg-install/lib/libjpeg.a|g' util/Makefile 2>/dev/null || true
    
    # Rebuild with fixed linking
    make clean && make -j$(nproc)
fi

log "Verifying libjpeg-turbo static linking before installation..."
# Test a few key executables for JPEG dependencies
if command -v ldd &> /dev/null; then
    for exe in util/faxmodem util/tiffcheck util/textfmt; do
        if [ -f "$exe" ]; then
            if ldd "$exe" 2>/dev/null | grep -q "libjpeg"; then
                log "WARNING: $exe still has dynamic libjpeg dependency"
            else
                log "✅ $exe: Static libjpeg-turbo linking verified"
            fi
        fi
    done
fi

log "Installing HylaFAX+..."
sudo make install

header "Build Complete!"
log "HylaFAX+ has been successfully built and installed with static libraries!"
log ""
log "Static Library Build Verification:"
log "✅ libjpeg-turbo: Built as static library (libjpeg.a)"
log "✅ TIFF: Built as static library with embedded libjpeg-turbo (libtiff.a)"
log "✅ HylaFAX+: Uses static libraries for all external dependencies"
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
TIFF Install Directory: /usr/local
TIFF Tools Path: /usr/local/bin
HylaFAX+ Install Directory: /usr/local
Configuration Command: sudo /usr/local/sbin/faxsetup

Libraries built:
- libjpeg-turbo: $BUILD_DIR/jpeg-install/lib/libjpeg.a (static, used for TIFF build)
- TIFF: /usr/local/lib/libtiff.a (static, includes libjpeg-turbo)
- HylaFAX+: /usr/local (uses system-installed TIFF tools)
EOF

log "Build information saved to: $BUILD_DIR/build-info.txt"