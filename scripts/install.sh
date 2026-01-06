#!/usr/bin/env bash

set -e # 遇到错误立即停止

# --- 配置区 ---
REPO_URL="https://github.com/0Sycamores/nixos-config"
TARGET_DIR="/tmp/nixos-install"

# --- 颜色定义 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== NixOS 多主机安装向导 ===${NC}"

# --- 1. 准备环境 ---
echo -e "\n${GREEN}[1/7] 准备环境...${NC}"

# 检查是否在 NixOS 安装环境中
if [ ! -e /etc/NIXOS ]; then
    echo -e "${RED}警告: 似乎不在 NixOS ISO 环境中。此脚本主要用于裸机安装。${NC}"
    echo -ne "确认继续吗? (yes/no): "
    read CONFIRM
    if [ "$CONFIRM" != "yes" ]; then exit 1; fi
fi

# 检查网络
if ping -c 1 baidu.com &> /dev/null; then
    echo "互联网连接正常。"
else
    echo -e "${RED}无法连接互联网，请先配置网络 (nmcli / wpa_supplicant)。${NC}"
    exit 1
fi

# 询问是否配置 HTTP 代理
echo -e "\n是否需要配置 HTTP 代理以加速 GitHub 访问? (建议国内用户配置)"
echo -ne "请输入代理地址 (例如 http://192.168.1.100:7890，留空则不配置): "
read PROXY_ADDR

if [ -n "$PROXY_ADDR" ]; then
    export http_proxy="$PROXY_ADDR"
    export https_proxy="$PROXY_ADDR"
    echo "已设置代理: $PROXY_ADDR"
fi

# 开启 Flakes
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf << EOF
experimental-features = nix-command flakes
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/
EOF

# --- 2. 获取配置 ---
echo -e "\n${GREEN}[2/7] 获取配置...${NC}"

echo "准备从 GitHub 克隆配置..."
if [ -d "$TARGET_DIR" ]; then
    echo "清理旧目录 $TARGET_DIR ..."
    rm -rf $TARGET_DIR
fi

# 使用 git clone 拉取代码
nix shell nixpkgs#git --command git clone $REPO_URL $TARGET_DIR
cd $TARGET_DIR

# --- 3. 选择主机 ---
echo -e "\n${GREEN}[3/7] 选择安装目标主机${NC}"
echo "可用主机配置 (hosts/):"

# 获取 hosts 目录下的子目录列表
HOSTS=($(ls hosts))

# 显示菜单
i=1
for host in "${HOSTS[@]}"; do
    echo "$i) $host"
    let i++
done

echo -ne "请输入序号选择主机: "
read HOST_INDEX

# 验证输入
if [[ ! "$HOST_INDEX" =~ ^[0-9]+$ ]] || [ "$HOST_INDEX" -lt 1 ] || [ "$HOST_INDEX" -gt "${#HOSTS[@]}" ]; then
    echo -e "${RED}错误: 无效的选择${NC}"
    exit 1
fi

# 获取选中的主机名
SELECTED_HOST=${HOSTS[$((HOST_INDEX-1))]}
echo -e "已选择主机: ${GREEN}$SELECTED_HOST${NC}"

# 检查 disko 配置是否存在
if [ ! -f "hosts/$SELECTED_HOST/disko.nix" ]; then
    echo -e "${RED}错误: hosts/$SELECTED_HOST/disko.nix 不存在。${NC}"
    echo "该主机可能不支持自动分区安装，或者配置尚未完成。"
    exit 1
fi

# --- 4. 选择硬盘 ---
echo -e "\n${GREEN}[4/7] 选择目标硬盘${NC}"
lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep "disk"
echo -ne "请输入目标硬盘设备名 (例如 sda 或 nvme0n1): "
read DISK_NAME
TARGET_DISK="/dev/$DISK_NAME"

if [ ! -b "$TARGET_DISK" ]; then
    echo -e "${RED}错误: 找不到设备 $TARGET_DISK${NC}"
    exit 1
fi

echo -e "${RED}警告: $TARGET_DISK 上的所有数据将被清空！${NC}"
echo -ne "确认继续吗? (yes/no): "
read CONFIRM_DISK
if [ "$CONFIRM_DISK" != "yes" ]; then
    echo "已取消。"
    exit 1
fi

# --- 5. 注入配置 ---
echo -e "\n${GREEN}[5/7] 注入硬件配置...${NC}"

# 修改 Disko 配置中的磁盘设备
# 匹配 device = "..."; 并替换
sed -i "s|device = \".*\";|device = \"$TARGET_DISK\";|" hosts/$SELECTED_HOST/disko.nix
echo "已将安装目标设置为 $TARGET_DISK"

# --- 6. 分区与格式化 ---
echo -e "\n${GREEN}[6/7] 执行 Disko 分区...${NC}"
nix run .#disko -- --mode disko ./hosts/$SELECTED_HOST/disko.nix

# --- 7. 安装 ---
echo -e "\n${GREEN}[7/7] 生成硬件配置并安装...${NC}"

# 生成 hardware-configuration.nix
nixos-generate-config --root /mnt --no-filesystems --show-hardware-config > hosts/$SELECTED_HOST/hardware.nix
git add hosts/$SELECTED_HOST/hardware.nix

echo "开始安装 NixOS ($SELECTED_HOST)..."
nixos-install --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" --root /mnt --flake .#$SELECTED_HOST

echo -e "\n${GREEN}=== 安装完成！ ===${NC}"
echo "请设置 root 密码："
nixos-enter --root /mnt -c 'passwd root'

echo -e "\n${GREEN}您可以输入 'reboot' 重启进入新系统了。${NC}"