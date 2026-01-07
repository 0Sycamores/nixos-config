{ config, pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware.nix
  ];

  # 必须开启 Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # 使用国内镜像源 + 官方源作为备用
  nix.settings = {
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"   # USTC 镜像
      "https://mirror.sjtu.edu.cn/nix-channels/store"    # 上交镜像
      "https://cache.nixos.org/"                         # 官方源（备用）
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };


  # 引导加载器
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 网络
  networking.hostName = "iroha";
  networking.networkmanager.enable = true;

  # 时区
  time.timeZone = "Asia/Shanghai";

  # 开启 SSH
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };

  users.users.root.hashedPassword = "!";

  # 启用 Fish Shell
  programs.fish.enable = true;

  # 普通用户
  users.users.sycamore = {
    isNormalUser = true;
    description = "sycamore";
    extraGroups = [ "networkmanager" "wheel" ];
    initialPassword = "password";
    shell = pkgs.fish;
  };

  # 常用软件 (用户级软件已移至 Home Manager)
  environment.systemPackages = with pkgs; [
    wget
    curl
    git # 保留 git 以便能拉取配置更新
  ];

  system.stateVersion = "25.11";
}