{ config, pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware.nix # 这个文件会在安装时由脚本生成
  ];

  # 必须开启 Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # 使用国内镜像源 (USTC)
  nix.settings.substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" ];

  # 引导加载器
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 网络 (占位符)
  networking.hostName = "__HOSTNAME__"; # <--- 脚本会替换这个
  networking.networkmanager.enable = true;

  # 时区
  time.timeZone = "Asia/Shanghai";

  # 开启 SSH
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # 普通用户
  users.users.__USERNAME__ = {
    isNormalUser = true;
    description = "__USERNAME__";
    extraGroups = [ "networkmanager" "wheel" ];
    initialPassword = "password";
  };

  # 常用软件
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
  ];

  system.stateVersion = "25.11"; # 保持和 input 版本一致
}