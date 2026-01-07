{ config, pkgs, ... }:

{
  imports = [
    # 硬件配置暂时注释，Disko 配置待添加
    # ./hardware.nix
    ../../modules/system-base.nix
    ../../modules/sops-config.nix
  ];

  networking.hostName = "yukino";

  system.stateVersion = "25.11";
}