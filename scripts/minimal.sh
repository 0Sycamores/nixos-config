#!/usr/bin/env bash

set -e # 遇到错误立即停止

# --- 配置区 ---
PROXY_URL="https://nixos.sycamore.icu"
REPO_URL="https://github.com/0Sycamores/nixos-config"
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
    echo "互联网连接正常。"
else
    echo -e "${RED}无法连接互联网，请先配置网络 (nmcli / wpa_supplicant)。${NC}"
    exit 1
fi

# 检查 GitHub 连接并配置代理
check_github() {
    echo -ne "正在检查 GitHub 连接... "
    # 使用 curl 检查，超时设置为 5 秒
    if curl -s --connect-timeout 5 https://github.com > /dev/null; then
        echo -e "${GREEN}成功${NC}"
        return 0
    else
        echo -e "${RED}失败${NC}"
        return 1
    fi
}

if ! check_github; then
    echo -e "${RED}无法连接 GitHub，NixOS 安装需要下载 Flake inputs。${NC}"
    echo -e "请选择解决方案："
    echo -e "1) 配置 HTTP 代理 (推荐，例如: http://192.168.1.100:7890)"
    echo -e "2) 使用 gh-proxy.org 镜像 (无需代理，自动修改配置文件)"
    echo -e "3) 跳过 (可能会失败)"
    echo -ne "请输入选项 [1-3]: "
    read NET_CHOICE

    case "$NET_CHOICE" in
        1)
            echo -ne "请输入代理地址: "
            read PROXY_ADDR
            if [ -n "$PROXY_ADDR" ]; then
                export http_proxy="$PROXY_ADDR"
                export https_proxy="$PROXY_ADDR"
                echo "已设置代理: $PROXY_ADDR"
                if ! check_github; then
                    echo -e "${RED}错误: 配置代理后仍无法连接 GitHub。${NC}"
                    exit 1
                fi
            fi
            ;;
        2)
            echo ">>> 将使用 https://gh-proxy.org/ 加速下载 (仅用于 flake.nix inputs)..."
            USE_MIRROR=true
            ;;
        *)
            echo -e "${RED}警告: 未采取措施，后续步骤可能会失败。${NC}"
            ;;
    esac
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

if [ "$USE_MIRROR" = "true" ]; then
    echo ">>> 正在应用 GitHub 镜像配置到 flake.nix..."
    # 替换 nixpkgs 源
    sed -i 's|url = "github:nixos/nixpkgs/nixos-25.11"|url = "git+https://gh-proxy.org/https://github.com/nixos/nixpkgs?ref=nixos-25.11"|g' flake.nix
    # 替换 disko 源
    sed -i 's|url = "github:nix-community/disko"|url = "git+https://gh-proxy.org/https://github.com/nix-community/disko"|g' flake.nix
fi

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