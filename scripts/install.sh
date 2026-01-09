#!/usr/bin/env bash
#
# NixOS 多主机安装程序
#
# 此脚本通过从 Git 仓库拉取配置、分区磁盘并安装系统，
# 在目标机器上安装 NixOS。
# 旨在在裸机 NixOS ISO 环境中运行。

set -e

# --- 配置 ---
readonly REPO_URL="https://github.com/0Sycamores/nixos-config"
readonly TARGET_DIR="/tmp/nixos-install"

# --- 颜色 ---
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

# --- 全局状态 ---
# 这些变量维护跨函数的状态
SELECTED_HOST=""
TARGET_DISK=""

# --- 日志辅助函数 ---

#######################################
# 打印标准信息到 stdout。
# 参数:
#   要打印的消息。
#######################################
info() {
    printf "%s\n" "$*"
}

#######################################
# 打印绿色成功消息。
# 参数:
#   要打印的消息。
#######################################
success() {
    printf "${GREEN}%s${NC}\n" "$*"
}

#######################################
# 打印红色错误消息到 stderr。
# 参数:
#   要打印的消息。
#######################################
err() {
    printf "${RED}%s${NC}\n" "$*" >&2
}

#######################################
# 打印带前置换行符的绿色部分标题（步骤）。
# 参数:
#   要打印的消息。
#######################################
step() {
    printf "\n${GREEN}%s${NC}\n" "$*"
}

#######################################
# 在退出或出错时运行的清理函数。
# 如果需要，递归卸载 /mnt 以使系统处于干净状态。
# 局部变量:
#   exit_code: 脚本的退出代码。
#######################################
cleanup() {
    local exit_code=$?
    if [[ "${exit_code}" -ne 0 ]]; then
        printf "\n" >&2
        err "❌ Script exited with error code ${exit_code}."
        err "Cleaning up..."

        # 检查 /mnt 是否已挂载
        if grep -qs "/mnt" /proc/mounts; then
            info "⚠️  The system is still mounted at /mnt for debugging."
            info "   You can unmount it manually by running: umount -R /mnt"
        fi
        
        err "Cleanup complete."
    fi
}

#######################################
# 步骤 1: 准备环境。
# 检查是否在 NixOS 中运行，检查互联网连接，
# 配置可选代理，并启用 Nix flakes。
#######################################
prepare_environment() {
    step "[1/8] Preparing environment..."

    # 检查是否在 NixOS 环境中 (基本检查 /etc/NIXOS)
    if [[ ! -e /etc/NIXOS ]]; then
        err "Warning: It seems you are not in the NixOS ISO environment. This script is intended for bare metal installation."
        read -r -p "Confirm to continue? (yes/no): " confirm
        if [[ "${confirm}" != "yes" ]]; then
            exit 1
        fi
    fi

    # 检查网络连接
    if ping -c 1 baidu.com &> /dev/null; then
        info "Internet connection is normal."
    else
        err "Unable to connect to the internet. Please configure the network first (nmcli / wpa_supplicant)."
        exit 1
    fi

    # 配置 HTTP 代理
    printf "\n"
    info "Do you need to configure an HTTP proxy to speed up GitHub access?"
    read -r -p "Please enter proxy address (e.g. 192.168.1.100:7890 or http://192.168.1.100:7890, leave empty to skip): " proxy_addr

    if [[ -n "${proxy_addr}" ]]; then
        # 如果缺少 http:// 则自动添加
        if [[ "${proxy_addr}" != http://* ]] && [[ "${proxy_addr}" != https://* ]]; then
            proxy_addr="http://${proxy_addr}"
        fi
        export http_proxy="${proxy_addr}"
        export https_proxy="${proxy_addr}"
        info "Proxy set: ${proxy_addr}"
    fi

    info "Testing GitHub connectivity..."
    if curl -s --head --connect-timeout 5 https://github.com > /dev/null; then
        success "GitHub connection successful!"
    else
        err "GitHub connection failed!"
        read -r -p "Do you want to continue anyway? [y/N]: " continue_anyway
        if [[ "${continue_anyway}" != "y" && "${continue_anyway}" != "Y" ]]; then
            exit 1
        fi
    fi

    # 启用 Flakes
    mkdir -p ~/.config/nix
    cat > ~/.config/nix/nix.conf << EOF
experimental-features = nix-command flakes
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/
EOF
}

#######################################
# 步骤 2: 拉取配置。
# 将 Git 仓库克隆到目标目录。
#######################################
fetch_configuration() {
    step "[2/8] Fetching configuration..."

    info "Preparing to clone configuration from GitHub..."
    if [[ -d "${TARGET_DIR}" ]]; then
        info "Cleaning up old directory ${TARGET_DIR} ..."
        rm -rf "${TARGET_DIR}"
    fi

    # 使用 nix shell 中的 git 克隆，确保 git 可用
    nix shell nixpkgs#git --command git clone "${REPO_URL}" "${TARGET_DIR}"
    
    # 切换到下载的仓库目录以进行后续操作
    cd "${TARGET_DIR}" || exit 1
}

#######################################
# 步骤 3: 选择目标主机。
# 列出 'hosts/' 目录下的可用主机并提示用户选择。
# 设置全局 SELECTED_HOST。
#######################################
select_host() {
    step "[3/8] Select target host"
    info "Available host configurations (hosts/):"

    if [[ ! -d "hosts" ]]; then
        err "Error: 'hosts' directory not found in ${TARGET_DIR}"
        exit 1
    fi

    # 将 hosts 读取到数组中
    local hosts=($(ls hosts))
    local i=1
    local host

    for host in "${hosts[@]}"; do
        info "$i) $host"
        ((i++))
    done

    while true; do
        read -r -p "Please enter the number to select a host: " host_index
        
        # 验证输入
        if [[ "${host_index}" =~ ^[0-9]+$ ]] && [[ "${host_index}" -ge 1 ]] && [[ "${host_index}" -le "${#hosts[@]}" ]]; then
            break
        else
            err "Error: Invalid selection, please try again."
        fi
    done

    # 设置全局选中主机
    SELECTED_HOST="${hosts[$((host_index-1))]}"
    info "Selected host: ${GREEN}${SELECTED_HOST}${NC}"

    # 检查 disko 配置是否存在
    if [[ ! -f "hosts/${SELECTED_HOST}/disko.nix" ]]; then
        err "Error: hosts/${SELECTED_HOST}/disko.nix does not exist."
        info "This host might not support automatic partitioning installation, or configuration is incomplete."
        exit 1
    fi
}

#######################################
# 步骤 4: 选择目标磁盘。
# 列出物理磁盘并提示用户选择一个。
# 检查现有的 Windows 分区以警告用户。
# 设置全局 TARGET_DISK。
#######################################
select_disk() {
    step "[4/8] Select target disk"
    lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep "disk"
    
    while true; do
        read -r -p "Please enter target disk name (e.g., sda or nvme0n1): " disk_name
        TARGET_DISK="/dev/${disk_name}"

        if [[ -b "${TARGET_DISK}" ]]; then
            break
        else
            err "Error: Device ${TARGET_DISK} not found, please try again."
        fi
    done

    # 检查 Windows 分区 (NTFS)
    if lsblk "${TARGET_DISK}" -o FSTYPE | grep -q -i "ntfs"; then
        err "⚠️  POTENTIAL WINDOWS SYSTEM DETECTED ON ${TARGET_DISK}!"
        err "   Found NTFS partition(s). Installing NixOS will ERASE EVERYTHING including Windows."
    fi

    err "Warning: All data on ${TARGET_DISK} will be cleared!"
    read -r -p "Confirm to continue? (yes/no): " confirm_disk
    if [[ "${confirm_disk}" != "yes" ]]; then
        info "Cancelled."
        exit 1
    fi
}

#######################################
# 步骤 5: 注入硬件配置。
# 将 disko.nix 中的磁盘设备替换为选定的目标磁盘。
#######################################
inject_hardware_config() {
    step "[5/8] Injecting hardware configuration..."

    # 修改 Disko 配置
    # 匹配 device = "..."; 并替换为实际目标磁盘
    sed -i "s|device = \".*\";|device = \"${TARGET_DISK}\";|" "hosts/${SELECTED_HOST}/disko.nix"
    info "Installation target set to ${TARGET_DISK}"
}

#######################################
# 步骤 6: 分区和格式化。
# 在 'disko' 模式下运行 disko 以应用分区和格式化。
#######################################
partition_and_format() {
    step "[6/8] Executing Disko partitioning..."
    # 使用 Flake 锁定的 Disko 版本
    # 使用明确的模式列表代替 --mode disko，以符合新版规范
    nix run .#disko -- --mode destroy,format,mount "./hosts/${SELECTED_HOST}/disko.nix"
}

#######################################
# 步骤 7: 恢复 SSH 密钥。
# 使用 rbw (Bitwarden CLI) 获取 SSH 主机密钥以保留身份。
#######################################
restore_ssh_keys() {
    step "[8/8] Restoring SSH Host Keys from Bitwarden..."

    # 确保目标目录存在
    mkdir -p /mnt/etc/ssh

    # 检查 rbw 是否已认证
    # 使用 nix shell 引入 pinentry-curses 以支持密码输入
    if ! nix shell nixpkgs#rbw nixpkgs#pinentry-curses --command rbw unlocked 2>/dev/null; then
        info "Please login to Bitwarden (rbw) to fetch the SSH key."

        read -r -p "Enter Bitwarden server URL (Leave empty for official server): " bw_url
        if [[ -z "${bw_url}" ]]; then
            bw_url="https://api.bitwarden.com"
        elif [[ "${bw_url}" != http://* ]] && [[ "${bw_url}" != https://* ]]; then
            bw_url="https://${bw_url}"
        fi

        read -r -p "Enter your Bitwarden email: " bw_email
        
        # 进入带有 rbw 和 pinentry-curses 的子 shell 让用户交互式登录
        # 并显式配置 pinentry 程序
        info "Configuring rbw..."
        nix shell nixpkgs#rbw nixpkgs#pinentry-curses --command bash -c "rbw config set base_url ${bw_url} && rbw config set email ${bw_email} && rbw config set pinentry pinentry-curses && echo 'Please enter your master password to login:' && rbw login"
    fi

    # 提示输入 Bitwarden 中的密钥项名称
    read -r -p "Enter the Bitwarden item name for ${SELECTED_HOST}'s SSH key: " bw_item_name

    # 获取密钥
    # 同样需要 pinentry-curses 环境，以防 agent 超时需要重新认证
    info "Fetching key '${bw_item_name}'..."

    local fetch_success=true

    # 获取私钥
    info "Fetching private key..."
    if nix shell nixpkgs#rbw nixpkgs#pinentry-curses --command rbw get "${bw_item_name}" -f private_key > /mnt/etc/ssh/ssh_host_ed25519_key; then
        if [[ ! -s /mnt/etc/ssh/ssh_host_ed25519_key ]]; then
            err "Error: Private key file is empty. Field 'private_key' might be missing in Bitwarden item."
            fetch_success=false
        fi
    else
        err "Error: Failed to execute rbw command for private key."
        fetch_success=false
    fi

    # 获取公钥
    info "Fetching public key..."
    if nix shell nixpkgs#rbw nixpkgs#pinentry-curses --command rbw get "${bw_item_name}" -f public_key > /mnt/etc/ssh/ssh_host_ed25519_key.pub; then
        if [[ ! -s /mnt/etc/ssh/ssh_host_ed25519_key.pub ]]; then
            err "Error: Public key file is empty. Field 'public_key' might be missing in Bitwarden item."
            fetch_success=false
        fi
    else
        err "Error: Failed to execute rbw command for public key."
        fetch_success=false
    fi

    if [[ "$fetch_success" == "true" ]]; then
        # 设置正确权限
        chmod 600 /mnt/etc/ssh/ssh_host_ed25519_key
        chmod 644 /mnt/etc/ssh/ssh_host_ed25519_key.pub
        success "SSH keys restored and permissions set."

        # 临时复制密钥到当前 ISO 环境，以便 sops-nix 在构建时可以解密 secrets
        info "Copying keys to current environment for sops-nix decryption..."
        cp /mnt/etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
        cp /mnt/etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
        # 确保当前环境也有正确权限
        chmod 600 /etc/ssh/ssh_host_ed25519_key
    else
        err "Failed to fetch keys properly!"
        err "You MUST manually copy the correct ssh_host_ed25519_key and .pub to /mnt/etc/ssh/ before rebooting!"
        err "Otherwise you will be locked out."
    fi
}

#######################################
# 步骤 8: 安装 NixOS。
# 生成 hardware-configuration.nix 并运行 nixos-install。
#######################################
install_nixos() {
    step "[8/8] Generating hardware config and installing..."

    # 生成 hardware.nix
    nixos-generate-config --root /mnt --no-filesystems --show-hardware-config > "hosts/${SELECTED_HOST}/hardware.nix"
    
    # 添加到 git 以便 flakes 可以看到它 (如果使用基于 git 的 flake 源)
    git add "hosts/${SELECTED_HOST}/hardware.nix"

    # 将配置复制到新系统
    # 按照惯例，放在 /etc/nixos 比较合适，因为这是 NixOS 的默认配置位置，且不会弄乱用户主目录
    step "Persisting configuration to /mnt/etc/nixos..."
    mkdir -p /mnt/etc/nixos
    # 使用 rsync 或 cp 复制，排除 .git 目录以减小体积（或者保留 git 以便后续版本控制，这里选择保留以便直接使用 git）
    cp -r . /mnt/etc/nixos/
    info "Configuration copied to /mnt/etc/nixos"

    info "Starting NixOS installation (${SELECTED_HOST})..."
    # 注意：这里使用 --flake /mnt/etc/nixos#... 来指向已经复制进去的配置
    # 这样可以确保安装的是最终持久化在磁盘上的那个版本
    nixos-install --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" --root /mnt --flake "/mnt/etc/nixos#${SELECTED_HOST}" --show-trace

    step "=== Installation Complete! ==="
}

#######################################
# 主执行入口点。
# 编排安装步骤。
#######################################
main() {
    # Set trap for cleanup on exit or interrupt
    trap cleanup EXIT INT TERM
    clear
    success "=== NixOS Multi-Host Installer ==="

    prepare_environment
    fetch_configuration
    select_host
    select_disk
    inject_hardware_config
    partition_and_format
    restore_ssh_keys
    install_nixos
    
    step "You can type 'reboot' to restart into the new system."
}

# Run main with all arguments
main "$@"