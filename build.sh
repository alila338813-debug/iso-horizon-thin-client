#!/bin/bash
set -e

echo "[+] Horizon Thin Client ISO Builder"
echo "[+] Using manual build method (no live-build)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run as root or with sudo"
    exit 1
fi

# Configuration
CHROOT_DIR="/tmp/horizon-chroot"
ISO_DIR="/tmp/iso"
ISO_NAME="horizon-thin-client.iso"
UBUNTU_VERSION="noble"
UBUNTU_MIRROR="https://archive.ubuntu.com/ubuntu/"

echo "[+] Installing required tools..."
apt update
apt install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    syslinux-utils \
    isolinux \
    grub-pc \
    wget \
    mtools

echo "[+] Checking for Horizon Client .deb..."
if [ ! -f config/packages.chroot/VMware-Horizon-Client-*.deb ]; then
    echo "[!] ERROR: Horizon Client .deb not found in config/packages.chroot/"
    echo "[!] Please download it and place in config/packages.chroot/"
    exit 1
fi

echo "[+] Creating chroot environment at $CHROOT_DIR..."
mkdir -p "$CHROOT_DIR"

# Bootstrap Ubuntu 24.04
debootstrap \
    --arch=amd64 \
    "$UBUNTU_VERSION" \
    "$CHROOT_DIR" \
    "$UBUNTU_MIRROR"

echo "[+] Configuring chroot..."

# Mount required filesystems
mount -t proc proc "$CHROOT_DIR/proc"
mount -t sysfs sys "$CHROOT_DIR/sys"
mount -o bind /dev "$CHROOT_DIR/dev"

# Copy Horizon Client to chroot
cp config/packages.chroot/VMware-Horizon-Client-*.deb "$CHROOT_DIR/tmp/"

# Create setup script
cat > "$CHROOT_DIR/tmp/setup.sh" << 'EOF'
#!/bin/bash
set -e

echo "[chroot] Configuring system..."

# Configure apt sources
cat > /etc/apt/sources.list << "SOURCES_EOF"
deb https://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb https://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb https://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
SOURCES_EOF

# Update package lists
apt-get update

# Install packages from list
echo "[chroot] Installing packages..."
while read pkg; do
    if [ -n "$pkg" ]; then
        echo "[chroot] Installing: $pkg"
        apt-get install -y --no-install-recommends "$pkg" || echo "[chroot] Warning: Failed to install $pkg"
    fi
done < /tmp/packages.list

# Install Horizon Client
echo "[chroot] Installing Horizon Client..."
dpkg -i /tmp/VMware-Horizon-Client-*.deb || apt-get install -f -y

# Create user
echo "[chroot] Creating horizon user..."
useradd -m -s /bin/bash horizon
echo "horizon:horizon" | chpasswd
usermod -aG sudo horizon

# Enable autologin for tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << "AUTOLOGIN_EOF"
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin horizon --noclear %I $TERM
AUTOLOGIN_EOF

# Configure Weston to start automatically
cat > /etc/systemd/system/weston.service << "WESTON_EOF"
[Unit]
Description=Weston Wayland compositor
After=systemd-user-sessions.service network.target

[Service]
User=horizon
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=WAYLAND_DISPLAY=wayland-1
ExecStart=/usr/bin/weston --backend=drm-backend.so --tty=1
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
WESTON_EOF

systemctl enable weston.service

# Clean up
echo "[chroot] Cleaning up..."
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*
EOF

# Copy package list and setup script
cp config/package-lists/horizon.list.chroot "$CHROOT_DIR/tmp/packages.list"
chmod +x "$CHROOT_DIR/tmp/setup.sh"

# Copy existing config files
if [ -d "config/includes.chroot" ]; then
    echo "[+] Copying additional configuration files..."
    cp -r config/includes.chroot/* "$CHROOT_DIR/" 2>/dev/null || true
fi

# Run setup in chroot
echo "[+] Running setup in chroot..."
chroot "$CHROOT_DIR" /tmp/setup.sh

# Unmount filesystems
echo "[+] Unmounting chroot filesystems..."
umount "$CHROOT_DIR/dev"
umount "$CHROOT_DIR/sys"
umount "$CHROOT_DIR/proc"

echo "[+] Preparing ISO filesystem..."
rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR"/{boot/grub,casper,isolinux}

# Create squashfs filesystem
echo "[+] Creating squashfs filesystem..."
mksquashfs "$CHROOT_DIR" "$ISO_DIR/casper/filesystem.squashfs" -comp xz -noappend

# Copy kernel and initrd
echo "[+] Copying kernel and initrd..."
KERNEL=$(ls "$CHROOT_DIR/boot"/vmlinuz-* 2>/dev/null | head -1)
INITRD=$(ls "$CHROOT_DIR/boot"/initrd.img-* 2>/dev/null | head -1)

if [ -f "$KERNEL" ]; then
    cp "$KERNEL" "$ISO_DIR/casper/vmlinuz"
    echo "[+] Kernel: $(basename "$KERNEL")"
else
    echo "[!] Warning: No kernel found"
fi

if [ -f "$INITRD" ]; then
    cp "$INITRD" "$ISO_DIR/casper/initrd"
    echo "[+] Initrd: $(basename "$INITRD")"
else
    echo "[!] Warning: No initrd found"
fi

# Copy boot files
echo "[+] Setting up boot configuration..."
cp /usr/lib/ISOLINUX/isolinux.bin "$ISO_DIR/isolinux/" 2>/dev/null || cp /usr/lib/syslinux/isolinux.bin "$ISO_DIR/isolinux/"
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "$ISO_DIR/isolinux/" 2>/dev/null || cp /usr/lib/syslinux/ldlinux.c32 "$ISO_DIR/isolinux/"

# Create isolinux config
cat > "$ISO_DIR/isolinux/isolinux.cfg" << 'EOF'
DEFAULT live
LABEL live
  menu label ^Horizon Thin Client
  kernel /casper/vmlinuz
  append initrd=/casper/initrd boot=casper quiet splash --
PROMPT 0
TIMEOUT 50
EOF

# Create GRUB config (BIOS only)
cat > "$ISO_DIR/boot/grub/grub.cfg" << 'EOF'
set default=0
set timeout=5

menuentry "Horizon Thin Client" {
  linux /casper/vmlinuz boot=casper quiet splash --
  initrd /casper/initrd
}
EOF

# Create disk info
mkdir -p "$ISO_DIR/.disk"
echo "Horizon Thin Client 24.04" > "$ISO_DIR/.disk/info"

echo "[+] Creating bootable ISO..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "HORIZON_TC" \
    -output "$ISO_NAME" \
    -eltorito-boot isolinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    "$ISO_DIR"

# Make hybrid for USB
if command -v isohybrid >/dev/null 2>&1; then
    echo "[+] Making ISO hybrid for USB..."
    isohybrid --entry 4 --type 0x00 "$ISO_NAME"
else
    echo "[!] isohybrid not found, creating regular ISO"
fi

echo "[✓] Build completed!"
echo "[✓] ISO: $ISO_NAME ($(du -h "$ISO_NAME" | cut -f1))"
echo "[✓] File info:"
file "$ISO_NAME"
