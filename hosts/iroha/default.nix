{ config, pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware.nix
  ];

  # 必须开启 Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # 使用国内镜像源 (USTC)
  nix.settings.substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" ];

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
    settings.PermitRootLogin = "yes";
  };

  # 普通用户
  users.users.sycamore = {
    isNormalUser = true;
    description = "sycamore";
    extraGroups = [ "networkmanager" "wheel" ];
    initialPassword = "password";
  };

  # 常用软件 (用户级软件已移至 Home Manager)
  environment.systemPackages = with pkgs; [
    wget
    curl
    git # 保留 git 以便能拉取配置更新
  ];

  system.stateVersion = "25.11";
}