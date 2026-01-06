{ config, pkgs, ... }:

{
  # WSL 专用配置
  wsl.enable = true;
  wsl.defaultUser = "sycamore";

  networking.hostName = "yui";
  time.timeZone = "Asia/Shanghai";

  system.stateVersion = "25.11";
}