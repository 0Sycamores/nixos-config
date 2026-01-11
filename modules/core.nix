# ===================================================================================
# System Core Configuration
# ===================================================================================
# 此模块定义了所有主机共用的基础系统配置 (Core Layer)。
# 它是“最小公约数”，不包含硬件特定或桌面环境配置。
#
# 功能:
# 1. Nix 自身配置 (Flakes, 镜像源)
# 2. 基础网络与时区
# 3. SSH 服务与安全
# 4. 用户账号管理
# 5. 核心系统软件包
# ===================================================================================
{ config, pkgs, vars, ... }:

{
  # =================================================================================
  # Nix Settings
  # =================================================================================

  # 启用 Nix Command 和 Flakes 支持
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # =================================================================================
  # Network & Time
  # =================================================================================

  # 启用 NetworkManager
  networking.networkmanager.enable = true;

  # 设置时区 (引用 vars)
  time.timeZone = vars.timeZone;

  # 启用防火墙 (默认开启，具体端口在各主机配置中定义)
  networking.firewall.enable = true;

  # =================================================================================
  # Services & Security
  # =================================================================================

  # OpenSSH 服务
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";         # 禁止 Root 远程登录
      PasswordAuthentication = false; # 禁止密码验证 (强制使用 SSH Key)
    };
  };

  # =================================================================================
  # Users & Permissions
  # =================================================================================

  # 禁止命令修改用户 (强制声明式管理)
  users.mutableUsers = false;

  # Root 用户 (密码由 sops 管理)
  users.users.root = {
    hashedPasswordFile = config.sops.secrets.root_password.path;
  };

  # 主用户配置
  users.users.${vars.username} = {
    isNormalUser = true;
    description = "${vars.username}";
    extraGroups = [ "networkmanager" "wheel" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    shell = pkgs.fish; # 使用 Fish Shell
    openssh.authorizedKeys.keys = vars.authorizedKeys; # 配置 SSH 公钥
  };

  # =================================================================================
  # System Environment
  # =================================================================================

  # 必须在系统级启用 Fish，才能将其用作登录 Shell
  programs.fish.enable = true;

  # 确保 /etc/nixos 指向用户的 Flake 配置目录 L+ 表示如果链接不存在则创建，如果存在且指向不同则强制重建
  systemd.tmpfiles.rules = [
    "L+ /etc/nixos - - - - /home/${vars.username}/.config/nixos"
  ];

  # 系统级基础软件包
  environment.systemPackages = with pkgs; [
    wget
    curl
    git
  ];

  # NixOS 版本状态 (请勿随意修改)
  system.stateVersion = vars.stateVersion;
}