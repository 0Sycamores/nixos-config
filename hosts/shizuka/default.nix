{ config, pkgs, ... }:

{
  # macOS 基础配置
  networking.hostName = "shizuka";
  networking.computerName = "shizuka";

  # Nix 配置
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # 必须，为了向后兼容
  system.stateVersion = 5; 
}