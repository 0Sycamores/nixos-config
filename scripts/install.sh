#!/usr/bin/env bash
#
# ======================================================================================
# NixOS Multi-Host Automated Installer / NixOS 多主机自动化安装程序
# ======================================================================================
#
# 描述 (Description):
#   此脚本专为在裸机环境下自动化安装 NixOS 而设计。它假设运行环境为官方 NixOS ISO。
#   该脚本通过一系列交互式步骤，引导用户完成从环境准备、配置下载、密钥恢复、
#   磁盘分区到最终系统安装的全过程。
#
#   核心功能与设计理念：
#   1. 环境自动检测与准备：
#      - 验证运行环境是否为 NixOS。
#      - 检测互联网连接（通过 ping baidu.com），因为 Nix 安装强依赖网络。
#      - 提供交互式 HTTP 代理配置，以加速国内环境下的 GitHub 访问。
#      - 自动配置并启用 Nix Flakes 实验特性，配置国内镜像源（USTC）以加速构建。
#
#   2. 配置即代码 (IaC) 拉取：
#      - 自动从指定的 GitHub 仓库克隆最新的 NixOS Flake 配置。
#      - 使用临时目录 (/tmp/nixos-install) 保证安装环境的清洁。
#
#   3. 动态主机选择：
#      - 自动扫描仓库中的 `hosts/` 目录，识别可用的主机配置。
#      - 提供交互式菜单供用户选择目标主机（如 iroha, yukino 等）。
#      - 验证所选主机是否包含 `disko.nix` 分区配置，确保自动化分区的可行性。
#
#   4. 密钥管理与身份一致性 (Sops-Nix 集成)：
#      - 集成 `rbw` (Bitwarden CLI) 从密码管理器安全恢复 Age 密钥 (用于 SOPS)。
#      - 使用 `pinentry-curses` 处理密码输入，确保在纯终端环境下可用。
#      - **关键安全检查**：在安装前使用恢复的 Age 密钥尝试解密 `secrets/secrets.yaml`。
#        这实现了 "Fail Fast" 原则：如果密钥错误或无法解密，立即中止安装，
#        防止在安装完成才发现无法解密系统密码。
#
#   5. 磁盘管理与 Disko 集成：
#      - 列出系统物理磁盘，提示用户选择安装目标。
#      - 智能检测目标磁盘是否含有 Windows (NTFS) 分区，并发出高亮警告。
#      - 动态修改 `disko.nix` 配置，将目标设备路径注入到配置中。
#      - 使用 `nix run .#disko` 执行声明式分区、格式化和挂载，无需手动编写 fstab。
#
#   6. 幂等性与系统安装：
#      - 自动生成 `hardware.nix` 并纳入 Git 版本控制。
#      - 强制执行 Git 提交，因为 Flake 只能识别已追踪（Tracked）的文件。
#      - 使用 `nixos-install` 从当前目录（Flake）构建并安装系统。
#
#   7. 配置持久化与最佳实践：
#      - 将完整的 Flake 配置复制到新系统的用户目录 (`~/.config/nixos`)，而非 `/etc/nixos`。
#        这是 Flake 时代的最佳实践，避免了 `/etc` 下 Git 仓库的 "Dubious Ownership" 权限问题。
#      - 自动创建 `/etc/nixos` -> `~/.config/nixos` 的软链接以保持兼容性。
#      - 自动修正配置文件权限为 UID 1000 (首个普通用户)，确保用户登录后可直接编辑。
#      - 将恢复的 Age 密钥持久化到 `/mnt/var/lib/sops-nix/key.txt`，确保新系统首次启动即可解密 sops secrets。
#
# 前置条件 (Prerequisites):
#   - 必须在 NixOS Live ISO 环境中运行。
#   - 必须拥有有效的互联网连接。
#   - 需要 Bitwarden 账户，且其中已存储对应主机的 Age 密钥（字段：notes）。
#   - 目标机器应支持 UEFI 启动（脚本默认配置为 UEFI/GPT）。
#
# 用法 (Usage):
#   通常通过 curl 或 wget 直接从 GitHub 拉取并执行：
#   curl -L https://raw.githubusercontent.com/0Sycamores/nixos-config/main/scripts/install.sh | bash
#   或
#   bash <(curl -fsSL nixos.sycamore.icu/install)
#
# 作者 (Author): Sycamore
# 仓库 (Repository): https://github.com/0Sycamores/nixos-config
# ======================================================================================

set -e

# --- 配置 ---
# 远程配置仓库地址
readonly REPO_URL="https://github.com/0Sycamores/nixos-config"
# 安装过程中的临时工作目录
readonly TARGET_DIR="/tmp/nixos-install"

# --- 颜色定义 ---
# 用于美化终端输出
readonly GREEN=$'\033[0;32m'
readonly RED=$'\033[0;31m'
readonly NC=$'\033[0m' # No Color (重置颜色)

# --- 全局状态变量 ---
# 这些变量在不同函数间传递状态
SELECTED_HOST=""  # 用户选择的目标主机名 (例如: iroha)
TARGET_DISK=""    # 用户选择的目标安装磁盘 (例如: /dev/sda)
TEMP_KEY_DIR=""   # 存放从 Bitwarden 恢复的临时密钥的目录路径

# --- 日志辅助函数 ---

#######################################
# 打印普通信息到标准输出 (stdout)。
# 参数:
#   $*: 要打印的消息内容。
#######################################
info() {
    printf "%s\n" "$*"
}

#######################################
# 打印绿色高亮的成功消息。
# 参数:
#   $*: 要打印的消息内容。
#######################################
success() {
    printf "${GREEN}%s${NC}\n" "$*"
}

#######################################
# 打印红色高亮的错误消息到标准错误 (stderr)。
# 参数:
#   $*: 要打印的消息内容。
#######################################
err() {
    printf "${RED}%s${NC}\n" "$*" >&2
}

#######################################
# 打印带有前置换行的绿色步骤标题。
# 用于区分安装过程的不同阶段。
# 参数:
#   $*: 步骤描述。
#######################################
step() {
    printf "\n${GREEN}%s${NC}\n" "$*"
}

#######################################
# 清理函数 (Cleanup)。
# 注册在脚本退出 (EXIT) 或被中断 (INT, TERM) 时自动执行。
# 负责清理临时文件、卸载挂载点（如果出错）并报告最终状态。
#######################################
cleanup() {
    local exit_code=$?

    # 安全清理临时密钥目录，防止私钥泄露
    if [[ -n "${TEMP_KEY_DIR}" && -d "${TEMP_KEY_DIR}" ]]; then
        rm -rf "${TEMP_KEY_DIR}"
    fi

    # 如果脚本非正常退出 (exit_code != 0)
    if [[ "${exit_code}" -ne 0 ]]; then
        printf "\n" >&2
        err "❌ Script exited with error code ${exit_code}."
        err "Cleaning up..."

        # 检查 /mnt 是否仍处于挂载状态，提示用户手动处理
        if grep -qs "/mnt" /proc/mounts; then
            info "⚠️  The system is still mounted at /mnt for debugging."
            info "   You can unmount it manually by running: umount -R /mnt"
        fi
        
        err "Cleanup complete."
    fi
}

#######################################
# 步骤 1: 准备安装环境。
# 1. 验证运行环境是否为 NixOS。
# 2. 检查互联网连接。
# 3. 提供交互式代理配置。
# 4. 配置 Nix 以启用 Flakes 和国内镜像源。
#######################################
prepare_environment() {
    step "[1/8] Preparing environment..."

    # 检查是否在 NixOS 环境中 (通过检测 /etc/NIXOS 标志文件)
    if [[ ! -e /etc/NIXOS ]]; then
        err "Error: This script must be run within a NixOS environment."
        exit 1
    fi

    # 检查网络连接 (Ping 百度)
    if ping -c 1 baidu.com &> /dev/null; then
        info "Internet connection is normal."
    else
        err "Unable to connect to the internet. Please configure the network first (nmcli / wpa_supplicant)."
        exit 1
    fi

    # 配置 HTTP 代理 (可选)
    printf "\n"
    info "Do you need to configure an HTTP proxy to speed up GitHub access?"
    read -r -p "Please enter proxy address (e.g. 192.168.1.100:7890 or http://192.168.1.100:7890, leave empty to skip): " proxy_addr

    if [[ -n "${proxy_addr}" ]]; then
        # 自动补全 http:// 前缀
        if [[ "${proxy_addr}" != http://* ]] && [[ "${proxy_addr}" != https://* ]]; then
            proxy_addr="http://${proxy_addr}"
        fi
        export http_proxy="${proxy_addr}"
        export https_proxy="${proxy_addr}"
        info "Proxy set: ${proxy_addr}"
    fi

    # 测试 GitHub 连通性
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

    # 启用 Flakes 和配置镜像源
    # 写入 ~/.config/nix/nix.conf
    mkdir -p ~/.config/nix
    cat > ~/.config/nix/nix.conf << EOF
experimental-features = nix-command flakes
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/
EOF
}

#######################################
# 步骤 2: 拉取配置。
# 从 GitHub 克隆 NixOS 配置仓库到本地临时目录。
#######################################
fetch_configuration() {
    step "[2/8] Fetching configuration..."

    info "Preparing to clone configuration from GitHub..."
    # 清理旧的临时目录 (如果存在)
    if [[ -d "${TARGET_DIR}" ]]; then
        info "Cleaning up old directory ${TARGET_DIR} ..."
        rm -rf "${TARGET_DIR}"
    fi

    # 使用 `nix shell nixpkgs#git` 临时环境执行 git clone，确保即使 ISO 精简版未预装 git 也能工作
    nix shell nixpkgs#git --command git clone "${REPO_URL}" "${TARGET_DIR}"
    
    # 切换工作目录到下载的仓库
    cd "${TARGET_DIR}" || exit 1
}

#######################################
# 步骤 3: 选择目标主机。
# 1. 扫描 `hosts/` 目录。
# 2. 展示可用主机列表。
# 3. 提示用户输入选择。
# 4. 验证所选主机是否包含必要的 `disko.nix`。
#######################################
select_host() {
    step "[3/8] Select target host"
    info "Available host configurations (hosts/):"

    if [[ ! -d "hosts" ]]; then
        err "Error: 'hosts' directory not found in ${TARGET_DIR}"
        exit 1
    fi

    # 读取 hosts 目录下的子目录名作为主机列表
    local hosts=($(ls hosts))
    local i=1
    local host

    # 打印菜单
    for host in "${hosts[@]}"; do
        info "$i) $host"
        ((i++))
    done

    # 循环等待用户有效输入
    while true; do
        read -r -p "Please enter the number to select a host: " host_index
        
        # 验证输入是否为有效的数字索引
        if [[ "${host_index}" =~ ^[0-9]+$ ]] && [[ "${host_index}" -ge 1 ]] && [[ "${host_index}" -le "${#hosts[@]}" ]]; then
            break
        else
            err "Error: Invalid selection, please try again."
        fi
    done

    # 设置全局变量 SELECTED_HOST
    SELECTED_HOST="${hosts[$((host_index-1))]}"
    info "Selected host: ${GREEN}${SELECTED_HOST}${NC}"

    # 预检查：确保该主机定义了 disko 分区配置
    if [[ ! -f "hosts/${SELECTED_HOST}/disko.nix" ]]; then
        err "Error: hosts/${SELECTED_HOST}/disko.nix does not exist."
        info "This host might not support automatic partitioning installation, or configuration is incomplete."
        exit 1
    fi
}

#######################################
# 步骤 4: 恢复密钥 (Age Key)。
# 使用 rbw (Bitwarden CLI) 从密码管理器中获取 Age Key。
# Age Key (存储在 notes 字段) 用于 SOPS 解密。
#######################################
restore_keys() {
    step "[4/8] Restoring Keys from Bitwarden..."

    # 创建权限受限的临时目录 (0700) 存放密钥
    TEMP_KEY_DIR=$(mktemp -d)
    chmod 700 "$TEMP_KEY_DIR"

    # 检查 rbw 是否处于未锁定状态
    if ! nix shell nixpkgs#rbw nixpkgs#pinentry-curses --command rbw unlocked 2>/dev/null; then
        info "Please login to Bitwarden (rbw) to fetch keys."

        read -r -p "Enter Bitwarden server URL (Leave empty for official server): " bw_url
        if [[ -z "${bw_url}" ]]; then
            bw_url="https://api.bitwarden.com"
        elif [[ "${bw_url}" != http://* ]] && [[ "${bw_url}" != https://* ]]; then
            bw_url="https://${bw_url}"
        fi

        read -r -p "Enter your Bitwarden email: " bw_email
        
        info "Configuring rbw..."
        if ! nix shell nixpkgs#rbw nixpkgs#pinentry-curses --command bash -c "rbw config set base_url ${bw_url} && rbw config set email ${bw_email} && rbw config set pinentry pinentry-curses && echo 'Please enter your master password to login:' && rbw login"; then
            err "Failed to login to Bitwarden. Please verify your credentials."
            exit 1
        fi
    fi

    # 提示用户输入 Bitwarden 中的 Item 名称
    read -r -p "Enter the Bitwarden item name for keys [default: ${SELECTED_HOST}]: " bw_item_name
    bw_item_name=${bw_item_name:-${SELECTED_HOST}}

    info "Fetching keys from '${bw_item_name}'..."

    # 获取 Age Secret Key (存储在 notes 字段)
    info "Fetching Age Secret Key (from notes)..."
    
    # 直接使用 rbw 获取并写入文件
    if nix shell nixpkgs#rbw nixpkgs#pinentry-curses --command rbw get "${bw_item_name}" -f notes > "${TEMP_KEY_DIR}/key.txt"; then
        if [[ ! -s "${TEMP_KEY_DIR}/key.txt" ]]; then
            err "Error: Retrieved key file is empty. Please check 'notes' field."
            err "Aborting installation."
            exit 1
        fi
    else
        err "Error: Failed to fetch Age Key from Bitwarden."
        err "Aborting installation."
        exit 1
    fi

    # 设置权限
    chmod 600 "${TEMP_KEY_DIR}/key.txt"
    success "Age Key fetched successfully."

    # 部署 Age Key 到当前环境 (用于 verify_sops_decryption)
    # sops-nix 默认路径是 /var/lib/sops-nix/key.txt
    info "Deploying Age Key to /var/lib/sops-nix/key.txt..."
    mkdir -p /var/lib/sops-nix
    cp "${TEMP_KEY_DIR}/key.txt" /var/lib/sops-nix/key.txt
    chmod 600 /var/lib/sops-nix/key.txt
}

#######################################
# 验证 SOPS 解密功能。
# 这是一个"防御性编程"步骤：
# 使用刚刚恢复的 SSH 密钥，尝试解密仓库中的 secrets.yaml。
# 如果解密失败，说明密钥不匹配，必须立即停止安装，否则系统安装后将无法解密用户密码，导致无法登录。
#######################################
verify_sops_decryption() {
    step "Verifying SOPS decryption..."

    # 1. 定位 Age Key
    local key_path="/var/lib/sops-nix/key.txt"

    if [[ ! -f "${key_path}" ]]; then
        err "❌ Age key not found at ${key_path}"
        return 1
    fi

    info "Attempting to decrypt secrets.yaml using Age key..."
    
    # 设置环境变量 SOPS_AGE_KEY_FILE
    export SOPS_AGE_KEY_FILE="${key_path}"
    
    # 尝试解密，将输出重定向到 /dev/null，只关心退出状态码
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
# 1. 列出系统中的物理磁盘。
# 2. 提示用户输入目标磁盘设备名。
# 3. 检查是否存在 Windows 分区并警告。
# 4. 请求用户最终确认擦除数据。
#######################################
select_disk() {
    step "[5/8] Select target disk"
    # 列出所有块设备，过滤出 disk 类型
    lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep "disk"
    
    while true; do
        read -r -p "Please enter target disk name (e.g., sda or nvme0n1): " disk_name
        TARGET_DISK="/dev/${disk_name}"

        # 检查设备块文件是否存在
        if [[ -b "${TARGET_DISK}" ]]; then
            break
        else
            err "Error: Device ${TARGET_DISK} not found, please try again."
        fi
    done

    # 检查是否存在 NTFS 分区 (可能的 Windows 系统)
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
# 修改 `hosts/<host>/disko.nix` 文件，将其中占位符设备路径替换为用户选择的实际磁盘。
#######################################
inject_hardware_config() {
    step "[6/8] Injecting hardware configuration..."

    # 使用 sed 直接修改文件
    # 匹配模式：device = "...";
    # 替换为：device = "/dev/xxx";
    sed -i "s|device = \".*\";|device = \"${TARGET_DISK}\";|" "hosts/${SELECTED_HOST}/disko.nix"
    info "Installation target set to ${TARGET_DISK}"
}

#######################################
# 步骤 7: 分区和格式化。
# 运行 Disko 工具，根据 disko.nix 的声明式配置自动执行分区、格式化和挂载。
#######################################
partition_and_format() {
    step "[7/8] Executing Disko partitioning..."
    # 使用 nix run 运行当前 Flake 中的 disko 目标
    # 参数说明：
    # --mode destroy,format,mount: 依次执行销毁数据、格式化分区、挂载到 /mnt
    # --yes-wipe-all-disks: 非交互式确认，因为我们在 select_disk 步骤已经确认过了
    nix run .#disko -- --mode destroy,format,mount --yes-wipe-all-disks "./hosts/${SELECTED_HOST}/disko.nix"
}


#######################################
# 步骤 8: 安装 NixOS。
# 1. 生成硬件配置 (hardware-configuration.nix)。
# 2. 提交更改到 Git (Flake 要求)。
# 3. 执行 nixos-install。
# 4. 将配置和密钥持久化到新系统。
#######################################
install_nixos() {
    step "[8/8] Generating hardware config and installing..."

    # 生成硬件扫描配置，排除文件系统相关内容 (因为由 Disko 管理)
    nixos-generate-config --root /mnt --no-filesystems --show-hardware-config > "hosts/${SELECTED_HOST}/hardware.nix"
    
    # 暂存所有修改 (包含新生成的 hardware.nix 和修改过的 disko.nix)
    git add .

    # 提交修改到 Git
    # Flake 的原理是只读取 Git 索引中的文件。如果文件未被追踪或未提交，
    # 在基于 Git 的 Flake 源中构建时可能会报 "file not found" 错误。
    if [ -n "$(git status --porcelain)" ]; then
        info "Committing changes to Git to ensure Flake visibility..."
        git config user.name "NixOS Installer"
        git config user.email "installer@sycamore.icu"
        git commit -m "Auto-generated hardware config and disk layout"
    fi

    info "Starting NixOS installation (${SELECTED_HOST})..."
    # 执行安装
    # --no-root-passwd: 不要求设置 root 密码 (我们通过 sops 或 user 配置管理)
    # --root /mnt: 安装目标目录
    # --flake ".#${SELECTED_HOST}": 使用当前目录 (.) 作为 Flake 源，构建指定主机配置
    nixos-install --no-root-passwd --root /mnt --flake ".#${SELECTED_HOST}" --show-trace

    # --- 后处理：持久化配置 ---
    step "Persisting configuration and keys to /mnt..."
    
    # 1. 复制 NixOS 配置
    # 最佳实践：将配置放在用户目录 (~/.config/nixos)，而非 /etc/nixos，以避免 Git 权限问题
    
    # 尝试从 modules/vars.nix 中解析主要用户名
    local target_user
    target_user=$(grep 'username =' modules/vars.nix | cut -d'"' -f2)
    
    # 如果解析失败，回退到交互式输入
    if [[ -z "${target_user}" ]]; then
        err "Warning: Could not detect username from modules/vars.nix"
        while true; do
            read -r -p "Please enter the primary username for the new system: " target_user
            # 用户名格式验证 (小写字母开头，仅含小写字母、数字、短横线)
            if [[ "${target_user}" =~ ^[a-z][a-z0-9-]*$ ]]; then
                break
            else
                err "Invalid username. Must start with a letter and contain only lowercase letters, digits, and hyphens."
            fi
        done
    fi
    
    # 定义目标路径
    local target_home="/mnt/home/${target_user}"
    local target_config_dir="${target_home}/.config/nixos"
    
    info "Persisting configuration to ${target_config_dir}..."
    
    # 创建目录结构
    mkdir -p "${target_home}"
    
    # 清理可能存在的旧配置 (防止冲突)
    if [[ -d "${target_config_dir}" ]]; then
        rm -rf "${target_config_dir}"
    fi
    mkdir -p "${target_config_dir}"
    
    # 复制当前目录的所有文件到目标位置
    cp -r ./. "${target_config_dir}/"
    
    # 设置所有权 (Ownership)
    # 由于用户在宿主机环境中不存在 (只在 /mnt/etc/passwd 中)，直接使用 UID/GID 1000:100。
    # NixOS 默认创建的第一个普通用户 UID 为 1000，用户组 users GID 为 100。
    info "Setting ownership to ${target_user} (UID 1000)..."
    
    # 递归修改配置目录权限
    chown -R 1000:100 "${target_config_dir}"
    
    # 修正父级 .config 目录的权限 (避免 root 拥有导致用户无法写入其他配置)
    if [[ -d "${target_home}/.config" ]]; then
        chown 1000:100 "${target_home}/.config"
    fi
    

    # 2. 持久化密钥 (仅 Age Key)
    if [[ -n "${TEMP_KEY_DIR}" && -d "${TEMP_KEY_DIR}" ]]; then
        # A. Age Key (用于 SOPS)
        info "Persisting Age Key to /mnt/var/lib/sops-nix/key.txt..."
        mkdir -p /mnt/var/lib/sops-nix
        cp "${TEMP_KEY_DIR}/key.txt" /mnt/var/lib/sops-nix/key.txt
        chmod 600 /mnt/var/lib/sops-nix/key.txt
    else
        err "Warning: Temporary keys not found, keys might not be persisted!"
    fi

    step "=== Installation Complete! ==="
}

#######################################
# 主程序入口。
# 按顺序编排所有安装步骤。
#######################################
main() {
    # 设置陷阱，在退出时执行清理
    trap cleanup EXIT INT TERM
    clear
    success "=== NixOS Multi-Host Installer ==="

    prepare_environment
    fetch_configuration
    select_host
    restore_keys
    verify_sops_decryption
    select_disk
    inject_hardware_config
    partition_and_format
    install_nixos
    
    step "You can type 'reboot' to restart into the new system."
}

# 运行主程序
main "$@"