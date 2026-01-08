#!/usr/bin/env bash

set -e # 遇到错误即停止

# --- 配置 ---
REPO_URL="https://github.com/0Sycamores/nixos-config"
TARGET_DIR="/tmp/nixos-install"

# --- 颜色 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 清除颜色

# --- 错误处理与清理 ---
cleanup() {
    EXIT_CODE=$?
    if [ "$EXIT_CODE" -ne 0 ]; then
        echo -e "\n${RED}❌ Script exited with error code $EXIT_CODE.${NC}"
        echo -e "${RED}Cleaning up...${NC}"

        # 检查 /mnt 是否有挂载
        if grep -qs "/mnt" /proc/mounts; then
            echo "Unmounting /mnt..."
            # 尝试关闭 swap (防止锁住磁盘)
            swapoff -a || true
            # 使用 -R 递归卸载 /mnt 下的所有挂载点
            umount -R /mnt || echo -e "${RED}Warning: Failed to unmount /mnt.${NC}"
        fi
        
        echo -e "${RED}Cleanup complete.${NC}"
    fi
}
trap cleanup EXIT INT TERM

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

# 生成 hardware.nix
nixos-generate-config --root /mnt --no-filesystems --show-hardware-config > hosts/$SELECTED_HOST/hardware.nix
git add hosts/$SELECTED_HOST/hardware.nix

echo "Starting NixOS installation ($SELECTED_HOST)..."
nixos-install --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" --root /mnt --flake .#$SELECTED_HOST

echo -e "\n${GREEN}=== Installation Complete! ===${NC}"


# --- 8. 恢复 SSH 密钥 (通过 rbw) ---
echo -e "\n${GREEN}[8/8] Restoring SSH Host Keys from Bitwarden...${NC}"

# 确保目标目录存在
mkdir -p /mnt/etc/ssh

# 检查是否已登录 rbw，如果没有则提示登录
if ! nix run nixpkgs#rbw -- unlocked 2>/dev/null; then
    echo "Please login to Bitwarden (rbw) to fetch the SSH key."

    echo -ne "Enter Bitwarden server URL (Leave empty for official server): "
    read BW_URL
    if [ -z "$BW_URL" ]; then
        BW_URL="https://api.bitwarden.com"
    fi

    echo -ne "Enter your Bitwarden email: "
    read BW_EMAIL
    
    # 进入一个带有 rbw 的 shell 让用户登录
    echo "Configuring rbw..."
    nix shell nixpkgs#rbw -c bash -c "rbw config set base_url $BW_URL && rbw config set email $BW_EMAIL && echo 'Please enter your master password to login:' && rbw login"
fi

# 提示用户输入 Bitwarden 中的密钥项名称
echo -ne "Enter the Bitwarden item name for ${SELECTED_HOST}'s SSH key: "
read BW_ITEM_NAME

# 拉取密钥并写入目标位置
echo "Fetching key '$BW_ITEM_NAME'..."
if nix run nixpkgs#rbw -- get "$BW_ITEM_NAME" -f private_key > /mnt/etc/ssh/ssh_host_ed25519_key && \
   nix run nixpkgs#rbw -- get "$BW_ITEM_NAME" -f public_key > /mnt/etc/ssh/ssh_host_ed25519_key.pub; then
    # 设置正确权限
    chmod 600 /mnt/etc/ssh/ssh_host_ed25519_key
    chmod 644 /mnt/etc/ssh/ssh_host_ed25519_key.pub
    echo -e "${GREEN}SSH keys restored and permissions set.${NC}"
else
    echo -e "${RED}Failed to fetch keys! Please check the item name or your login status.${NC}"
    echo -e "${RED}You MUST manually copy the correct ssh_host_ed25519_key and .pub to /mnt/etc/ssh/ before rebooting!${NC}"
    echo -e "${RED}Otherwise you will be locked out.${NC}"
fi

echo -e "\n${GREEN}You can type 'reboot' to restart into the new system.${NC}"