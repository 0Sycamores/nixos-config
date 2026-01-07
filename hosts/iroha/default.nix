{ config, pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../modules/system-base.nix
    ../../modules/sops-config.nix
  ];

  networking.hostName = "iroha";

  # 该机器特定的配置写在这里

  system.stateVersion = "25.11";
}