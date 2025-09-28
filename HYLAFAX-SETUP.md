# HylaFAX+ Installation and Setup Guide for Rocky Linux

## Quick Start

### 1. Build HylaFAX+ (One Command)

```bash
# Download and run the all-in-one build script
wget https://your-repo/hylafax-build.sh
chmod +x hylafax-build.sh
./hylafax-build.sh
```

**Or if you have the script locally:**
```bash
./hylafax-build.sh
```

The script will:
- Install all required dependencies
- Build libjpeg-turbo from GitHub source
- Build TIFF 3.9.7 from source with embedded libjpeg-turbo
- Build HylaFAX+ with Rocky Linux compatibility patches
- Install everything to `/usr/local/`

### 2. Configure HylaFAX+ (After Build)

The build script will show you the exact command to run:

```bash
sudo /usr/local/sbin/faxsetup
```

**Basic Configuration Steps:**

1. **Run Setup:**
   ```bash
   sudo /usr/local/sbin/faxsetup
   ```

2. **Create Required Users:**
   ```bash
   sudo useradd -r -s /bin/false uucp 2>/dev/null || true
   sudo mkdir -p /var/spool/hylafax
   sudo chown uucp:uucp /var/spool/hylafax
   ```

3. **Start HylaFAX+ Services:**
   ```bash
   sudo /usr/local/sbin/faxq &
   sudo /usr/local/sbin/hfaxd -i hylafax &
   ```

### 3. Test Installation

```bash
# Check if services are running
ps aux | grep fax

# Check installation
ls -la /usr/local/sbin/fax*

# Verify TIFF tools
ls -la /usr/local/bin/tiff*
```

## Key Features

- **Complete Static Library Build**: All external dependencies (libjpeg-turbo, TIFF) are built as static libraries
- **High-Performance JPEG**: Uses libjpeg-turbo with SIMD optimizations for 2-6x faster JPEG processing
- **System-Independent**: No system JPEG installation required - libjpeg-turbo is built from GitHub source and embedded in TIFF
- **Rocky Linux 9.x Compatibility**: Tested and working on Rocky Linux 9.x with GCC/G++ 14.2.1
- **Git-based Libraries**: Uses TIFF 3.9.7 from GitLab and libjpeg-turbo from GitHub repositories
- **Fork Integration**: Uses your GitHub HylaFAX+ fork with Rocky Linux compatibility patches
- **Automated Build**: Single script handles all dependencies and compilation
- **Position Independent Code**: All libraries built with -fPIC for modern security standards
- **SIMD Acceleration**: libjpeg-turbo built with SIMD optimizations for maximum performance

## Important Notes

- **Unified Installation**: Both HylaFAX+ and TIFF tools are installed to `/usr/local/` for consistency
- **TIFF Tools**: Custom TIFF 3.9.7 tools with embedded libjpeg-turbo are installed to `/usr/local/bin/`
- **No Temporary Dependencies**: All components are installed permanently, no temporary directories needed
- **System Integration**: TIFF tools are available system-wide and integrated with HylaFAX+ automatically

## Troubleshooting

### If Build Fails
1. Check you're not running as root
2. Ensure you have sudo privileges
3. Make sure you have internet connection for package downloads

### If Setup Asks for Modem
- This is normal for a complete fax server setup
- For testing without hardware modems, you can skip modem configuration
- Press Ctrl+C if setup gets stuck asking for serial ports

## What Gets Installed

- **HylaFAX+ binaries:** `/usr/local/sbin/` (faxq, hfaxd, faxsetup, etc.)
- **HylaFAX+ client tools:** `/usr/local/bin/` (sendfax, faxstat, etc.)
- **TIFF 3.9.7 tools:** `/usr/local/bin/` (tiffinfo, tiff2ps, tiffcp, etc.)
- **TIFF 3.9.7 libraries:** `/usr/local/lib/` (libtiff.a with embedded libjpeg-turbo)
- **Configuration files:** `/usr/local/etc/hylafax/`
- **Spool directory:** `/var/spool/hylafax/`

**Note:** libjpeg-turbo is built temporarily and embedded into TIFF - no separate installation needed.

## System Requirements

- Rocky Linux 9.x
- At least 2GB RAM
- 1GB free disk space
- Internet connection for package downloads
- Regular user account with sudo privileges
- Development tools (automatically installed by script):
  - GCC/G++ 14.2.1+
  - CMake (for libjpeg-turbo build)
  - NASM (for SIMD optimizations)

## Support

This build includes all necessary patches for Rocky Linux 9.x compatibility:
- Modern GCC/G++ 14.2.1 support  
- C++17 standard compliance
- System library compatibility
- libjpeg-turbo 3.0.4 with SIMD acceleration
- TIFF 3.9.7 static linking with embedded libjpeg-turbo

For issues, check the build log output and ensure all dependencies were installed correctly.