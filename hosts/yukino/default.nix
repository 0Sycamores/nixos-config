{ config, pkgs, ... }:

{
  imports = [
    # 暂时只引入硬件配置，Disko 稍后根据实际硬盘配置添加
    # ./hardware.nix 
  ];

  networking.hostName = "yukino";
  time.timeZone = "Asia/Shanghai";
  
  users.users.root.hashedPassword = "!";

  system.stateVersion = "25.11";
}