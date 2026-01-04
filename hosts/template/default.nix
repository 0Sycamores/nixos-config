{ config, pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware.nix # 这个文件会在安装时由脚本生成
  ];

  # 必须开启 Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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

  # 初始用户 (密码是 1)
  users.users.root.initialPassword = "1";

  # 常用软件
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
  ];

  system.stateVersion = "24.11"; # 保持和 input 版本一致
}