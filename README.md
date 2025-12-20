# Horizon Thin Client ISO Builder

A tool to build a bootable Ubuntu-based ISO with VMware Horizon Client pre-installed for thin client deployments.

## Features

- **Ubuntu 24.04 (Noble)** base system
- **VMware Horizon Client** pre-installed
- **Weston Wayland** compositor as desktop environment
- **Auto-login** for the `horizon` user
- **BIOS boot** support (compatible with most hardware)
- **USB boot** ready (hybrid ISO)
- **Minimal footprint** with essential packages only

## Prerequisites

- Ubuntu 24.04 or similar Linux distribution
- Root/sudo access
- 10GB+ free disk space
- Internet connection for package downloads

## Quick Start

### 1. Download Horizon Client

First, download the VMware Horizon Client `.deb` package from the [official website](https://www.vmware.com/go/viewclients) and place it in:

```
config/packages.chroot/
```

The file should be named something like `VMware-Horizon-Client-*.deb`.

### 2. Build the ISO

```bash
# Make the build script executable
chmod +x build.sh

# Run as root (or with sudo)
sudo ./build.sh
```

The build process will:
1. Install required build tools
2. Create a chroot environment with Ubuntu 24.04
3. Install all necessary packages and Horizon Client
4. Configure auto-login and Weston
5. Create a bootable ISO image

### 3. Use the ISO

The resulting ISO `horizon-thin-client.iso` can be:
- **Burnt to DVD** for optical media boot
- **Written to USB** using `dd` or similar tools
- **Used in virtualization** (VMware, VirtualBox, etc.)

## GitHub Actions Build

The repository includes a GitHub Actions workflow that automatically builds the ISO on push or manual trigger:

1. Go to **Actions** → **🖥 Build Horizon Thin Client ISO**
2. Click **Run workflow**
3. Download the built ISO from the artifacts

## Customization

### Package List

Edit `config/package-lists/horizon.list.chroot` to add or remove packages.

### Configuration Files

Additional configuration files can be placed in `config/includes.chroot/` - they will be copied into the chroot during build.

### User Configuration

The default user is `horizon` with password `horizon`. To change this, modify the `build.sh` script.

## Technical Details

### Base System
- **Ubuntu**: 24.04 (noble)
- **Architecture**: amd64
- **Kernel**: Latest generic kernel from Ubuntu repositories
- **Init system**: systemd

### Desktop Environment
- **Display server**: Weston (Wayland)
- **Auto-start**: Weston starts automatically on boot
- **Session**: Auto-login to Weston session

### Network
- **NetworkManager** for network management
- **OpenSSH client** for remote access
- **Curl** for downloads

### Boot Configuration
- **Bootloader**: GRUB (BIOS only)
- **Boot options**: `boot=casper quiet splash`
- **ISO type**: Hybrid (bootable from both CD/DVD and USB)

## Troubleshooting

### Build Fails with "No kernel found"
This usually means the kernel package wasn't installed. Check that `linux-image-generic` is in the package list.

### ISO Doesn't Boot
- Ensure your system supports BIOS boot (not just UEFI)
- Try different USB creation tools (Rufus, Etcher, dd)
- Check ISO integrity with `md5sum`

### Horizon Client Issues
- Verify the `.deb` package is compatible with Ubuntu 24.04
- Check for missing dependencies in the package list
- Ensure network connectivity in the live environment

## Security Notes

⚠️ **Important**: This ISO is designed for testing and demonstration purposes.

- The default user `horizon` has password `horizon` and sudo access
- Auto-login is enabled for convenience
- For production use:
  - Change all default passwords
  - Disable auto-login if needed
  - Add firewall rules
  - Enable automatic security updates

## License

This project is provided as-is. VMware Horizon Client is proprietary software from VMware, Inc. Please ensure you comply with VMware's licensing terms when using their software.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the build
5. Submit a pull request

## Support

For issues with the build process, please open an issue on GitHub. For Horizon Client issues, refer to VMware's official documentation and support channels.