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
    theme = pkgs.distro-grub-themes;
  };

  # 内核参数优化
  boot.kernelParams = [
    "nowatchdog"
    "zswap.enabled=0"
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