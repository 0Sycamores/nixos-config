/*
  ===================================================================================
  Host Configuration for 'iroha'
  ===================================================================================
  主机 'iroha' 的系统入口配置文件。
  
  包含:
  1. 导入必要的 NixOS 模块 (Disko, SOPS, Home Manager 等)。
  2. 导入硬件配置和系统基础配置。
  3. 配置 Home Manager 集成。
  4. 设置主机名和临时文件规则 (确保特定目录存在)。
*/
{ config, pkgs, inputs, vars, ... }:

{
  imports = [
    # 导入外部 Flake 提供的模块
    inputs.disko.nixosModules.disko            # 磁盘分区工具
    inputs.sops-nix.nixosModules.sops          # 敏感信息管理
    inputs.home-manager.nixosModules.home-manager # Home Manager 系统级集成
    
    # 导入本地配置模块
    ./disko.nix                 # 本机磁盘分区配置
    ./hardware.nix              # 本机硬件配置 (通常由 nixos-generate-config 生成)
    ../../modules/core.nix        # 系统通用基础配置 (无引导)
    ../../modules/mirror.nix      # 国内镜像源
    ../../modules/boot.nix        # 物理机引导配置
    ../../modules/sops.nix        # SOPS 通用配置
    ../desktop.nix                # 桌面环境配置 (Niri)
  ];

  # =================================================================================
  # Home Manager Integration
  # =================================================================================

  home-manager = {
    useGlobalPkgs = true;    # 使用系统级 nixpkgs，减少重复下载
    useUserPackages = true;  # 将软件包安装到 /etc/profiles，方便管理
    extraSpecialArgs = { inherit inputs vars; }; # 传递 inputs 和 vars 到 Home Manager 模块
    
    # 导入 iroha 用户的 Home Manager 配置
    users.${vars.username} = import ./home.nix;
  };

  # =================================================================================
  # Host Specific Settings
  # =================================================================================

  # 设置主机名
  networking.hostName = "iroha";

  # =================================================================================
  # Console Settings
  # =================================================================================
  console = {
    earlySetup = true;
    font = "ter-v24n"; # 使用 16px 标准字体，或者直接留空使用默认
    packages = with pkgs; [ terminus_font ];
  };

  # 自动登录到 TTY1
  services.getty.autologinUser = vars.username;

  # VMware Guest Tools
  virtualisation.vmware.guest.enable = true;

  # 强制指定一个高分辨率，例如 1920x1080 或 2560x1440 "Virtual-1" 是显示器名称
  boot.kernelParams = [ "video=Virtual-1:1080x1080" ];

  # 防火墙配置
  # OpenSSH (22) 默认会打开防火墙，但在此处显式声明以便管理
  networking.firewall.allowedTCPPorts = [ 22 ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  # 确保特定用户目录存在 (Downloads, Videos, Games)
  # 权限: 0755, 用户: vars.username, 组: users
  # 注意: 使用 "d" 类型，如果目录不存在则创建
  systemd.tmpfiles.rules = [
    "d /home/${vars.username}/Downloads 0755 ${vars.username} users -"
    "d /home/${vars.username}/Videos 0755 ${vars.username} users -"
    "d /home/${vars.username}/Games 0755 ${vars.username} users -"
  ];

  # 系统状态版本 (保持兼容性)
  system.stateVersion = vars.stateVersion;
}