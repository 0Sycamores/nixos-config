#!/usr/bin/env bash
set -e

# --- 配置区 ---
# ⚠️⚠️⚠️ 请修改下面这行！改为你的仓库地址 ⚠️⚠️⚠️
REPO_URL="https://nixos.sycamore.icu/https://github.com/0Sycamore/nixos-config"
TARGET_DIR="/tmp/nixos-install"

# --- 颜色 ---
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}>>> 开始 NixOS 自动化安装流程...${NC}"

# 1. 准备环境
echo -e "${GREEN}>>> 正在启用 Flakes...${NC}"
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 2. 拉取代码
echo -e "${GREEN}>>> 正在从 GitHub 克隆配置...${NC}"
rm -rf $TARGET_DIR
# 使用 git clone 拉取代码
nix shell nixpkgs#git --command git clone $REPO_URL $TARGET_DIR
cd $TARGET_DIR

# 3. 询问配置
echo -e "${GREEN}>>> 请选择安装目标硬盘:${NC}"
lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep disk
read -p "输入设备名 (如 /dev/sda): " DISK_DEV

read -p "输入新主机名 (默认: nixos): " NEW_HOSTNAME
NEW_HOSTNAME=${NEW_HOSTNAME:-nixos}

echo -e "${GREEN}>>> 警告: $DISK_DEV 将被格式化！(5秒后开始)${NC}"
sleep 5

# 4. 替换占位符 (Magic)
echo -e "${GREEN}>>> 正在注入配置...${NC}"
sed -i "s|__DISK_DEVICE__|$DISK_DEV|g" hosts/template/disko.nix
sed -i "s|__HOSTNAME__|$NEW_HOSTNAME|g" hosts/template/default.nix

# 5. 分区 (Disko)
echo -e "${GREEN}>>> 执行 Disko 分区...${NC}"
nix run github:nix-community/disko -- --mode disko ./hosts/template/disko.nix

# 6. 生成硬件配置
echo -e "${GREEN}>>> 生成 hardware-configuration.nix...${NC}"
nixos-generate-config --root /mnt --show-hardware-config > hosts/template/hardware.nix

# 7. 安装
echo -e "${GREEN}>>> 开始安装 NixOS...${NC}"
nixos-install --root /mnt --flake .#new-machine

echo -e "${GREEN}>>> 安装完成！请拔掉 ISO 并重启。${NC}"