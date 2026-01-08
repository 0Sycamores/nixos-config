{ config, pkgs, inputs, vars, ... }:

{
  imports = [
    # inputs.disko.nixosModules.disko # 稍后启用
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
    users.${vars.username} = import ../../home/yukino.nix;
  };

  networking.hostName = "yukino";

  # 该机器系统级特定的配置写在这里

  system.stateVersion = vars.stateVersion;
}