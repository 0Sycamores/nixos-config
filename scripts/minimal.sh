#!/usr/bin/env bash

set -e # 遇到错误立即停止

# --- 配置区 ---
PROXY_URL="https://nixos.sycamore.icu"
REPO_URL="$PROXY_URL/https://github.com/0Sycamores/nixos-config"
TARGET_DIR="/tmp/nixos-install"

# --- 颜色定义 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== NixOS 交互式安装向导 (Disko + Flakes) ===${NC}"

# --- 1. 准备环境 ---
echo -e "\n${GREEN}[1/6] 准备环境...${NC}"

# 检查网络
if ping -c 1 baidu.com &> /dev/null; then
    echo "网络正常。"
else
    echo -e "${RED}无法连接互联网，请先配置网络 (nmcli / wpa_supplicant)。${NC}"
    exit 1
fi

echo ">>> 正在启用 Flakes..."
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
# 配置 substituters 代理，加速二进制缓存下载 (使用 USTC 镜像)
echo "substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/" >> ~/.config/nix/nix.conf

echo ">>> 正在从 GitHub 克隆配置..."
rm -rf $TARGET_DIR
# 使用 git clone 拉取代码
nix shell nixpkgs#git --command git clone $REPO_URL $TARGET_DIR
cd $TARGET_DIR

# --- 2. 交互式收集信息 ---
echo -e "\n${GREEN}[2/6] 收集安装信息${NC}"

# 询问目标硬盘
lsblk -d -n -o NAME,SIZE,MODEL | grep -v "loop"
echo -ne "请输入目标硬盘设备名 (例如 sda 或 nvme0n1): "
read DISK_NAME
TARGET_DISK="/dev/$DISK_NAME"

if [ ! -b "$TARGET_DISK" ]; then
    echo -e "${RED}错误: 找不到设备 $TARGET_DISK${NC}"
    exit 1
fi

echo -e "${RED}警告: $TARGET_DISK 上的所有数据将被清空！${NC}"
echo -ne "确认继续吗? (yes/no): "
read CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "已取消。"
    exit 1
fi

# 询问主机名与用户名
echo -ne "请输入主机名 (Hostname) [默认: minimal]: "
read NEW_HOSTNAME
NEW_HOSTNAME=${NEW_HOSTNAME:-nixos}

echo -ne "请输入用户名 (Username) [默认: minimal]: "
read USERNAME
USERNAME=${USERNAME:-minimal}

# --- 3. 替换占位符 ---
echo -e "\n${GREEN}[3/6] 注入配置信息...${NC}"
sed -i "s|__DISK_DEVICE__|$TARGET_DISK|g" hosts/minimal/disko.nix
sed -i "s|__HOSTNAME__|$NEW_HOSTNAME|g" hosts/minimal/default.nix
sed -i "s|__USERNAME__|$USERNAME|g" hosts/minimal/default.nix

# --- 4. 执行分区与挂载 ---
echo -e "\n${GREEN}[4/6] 执行 Disko 分区...${NC}"
nix run github:nix-community/disko -- --mode disko ./hosts/minimal/disko.nix

# --- 5. 生成硬件配置 ---
echo -e "\n${GREEN}[5/6] 生成硬件配置...${NC}"
nixos-generate-config --root /mnt --no-filesystems > hosts/minimal/hardware.nix

# --- 6. 执行安装 ---
echo -e "\n${GREEN}[6/6] 开始安装 NixOS...${NC}"
# 使用 --option substituters 指定代理，确保安装过程中也能走代理 (使用 USTC 镜像)
nixos-install --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" --root /mnt --flake .#minimal

echo -e "\n${GREEN}=== 安装完成！ ===${NC}"
echo "请设置 root 密码："
nixos-enter --root /mnt -c 'passwd root'

echo -e "\n${GREEN}你可以输入 'reboot' 重启进入新系统了。${NC}"