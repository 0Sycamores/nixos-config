#!/usr/bin/env bash

set -e # 遇到错误即停止

# --- 配置 ---
REPO_URL="https://github.com/0Sycamores/nixos-config"
TARGET_DIR="/tmp/nixos-install"

# --- 颜色 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 清除颜色

echo -e "${GREEN}=== NixOS Multi-Host Installer ===${NC}"

# --- 1. 准备环境 ---
echo -e "\n${GREEN}[1/8] Preparing environment...${NC}"

# 检查是否处于 NixOS 安装环境
if [ ! -e /etc/NIXOS ]; then
    echo -e "${RED}Warning: It seems you are not in the NixOS ISO environment. This script is intended for bare metal installation.${NC}"
    echo -ne "Confirm to continue? (yes/no): "
    read CONFIRM
    if [ "$CONFIRM" != "yes" ]; then exit 1; fi
fi

# 检查网络
if ping -c 1 baidu.com &> /dev/null; then
    echo "Internet connection is normal."
else
    echo -e "${RED}Unable to connect to the internet. Please configure the network first (nmcli / wpa_supplicant).${NC}"
    exit 1
fi

# 询问是否配置 HTTP 代理
echo -e "\nDo you need to configure an HTTP proxy to speed up GitHub access?"
echo -ne "Please enter proxy address (e.g. 192.168.1.100:7890 or http://192.168.1.100:7890, leave empty to skip): "
read PROXY_ADDR

if [ -n "$PROXY_ADDR" ]; then
    if [[ "$PROXY_ADDR" != http://* ]] && [[ "$PROXY_ADDR" != https://* ]]; then
        PROXY_ADDR="http://$PROXY_ADDR"
    fi
    export http_proxy="$PROXY_ADDR"
    export https_proxy="$PROXY_ADDR"
    echo "Proxy set: $PROXY_ADDR"

    echo "Testing GitHub connectivity..."
    if curl -s --head --connect-timeout 5 https://github.com > /dev/null; then
        echo -e "${GREEN}GitHub connection successful!${NC}"
    else
        echo -e "${RED}GitHub connection failed!${NC}"
        echo -ne "Do you want to continue anyway? [y/N]: "
        read CONTINUE
        if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
            exit 1
        fi
    fi
fi

# 启用 Flakes
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf << EOF
experimental-features = nix-command flakes
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/
EOF

# --- 2. 拉取配置 ---
echo -e "\n${GREEN}[2/8] Fetching configuration...${NC}"

echo "Preparing to clone configuration from GitHub..."
if [ -d "$TARGET_DIR" ]; then
    echo "Cleaning up old directory $TARGET_DIR ..."
    rm -rf $TARGET_DIR
fi

# 使用 git clone 拉取代码
nix shell nixpkgs#git --command git clone $REPO_URL $TARGET_DIR
cd $TARGET_DIR

# --- 3. 选择主机 ---
echo -e "\n${GREEN}[3/8] Select target host${NC}"
echo "Available host configurations (hosts/):"

# 获取 hosts 目录下的子目录
HOSTS=($(ls hosts))

# 显示菜单
i=1
for host in "${HOSTS[@]}"; do
    echo "$i) $host"
    let i++
done

echo -ne "Please enter the number to select a host: "
read HOST_INDEX

# 验证输入
if [[ ! "$HOST_INDEX" =~ ^[0-9]+$ ]] || [ "$HOST_INDEX" -lt 1 ] || [ "$HOST_INDEX" -gt "${#HOSTS[@]}" ]; then
    echo -e "${RED}Error: Invalid selection${NC}"
    exit 1
fi

# 获取选中的主机名
SELECTED_HOST=${HOSTS[$((HOST_INDEX-1))]}
echo -e "Selected host: ${GREEN}$SELECTED_HOST${NC}"

# 检查 disko 配置是否存在
if [ ! -f "hosts/$SELECTED_HOST/disko.nix" ]; then
    echo -e "${RED}Error: hosts/$SELECTED_HOST/disko.nix does not exist.${NC}"
    echo "This host might not support automatic partitioning installation, or configuration is incomplete."
    exit 1
fi

# --- 4. 选择磁盘 ---
echo -e "\n${GREEN}[4/8] Select target disk${NC}"
lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep "disk"
echo -ne "Please enter target disk name (e.g., sda or nvme0n1): "
read DISK_NAME
TARGET_DISK="/dev/$DISK_NAME"

if [ ! -b "$TARGET_DISK" ]; then
    echo -e "${RED}Error: Device $TARGET_DISK not found${NC}"
    exit 1
fi

# Check for Windows partitions (NTFS)
if lsblk "$TARGET_DISK" -o FSTYPE | grep -q -i "ntfs"; then
    echo -e "${RED}⚠️  POTENTIAL WINDOWS SYSTEM DETECTED ON $TARGET_DISK!${NC}"
    echo -e "${RED}   Found NTFS partition(s). Installing NixOS will ERASE EVERYTHING including Windows.${NC}"
fi

echo -e "${RED}Warning: All data on $TARGET_DISK will be cleared!${NC}"
echo -ne "Confirm to continue? (yes/no): "
read CONFIRM_DISK
if [ "$CONFIRM_DISK" != "yes" ]; then
    echo "Cancelled."
    exit 1
fi

# --- 5. 注入配置 ---
echo -e "\n${GREEN}[5/8] Injecting hardware configuration...${NC}"

# 修改 Disko 配置中的磁盘设备
# 匹配 device = "..."; 并替换
sed -i "s|device = \".*\";|device = \"$TARGET_DISK\";|" hosts/$SELECTED_HOST/disko.nix
echo "Installation target set to $TARGET_DISK"

# --- 6. 分区和格式化 ---
echo -e "\n${GREEN}[6/8] Executing Disko partitioning...${NC}"
nix run .#disko -- --mode disko ./hosts/$SELECTED_HOST/disko.nix

# --- 7. 安装 ---
echo -e "\n${GREEN}[7/8] Generating hardware config and installing...${NC}"

# 生成 hardware-configuration.nix
nixos-generate-config --root /mnt --no-filesystems --show-hardware-config > hosts/$SELECTED_HOST/hardware.nix
git add hosts/$SELECTED_HOST/hardware.nix

echo "Starting NixOS installation ($SELECTED_HOST)..."
nixos-install --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" --root /mnt --flake .#$SELECTED_HOST

echo -e "\n${GREEN}=== Installation Complete! ===${NC}"

# --- 8. 设置用户密码 ---
echo -e "\n${GREEN}[8/8] Set user password${NC}"
TARGET_USER=$(nixos-enter --root /mnt -c 'getent passwd' | awk -F: '$3 == 1000 {print $1}')

if [ -n "$TARGET_USER" ]; then
    for ((i=1; i<=3; i++)); do
        echo -e "\nPlease set password for user ${GREEN}$TARGET_USER${NC} (Attempt $i/3):"
        if nixos-enter --root /mnt -c "passwd $TARGET_USER"; then
            break
        else
            echo -e "${RED}Failed to set password.${NC}"
            if [ $i -eq 3 ]; then
                 echo -e "${RED}Max retries reached. Skipped setting password for $TARGET_USER.${NC}"
            fi
        fi
    done
fi

echo -e "\n${GREEN}You can type 'reboot' to restart into the new system.${NC}"