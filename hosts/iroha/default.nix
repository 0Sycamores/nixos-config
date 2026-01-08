{ config, pkgs, inputs, vars, ... }:

{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    
    ./disko.nix
    ./hardware.nix
    ../../modules/system-base.nix
    ../../modules/sops-config.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs vars; };
    users.${vars.username} = import ../../home/iroha.nix;
  };

  networking.hostName = "iroha";

  # 该机器系统级特定的配置写在这里

  system.stateVersion = vars.stateVersion;
}