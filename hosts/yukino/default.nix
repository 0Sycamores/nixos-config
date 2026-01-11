/*
  ===================================================================================
  Host Configuration for 'yukino'
  ===================================================================================
  主机 'yukino' 的系统入口配置文件。
  
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
    inputs.sops-nix.nixosModules.sops          # 敏感信息管理
    inputs.home-manager.nixosModules.home-manager # Home Manager 系统级集成
    
    # 导入本地配置模块
    ./disko.nix                 # 本机磁盘分区配置
    ./hardware.nix              # 本机硬件配置
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
    useGlobalPkgs = true;    # 使用系统级 nixpkgs
    useUserPackages = true;  # 将软件包安装到 /etc/profiles
    extraSpecialArgs = { inherit inputs vars; }; # 传递 inputs 和 vars
    
    # 导入 yukino 用户的 Home Manager 配置
    users.${vars.username} = import ./home.nix;
  };

  # =================================================================================
  # Host Specific Settings
  # =================================================================================

  # 设置主机名
  networking.hostName = "yukino";

  # NVIDIA 显卡驱动配置
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    # 必须启用 modesetting。
    modesetting.enable = true;

    # Nvidia 电源管理。实验性功能，可能导致睡眠/挂起失败。
    # 如果你在从睡眠唤醒后遇到图形损坏或应用程序崩溃的问题，请启用此选项。
    # 这通过将整个 VRAM 内存保存到 /tmp/ 而不仅仅是基本部分来修复该问题。
    powerManagement.enable = false;

    # 细粒度电源管理。在不使用 GPU 时将其关闭。
    # 实验性功能，仅适用于现代 Nvidia GPU（Turing 架构或更新版本）。
    powerManagement.finegrained = false;

    # 使用 Nvidia 开源内核模块（不要与独立的第三方 "nouveau" 开源驱动混淆）。
    # 支持仅限于 Turing 及更高架构。支持的 GPU 完整列表见：
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    open = true;

    # 启用 Nvidia 设置菜单，
    # 可通过 `nvidia-settings` 访问。
    nvidiaSettings = true;

    # 可选：你可能需要为你的特定 GPU 选择合适的驱动版本。
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # 防火墙配置
  # OpenSSH (22) 默认会开启防火墙，但在此处显式声明以便管理
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

  # 系统状态版本
  system.stateVersion = vars.stateVersion;
}