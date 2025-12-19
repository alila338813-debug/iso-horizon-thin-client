# horizo-thin-client
name: Build Horizon Thin Client ISO
on: [workflow_dispatch]

jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          lfs: true

      # ✅ 关键1：先安装 live-build（否则 lb: command not found）
      - name: Install live-build and dependencies
        run: |
          sudo apt update
          sudo apt install -y live-build xorriso

      # ✅ 关键2：验证 lb 是否可用
      - name: Verify lb command
        run: |
          which lb
          lb --version

      - name: Verify Horizon .deb
        run: |
          ls -lh config/packages.chroot/
          [ -f config/packages.chroot/vmware-horizon-client_*.deb ] || { echo "❌ Missing .deb"; exit 1; }

      # ✅ 关键3：配置（现在 lb 已存在！）
      - name: Configure live-build (GRUB only)
        run: |
          lb config \
            --distribution jammy \
            --architectures amd64 \
            --bootloader grub \
            --syslinux-theme none \
            --gfxboot false \
            --archive-areas "main restricted universe multiverse" \
            --bootappend-live "boot=live quiet splash nomodeset"

      # ✅ 关键4：验证配置写入
      - name: Debug config
        run: grep -E "LB_BOOTLOADER|LB_SYSLINUX_THEME|LB_GFXBOOT" config/binary

      # ✅ 关键5：构建
      - name: Build ISO
        run: sudo lb build

      - name: Upload ISO
        uses: actions/upload-artifact@v4
        with:
          name: horizon-thin-client.iso
          path: live-image-amd64.hybrid.iso
