{ config, pkgs, vars, ... }:

{
  # 开启 Nix Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # 使用国内镜像加速下载
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

  # 引导加载器 (GRUB)
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    useOSProber = true;
    default = "saved"; # 记忆上次启动项
    theme = pkgs.fetchFromGitHub {
        owner = "adnksharp";
        repo = "CyberGRUB-2077";
        rev = "6a5736ef44e4ede9bb403d78eafe7271dd2928db";
        sha256 = "sha256-1f61nkh6a2vwdaglzsbhj0pm5nrfq7qb1vx8g8wg19s1sbdaq8j7";
    };
  };

  # 内核参数优化
  boot.kernelParams = [
    "nowatchdog"      # 禁用看门狗加速启动和关机
    "zswap.enabled=0" # 禁用zswap 防止和zram冲突
    "loglevel=5"      # 启动日志开到5级
  ];

  # 禁用不需要的内核模块
  boot.blacklistedKernelModules = [
    "iTCO_wdt"   # intel 的看门狗
    "sp5100_tco" # AMD 的看门狗
  ];

  networking.networkmanager.enable = true;

  time.timeZone = vars.timeZone;

  # 开启 SSH 服务，禁止 root 登录
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };

  # 禁止手动修改密码
  users.mutableUsers = false;
  
  # Root 用户
  users.users.root = {
    hashedPasswordFile = config.sops.secrets.root_password.path;
  };

  # Wheel 用户
  users.users.${vars.username} = {
    isNormalUser = true;
    description = "${vars.username}";
    extraGroups = [ "networkmanager" "wheel" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    shell = pkgs.fish;
  };

  # 系统级基础软件
  environment.systemPackages = with pkgs; [
    wget
    curl
    git
    distro-grub-themes
  ];

  system.stateVersion = vars.stateVersion;
}