{ config, pkgs, ... }:

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

  # 引导加载器
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";

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

  # Sycamore 用户
  users.users.sycamore = {
    isNormalUser = true;
    description = "sycamore";
    extraGroups = [ "networkmanager" "wheel" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    shell = pkgs.fish;
  };

  # 系统级基础软件
  environment.systemPackages = with pkgs; [
    wget
    curl
    git
  ];

  system.stateVersion = "25.11";
}