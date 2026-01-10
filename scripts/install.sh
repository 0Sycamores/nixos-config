#!/usr/bin/env bash
#
# ======================================================================================
# NixOS Multi-Host Automated Installer / NixOS 多主机自动化安装程序
# ======================================================================================
#
# 描述 (Description):
#   此脚本用于在裸机环境下自动化安装 NixOS。它设计用于官方 NixOS ISO 环境。
#   主要功能包括：
#   1. 环境准备：检测网络、配置代理、启用 Flakes。
#   2. 配置拉取：自动从 GitHub 克隆最新的 NixOS 配置仓库。
#   3. 主机选择：动态解析 `hosts/` 目录，允许用户选择目标主机配置。
#   4. 密钥恢复：集成 Bitwarden CLI (rbw)，安全恢复 SSH 主机密钥以保持身份一致性。
#   5. 磁盘管理：交互式选择目标磁盘，并发出数据清除警告。
#   6. 自动分区：使用 Disko 根据配置文件自动执行磁盘分区和格式化。
#   7. 系统安装：生成硬件配置，持久化密钥和配置，并执行 nixos-install。
#
# 前置条件 (Prerequisites):
#   - 必须在 NixOS Live ISO 环境中运行。
#   - 必须能连通Github。
#   - 需要 Bitwarden 账户和已存储的 SSH 主机密钥条目。
#   - 目标机器应支持 UEFI 启动（推荐）。
#
# 用法 (Usage):
#   通常通过 curl 或 wget 直接执行：
#   curl -L https://raw.githubusercontent.com/0Sycamores/nixos-config/main/scripts/install.sh | bash
#   或
#   bash <(curl -fsSL nixos.sycamore.icu/install)
#
# 作者 (Author): Sycamore
# 仓库 (Repository): https://github.com/0Sycamores/nixos-config
# ======================================================================================

set -e

# --- 配置 ---
readonly REPO_URL="https://github.com/0Sycamores/nixos-config"
readonly TARGET_DIR="/tmp/nixos-install"

# --- 颜色 ---
readonly GREEN=$'\033[0;32m'
readonly RED=$'\033[0;31m'
readonly NC=$'\033[0m' # No Color

# --- 全局状态 ---
# 这些变量维护跨函数的状态
SELECTED_HOST=""
TARGET_DISK=""
TEMP_KEY_DIR=""

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
# 局部变量:
#   exit_code: 脚本的退出代码。
#######################################
cleanup() {
    local exit_code=$?

    # 安全清理临时密钥目录
    if [[ -n "${TEMP_KEY_DIR}" && -d "${TEMP_KEY_DIR}" ]]; then
        rm -rf "${TEMP_KEY_DIR}"
    fi

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
# 步骤 4: 恢复 SSH 密钥。
# 使用 rbw (Bitwarden CLI) 获取 SSH 主机密钥以保留身份。
#######################################
restore_ssh_keys() {
    step "[4/8] Restoring SSH Host Keys from Bitwarden..."

    # 使用 mktemp 创建安全的临时目录
    TEMP_KEY_DIR=$(mktemp -d)
    chmod 700 "$TEMP_KEY_DIR"

    # 内部辅助函数：获取单个密钥字段
    # 参数: item_name, field_name, output_file
    _fetch_key_field() {
        local item="$1"
        local field="$2"
        local out="$3"
        
        # 使用增强的 sed 链处理多种格式异常：
        # 1. s/\\n/\n/g:                      将 rbw 输出的字面量 "\n" 转换为实际换行
        # 2. s/-----BEGIN [A-Z ]*-----/&\n/g: 确保 Header 之后强制换行 (修复单行粘连)
        # 3. s/-----END [A-Z ]*-----/\n&/g:   确保 Footer 之前强制换行 (修复单行粘连)
        # 4. /^$/d:                           删除因重复换行产生的空行
        if nix shell nixpkgs#rbw nixpkgs#pinentry-curses --command rbw get "${item}" -f "${field}" \
           | sed -e 's/\\n/\n/g' \
                 -e 's/-----BEGIN [A-Z ]*-----/&\n/g' \
                 -e 's/-----END [A-Z ]*-----/\n&/g' \
           | sed '/^$/d' > "${out}"; then
           
            if [[ ! -s "${out}" ]]; then
                err "Error: File '${out}' is empty. Field '${field}' might be missing in Bitwarden item."
                return 1
            fi
            return 0
        else
            err "Error: Failed to fetch '${field}' from Bitwarden."
            return 1
        fi
    }

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
        if ! nix shell nixpkgs#rbw nixpkgs#pinentry-curses --command bash -c "rbw config set base_url ${bw_url} && rbw config set email ${bw_email} && rbw config set pinentry pinentry-curses && echo 'Please enter your master password to login:' && rbw login"; then
            err "Failed to login to Bitwarden. Please verify your credentials."
            exit 1
        fi
    fi

    # 提示输入 Bitwarden 中的密钥项名称
    read -r -p "Enter the Bitwarden item name for ${SELECTED_HOST}'s SSH key: " bw_item_name

    # 获取密钥
    # 同样需要 pinentry-curses 环境，以防 agent 超时需要重新认证
    info "Fetching key '${bw_item_name}'..."

    local fetch_success=true

    # 获取私钥
    info "Fetching private key..."
    if ! _fetch_key_field "${bw_item_name}" "private_key" "${TEMP_KEY_DIR}/ssh_host_ed25519_key"; then
        fetch_success=false
    fi

    # 获取公钥
    info "Fetching public key..."
    if ! _fetch_key_field "${bw_item_name}" "public_key" "${TEMP_KEY_DIR}/ssh_host_ed25519_key.pub"; then
        fetch_success=false
    fi

    if [[ "$fetch_success" == "true" ]]; then
        # 设置正确权限
        chmod 600 "${TEMP_KEY_DIR}/ssh_host_ed25519_key"
        chmod 644 "${TEMP_KEY_DIR}/ssh_host_ed25519_key.pub"
        success "SSH keys fetched successfully."

        info "--- Key Preview (Masked) ---"
        info "Private Key:"
        # 打印首尾行以验证格式是否正确（例如检查是否已正确换行）
        head -n 1 "${TEMP_KEY_DIR}/ssh_host_ed25519_key"
        echo "......"
        tail -n 1 "${TEMP_KEY_DIR}/ssh_host_ed25519_key"
        
        echo ""
        info "Public Key:"
        cat "${TEMP_KEY_DIR}/ssh_host_ed25519_key.pub"
        info "----------------------------"

        # 复制密钥到当前 ISO 环境，以便 sops-nix 在构建时可以解密 secrets
        info "Copying keys to current environment for sops-nix decryption..."
        mkdir -p /etc/ssh
        cp "${TEMP_KEY_DIR}/ssh_host_ed25519_key" /etc/ssh/ssh_host_ed25519_key
        cp "${TEMP_KEY_DIR}/ssh_host_ed25519_key.pub" /etc/ssh/ssh_host_ed25519_key.pub
        # 确保当前环境也有正确权限
        chmod 600 /etc/ssh/ssh_host_ed25519_key
    else
        err "Failed to fetch keys properly!"
        err "Aborting installation to prevent lockout."
        exit 1
    fi
}

verify_sops_decryption() {
    step "Verifying SOPS decryption..."

    # 1. 确定私钥位置 (脚本中恢复到了 /etc/ssh/ssh_host_ed25519_key)
    local key_path="/etc/ssh/ssh_host_ed25519_key"

    if [[ ! -f "${key_path}" ]]; then
        err "❌ Private key not found at ${key_path}"
        return 1
    fi

    # 2. 尝试解密 secrets.yaml
    # SOPS 默认会根据环境变量或配置文件寻找密钥。
    # 这里我们需要告诉 sops 使用 SSH key 转换成的 age key。
    # sops-nix 的机制是把 ssh key 转换成 age key。
    # 我们可以利用 sops 的 --keyservice 选项或者设置 SOPS_AGE_KEY_FILE 环境变量。
    
    # 但更简单的方法是直接利用 ssh-to-age 工具（如果环境里有）或者让 sops 自动识别 SSH 密钥。
    # 实际上，sops 原生并不直接支持读取 ssh 私钥文件作为 age key（这是 sops-nix 做的一层桥接）。
    # sops-nix 在激活时会运行一个脚本把 ssh key 转换成 age key 放在 /run/secrets.d/age-keys.txt (类似路径)。
    
    # 在安装脚本这种临时环境中，最直接的验证方法是：
    # 使用 ssh-to-age 将 SSH 私钥转换为 Age 私钥，然后尝试解密。
    
    info "Converting SSH key to Age key for testing..."
    
    # 获取转换后的 Age 私钥
    local age_key
    if ! age_key=$(nix shell nixpkgs#ssh-to-age --command ssh-to-age -private-key -i "${key_path}"); then
        err "❌ Failed to convert SSH key to Age key."
        return 1
    fi
    
    info "Attempting to decrypt secrets.yaml..."
    
    # 设置环境变量供 sops 使用
    export SOPS_AGE_KEY="${age_key}"
    
    # 尝试解密 (只输出到 /dev/null，不展示内容，只看退出码)
    if nix shell nixpkgs#sops --command sops --decrypt "secrets/secrets.yaml" > /dev/null 2>&1; then
        success "✅ SOPS decryption verified successfully!"
        return 0
    else
        err "❌ SOPS decryption FAILED!"
        err "   The restored SSH key does not match the lock on secrets.yaml."
        err "   Please check if the host key in Bitwarden matches .sops.yaml."
        return 1
    fi
}

#######################################
# 步骤 5: 选择目标磁盘。
# 列出物理磁盘并提示用户选择一个。
# 检查现有的 Windows 分区以警告用户。
# 设置全局 TARGET_DISK。
#######################################
select_disk() {
    step "[5/8] Select target disk"
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
# 步骤 6: 注入硬件配置。
# 将 disko.nix 中的磁盘设备替换为选定的目标磁盘。
#######################################
inject_hardware_config() {
    step "[6/8] Injecting hardware configuration..."

    # 修改 Disko 配置
    # 匹配 device = "..."; 并替换为实际目标磁盘
    sed -i "s|device = \".*\";|device = \"${TARGET_DISK}\";|" "hosts/${SELECTED_HOST}/disko.nix"
    info "Installation target set to ${TARGET_DISK}"
}

#######################################
# 步骤 7: 分区和格式化。
# 在 'disko' 模式下运行 disko 以应用分区和格式化。
#######################################
partition_and_format() {
    step "[7/8] Executing Disko partitioning..."
    # 使用 Flake 锁定的 Disko 版本 (确保环境一致性)
    # --mode destroy,format,mount: 依次执行销毁旧数据、格式化新分区、挂载到 /mnt
    # --yes-wipe-all-disks: 非交互式确认擦除所有数据 (脚本前面已通过 select_disk 确认过)
    nix run .#disko -- --mode destroy,format,mount --yes-wipe-all-disks "./hosts/${SELECTED_HOST}/disko.nix"
}


#######################################
# 步骤 8: 安装 NixOS。
# 生成 hardware-configuration.nix 并运行 nixos-install。
#######################################
install_nixos() {
    step "[8/8] Generating hardware config and installing..."

    # 生成 hardware.nix
    nixos-generate-config --root /mnt --no-filesystems --show-hardware-config > "hosts/${SELECTED_HOST}/hardware.nix"
    
    # 暂存所有修改 (包含新生成的 hardware.nix 和修改过的 disko.nix)
    # 这一步对于基于 Git 的 Flake 至关重要，否则未追踪的文件可能被忽略
    git add .

    # 提交修改，确保 Flake 能读取到新文件 (hardware.nix)
    # 当 Flake 源为 Git 仓库时，未提交的文件(即使已暂存)可能无法被 Nix 识别，
    # 导致 "No such file or directory" 错误。
    if [ -n "$(git status --porcelain)" ]; then
        info "Committing changes to Git to ensure Flake visibility..."
        git config user.name "NixOS Installer"
        git config user.email "installer@localhost"
        git commit -m "Auto-generated hardware config and disk layout"
    fi

    # 将配置复制到新系统
    # 按照惯例，放在 /etc/nixos 比较合适，因为这是 NixOS 的默认配置位置
    step "Persisting configuration and keys to /mnt..."
    
    # 1. 复制 NixOS 配置
    # 先清理目标目录，防止残留文件干扰
    if [[ -d "/mnt/etc/nixos" ]]; then
        rm -rf /mnt/etc/nixos
    fi
    mkdir -p /mnt/etc/nixos
    
    # 复制当前目录所有内容（包含 .git，保留版本控制能力）
    # 使用 ./. 确保隐藏文件也被复制
    cp -r ./. /mnt/etc/nixos/
    info "Configuration copied to /mnt/etc/nixos"

    # 2. 复制 SSH 密钥
    if [[ -n "${TEMP_KEY_DIR}" && -d "${TEMP_KEY_DIR}" ]]; then
        mkdir -p /mnt/etc/ssh
        cp "${TEMP_KEY_DIR}"/* /mnt/etc/ssh/
        chmod 600 /mnt/etc/ssh/ssh_host_ed25519_key
        chmod 644 /mnt/etc/ssh/ssh_host_ed25519_key.pub
        info "SSH keys copied to /mnt/etc/ssh"
    else
        err "Warning: Temporary keys not found, SSH keys might not be persisted!"
    fi

    info "Starting NixOS installation (${SELECTED_HOST})..."
    # 注意：这里使用 --flake /mnt/etc/nixos#... 来指向已经复制进去的配置
    # 这样可以确保安装的是最终持久化在磁盘上的那个版本
    # 使用 --no-root-passwd 因为我们通常在配置中声明了用户密码或使用 SSH 密钥
    nixos-install --no-root-passwd --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" --root /mnt --flake "/mnt/etc/nixos#${SELECTED_HOST}" --show-trace

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
    restore_ssh_keys
    verify_sops_decryption
    select_disk
    inject_hardware_config
    partition_and_format
    install_nixos
    
    step "You can type 'reboot' to restart into the new system."
}

# Run main with all arguments
main "$@"