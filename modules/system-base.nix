/*
  ===================================================================================
  System Base Configuration
  ===================================================================================
  此模块定义了所有主机共用的基础系统配置。
  
  包含:
  1. Nix 自身配置 (Flakes, 镜像源)
  2. 启动引导 (Bootloader - GRUB)
  3. 内核参数与模块管理
  4. 内存管理 (ZRAM)
  5. 基础网络与时区
  6. SSH 服务与安全
  7. 用户账号管理
  8. 核心系统软件包
*/
{ config, pkgs, vars, ... }:

{
  # =================================================================================
  # Nix Settings
  # =================================================================================

  # 启用 Nix Command 和 Flakes 支持
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # 配置国内镜像源以加速下载 (USTC, SJTU)
  nix.settings = {
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  # =================================================================================
  # Boot & Kernel
  # =================================================================================

  # 禁用 systemd-boot, 使用 GRUB
  boot.loader.systemd-boot.enable = false;
  
  # 允许修改 EFI 变量
  boot.loader.efi.canTouchEfiVariables = true;

  # GRUB 引导加载程序配置
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";      # EFI 系统不需要指定设备
    useOSProber = true;    # 自动检测其他操作系统
    default = "saved";     # 记住上次选择的启动项
    # # CyberPunk 主题配置
    # theme = pkgs.fetchFromGitHub {
    #     owner = "adnksharp";
    #     repo = "CyberGRUB-2077";
    #     rev = "6a5736ef44e4ede9bb403d78eafe7271dd2928db";
    #     sha256 = "sha256-1f61nkh6a2vwdaglzsbhj0pm5nrfq7qb1vx8g8wg19s1sbdaq8j7";
    # };
  };

  # 内核参数调优
  boot.kernelParams = [
    "nowatchdog"      # 禁用硬件看门狗
    "zswap.enabled=0" # 禁用 ZSwap (使用 ZRam 代替)
    "loglevel=5"      # 设置引导日志级别
  ];

  # 禁用不需要的内核模块
  boot.blacklistedKernelModules = [
    "iTCO_wdt"     # Intel Watchdog
    "sp5100_tco"   # AMD/ATI Watchdog
  ];

  # =================================================================================
  # Memory & Performance
  # =================================================================================

  # 启用 ZRam (内存压缩交换)
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50; # 使用 50% 内存作为 ZRam

  # =================================================================================
  # Network & Time
  # =================================================================================

  # 启用 NetworkManager
  networking.networkmanager.enable = true;

  # 设置时区 (引用 vars)
  time.timeZone = vars.timeZone;

  # =================================================================================
  # Services & Security
  # =================================================================================

  # OpenSSH 服务
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no"; # 禁止 Root 远程登录
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
  };

  # =================================================================================
  # System Environment
  # =================================================================================

  # 必须在系统级启用 Fish，才能将其用作登录 Shell
  programs.fish.enable = true;

  # 系统级基础软件包
  environment.systemPackages = with pkgs; [
    wget
    curl
    git
  ];

  # NixOS 版本状态 (请勿随意修改)
  system.stateVersion = vars.stateVersion;
}