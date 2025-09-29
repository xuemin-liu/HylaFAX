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
- Install only essential development tools and runtime utilities
- Build libjpeg-turbo from GitHub source (kept in temp directory)
- Build zlib from GitHub source (kept in temp directory) 
- Build jbigkit from GitHub source (kept in temp directory)
- Build TIFF 3.9.7 from source with all compression libraries embedded (static libs in temp directory)
- Build HylaFAX+ with Rocky Linux compatibility patches
- Install only essential executables to `/usr/local/`

### 2. Configure HylaFAX+ (After Build)

The build script will show you the exact command to run:

```bash
sudo /usr/local/sbin/faxsetup
```

**Basic Configuration Steps:**

1. **Install Required Dependencies:**
   ```bash
   # Install sendmail for email notifications (required for setup)
   sudo dnf install -y sendmail sendmail-cf
   ```
   **Note:** Sendmail is required for faxsetup to complete successfully. Email notifications can be disabled after setup if desired.

2. **Create Required Users:**
   ```bash
   sudo useradd -r -s /bin/false uucp 2>/dev/null || true
   sudo mkdir -p /var/spool/hylafax
   sudo chown uucp:uucp /var/spool/hylafax
   ```

3. **Run Setup:**
   ```bash
   # Run faxsetup (answer 'yes' to init scripts, 'no' to paging, 'no' to modem for testing)
   sudo /usr/local/sbin/faxsetup
   ```

4. **Start HylaFAX+ Services:**
   ```bash
   # Start services using systemctl
   sudo systemctl start hylafax
   
   # Check service status
   sudo systemctl status hylafax
   
   # Alternatively, start manually if needed:
   # sudo /usr/local/sbin/faxq &
   # sudo /usr/local/sbin/hfaxd -i hylafax &
   ```

### 3. Test Installation

```bash
# Check if services are running
ps aux | grep -E "faxq|hfaxd" | grep -v grep

# Check systemctl service status
sudo systemctl status hylafax

# Test server connectivity (requires authentication)
/usr/local/bin/faxstat -s

# Check installation files
ls -la /usr/local/sbin/fax*

# Verify TIFF tools with version info
/usr/local/bin/tiffinfo -v 2>&1 | head -5

# Verify static binary linking
ldd /usr/local/sbin/faxmodem 2>&1 | head -3
```

## Key Features

- **Complete Static Library Build**: All compression libraries (libjpeg-turbo, zlib, jbigkit) are built as optimized static libraries in temp directories
- **High-Performance JPEG**: Uses libjpeg-turbo with SIMD optimizations for 2-6x faster JPEG processing
- **Full Compression Support**: Includes ZIP/Deflate (zlib) and JBIG bi-level compression for maximum fax compatibility
- **System-Independent**: No system compression library dependencies - all built from GitHub source and embedded in TIFF
- **Headless Server Ready**: No X11 or GUI dependencies - optimized for server environments
- **Clean System Installation**: Only essential executables installed to system directories, all intermediate build artifacts kept in temp folders
- **Rocky Linux 9.x Compatibility**: Tested and working on Rocky Linux 9.x with GCC/G++ 14.2.1
- **Git-based Libraries**: Uses TIFF 3.9.7 from GitLab and libjpeg-turbo from GitHub repositories
- **Fork Integration**: Uses your GitHub HylaFAX+ fork with Rocky Linux compatibility patches
- **Automated Build**: Single script handles all dependencies and compilation
- **Optimized Static Build**: All libraries built without unnecessary position-independent code overhead
- **SIMD Acceleration**: libjpeg-turbo built with SIMD optimizations for maximum performance

## Important Notes

- **Clean Installation**: Only essential executables (HylaFAX+ and TIFF tools) are installed to `/usr/local/`
- **TIFF Tools**: Custom TIFF 3.9.7 tools with embedded compression libraries are installed to `/usr/local/bin/`
- **Static Libraries**: All compression libraries (libjpeg-turbo, zlib, jbigkit) are built as optimized static libraries and remain in temporary build directories
- **No X11 Dependencies**: Headless server build with no GUI or X11 libraries required
- **System Integration**: TIFF tools are available system-wide and integrated with HylaFAX+ automatically
- **Minimal System Impact**: No unnecessary files installed to system directories

## Troubleshooting

### If Build Fails
1. Check you're not running as root
2. Ensure you have sudo privileges
3. Make sure you have internet connection for package downloads

### If Setup Fails with Sendmail Error
```bash
# Install sendmail if faxsetup complains about missing /usr/lib/sendmail
sudo dnf install -y sendmail sendmail-cf
```

### If Setup Asks for Modem
- This is normal for a complete fax server setup
- For testing without hardware modems, you can skip modem configuration
- Press Ctrl+C if setup gets stuck asking for serial ports
- Or run automated setup: `printf "yes\nyes\nno\nno\n" | sudo /usr/local/sbin/faxsetup`

### If Services Don't Start
```bash
# Check service status
sudo systemctl status hylafax

# Start services manually if systemctl fails
sudo /usr/local/sbin/faxq &
sudo /usr/local/sbin/hfaxd -i hylafax &

# Check processes
ps aux | grep -E "faxq|hfaxd" | grep -v grep
```

### If Client Commands Ask for Password
- This is normal - HylaFAX+ requires authentication
- Check `/var/spool/hylafax/etc/hosts.hfaxd` for allowed hosts
- For testing, ensure `localhost` and `127.0.0.1` are listed

### How to Disable Email Notifications After Setup

If you want to disable email notifications after HylaFAX+ is set up and running:

```bash
# Method 1: Replace notification scripts with no-op versions
sudo cp /bin/true /var/spool/hylafax/bin/notify
sudo cp /bin/true /var/spool/hylafax/bin/faxrcvd
sudo cp /bin/true /var/spool/hylafax/bin/pollrcvd

# Method 2: Edit notification scripts to disable email sending
sudo sed -i 's/^SENDMAIL=.*/SENDMAIL=\/bin\/true/' /var/spool/hylafax/bin/notify
sudo sed -i 's/^SENDMAIL=.*/SENDMAIL=\/bin\/true/' /var/spool/hylafax/bin/faxrcvd

# Method 3: Disable notifications in modem config files (if modems are configured)
# Edit any config files in /var/spool/hylafax/etc/config.* and add:
# NotifyCmd: /bin/true

# Method 4: Stop and disable sendmail service (optional)
sudo systemctl stop sendmail
sudo systemctl disable sendmail

# Restart HylaFAX+ services to apply changes
sudo systemctl restart hylafax
```

**Note:** Sendmail is still required for initial setup, but email notifications can be safely disabled afterward without affecting fax functionality.

## What Gets Installed

**System Directories:**
- **HylaFAX+ binaries:** `/usr/local/sbin/` (faxq, hfaxd, faxsetup, etc.)
- **HylaFAX+ client tools:** `/usr/local/bin/` (sendfax, faxstat, etc.)
- **TIFF 3.9.7 tools:** `/usr/local/bin/` (tiffinfo, tiff2ps, tiffcp, etc.)
- **Configuration files:** `/usr/local/etc/hylafax/`
- **Spool directory:** `/var/spool/hylafax/`
- **Runtime utilities:** System packages (ghostscript, netpbm-progs)

**Temporary Build Directory (not in system):**
- **libjpeg-turbo libraries:** Optimized static libraries for JPEG compression
- **zlib libraries:** Optimized static libraries for ZIP/Deflate compression
- **jbigkit libraries:** Optimized static libraries for JBIG bi-level compression
- **TIFF 3.9.7 libraries:** Static libraries (libtiff.a with all compression embedded)
- **Development headers:** Include files for all compression libraries

**Note:** Only essential executables are installed to system directories. All compression libraries are statically linked and embedded in TIFF, with source artifacts remaining in temporary directories.

## System Requirements

- Rocky Linux 9.x/10.x
- At least 2GB RAM
- 1GB free disk space
- Internet connection for package downloads
- Regular user account with sudo privileges
- Development tools (automatically installed by script):
  - GCC/G++ 14.2.1+
  - CMake (for libjpeg-turbo build)
  - NASM (for SIMD optimizations)
  - Autotools (for library builds)
- Runtime utilities (automatically installed):
  - Ghostscript (document conversion)
  - NetPBM (image processing)
  - Sendmail (required for setup, email notifications can be disabled later)

## Quick Setup Verification

After completing the setup, verify everything is working:

```bash
# 1. Check services are running
sudo systemctl status hylafax
ps aux | grep -E "faxq|hfaxd" | grep -v grep

# 2. Verify static binaries
ldd /usr/local/sbin/faxmodem  # Should show "not a dynamic executable"

# 3. Test TIFF tools
/usr/local/bin/tiffinfo -v 2>&1 | head -3  # Should show "LIBTIFF, Version 3.9.7"

# 4. Check HylaFAX+ installation
ls -la /usr/local/sbin/fax* | wc -l  # Should show multiple fax binaries

# 5. Verify spool directory ownership
ls -ld /var/spool/hylafax  # Should be owned by uucp:uucp
```

**Expected Results:**
- ✅ Services: `faxq` and `hfaxd` running as uucp user
- ✅ Binaries: All executables are statically linked
- ✅ TIFF: Version 3.9.7 with embedded compression libraries
- ✅ Access: Proper file ownership and permissions

## Support

This build includes all necessary patches for Rocky Linux 9.x compatibility:
- Modern GCC/G++ 14.2.1 support  
- C++17 standard compliance
- System library compatibility
- libjpeg-turbo 3.0.4 with SIMD acceleration
- zlib 1.3.1 for ZIP/Deflate compression
- jbigkit 2.1 for JBIG bi-level compression
- TIFF 3.9.7 static linking with all compression libraries embedded
- Headless server operation (no X11 dependencies)

For issues, check the build log output and ensure all dependencies were installed correctly.