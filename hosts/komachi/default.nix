{ config, pkgs, ... }:

{
  networking.hostName = "komachi";
  time.timeZone = "Asia/Shanghai";
  
  services.openssh.enable = true;

  system.stateVersion = "25.11";
}