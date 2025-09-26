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
- Build TIFF 3.9.7 from source
- Build HylaFAX+ with Rocky Linux patches
- Install everything to `/usr/local/`

### 2. Configure HylaFAX+ (After Build)

The build script will show you the exact command to run. It will look like:

```bash
sudo /usr/local/sbin/faxsetup -with-TIFFBIN=/tmp/hylafax-build-XXXXXX/tiff397-install/bin
```

**Basic Configuration Steps:**

1. **Run Setup (Replace XXXXXX with your actual build timestamp):**
   ```bash
   sudo /usr/local/sbin/faxsetup -with-TIFFBIN=/tmp/hylafax-build-XXXXXX/tiff397-install/bin
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

# Verify TIFF tools (use path from build-info.txt)
ls -la /tmp/hylafax-build-XXXXXX/tiff397-install/bin/
```

## Key Features

- **Complete Static Library Build**: All external dependencies (JPEG, TIFF) are built as static libraries
- **System-Independent**: No system JPEG installation required - JPEG is built from source and embedded in TIFF
- **Rocky Linux 9.x Compatibility**: Tested and working on Rocky Linux 9.x with GCC 14.2.1
- **Git-based TIFF**: Uses TIFF 3.9.7 directly from GitLab repository
- **Fork Integration**: Uses your GitHub HylaFAX+ fork with Rocky Linux compatibility patches
- **Automated Build**: Single script handles all dependencies and compilation
- **Position Independent Code**: All libraries built with -fPIC for modern security standards

## Important Notes

- **TIFF Tools Path:** The build creates custom TIFF tools. Always use the path from your build directory, NOT system TIFF packages.
- **Build Directory:** The script creates `/tmp/hylafax-build-TIMESTAMP/` - don't delete this, you need the TIFF tools!
- **Configuration:** Always use the `-with-TIFFBIN` parameter pointing to your custom TIFF tools.

## Troubleshooting

### If Build Fails
1. Check you're not running as root
2. Ensure you have sudo privileges
3. Make sure you have internet connection for package downloads

### If Setup Asks for Modem
- This is normal for a complete fax server setup
- For testing without hardware modems, you can skip modem configuration
- Press Ctrl+C if setup gets stuck asking for serial ports

### Finding Your Build Directory
```bash
ls -la /tmp/hylafax-build-*/build-info.txt
cat /tmp/hylafax-build-*/build-info.txt
```

## What Gets Installed

- **HylaFAX+ binaries:** `/usr/local/sbin/` (faxq, hfaxd, faxsetup, etc.)
- **HylaFAX+ client tools:** `/usr/local/bin/` (sendfax, faxstat, etc.)
- **TIFF 3.9.7 tools:** `/tmp/hylafax-build-TIMESTAMP/tiff397-install/bin/`
- **Configuration files:** `/usr/local/etc/hylafax/`
- **Spool directory:** `/var/spool/hylafax/`

## System Requirements

- Rocky Linux 9.x
- At least 2GB RAM
- 1GB free disk space
- Internet connection for package downloads
- Regular user account with sudo privileges

## Support

This build includes all necessary patches for Rocky Linux 9.x compatibility:
- Modern GCC 14.2.1 support  
- C++17 standard compliance
- System library compatibility
- TIFF 3.9.7 static linking

For issues, check the build log output and ensure all dependencies were installed correctly.