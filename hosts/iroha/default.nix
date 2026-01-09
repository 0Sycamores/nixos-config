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

    # 2. 修正挂载点权限
  # 确保 Downloads, Videos, Games 属于用户，而不是 root
  systemd.tmpfiles.rules = [
    "d /home/${vars.username}/Downloads 0755 ${vars.username} users -"
    "d /home/${vars.username}/Videos 0755 ${vars.username} users -"
    "d /home/${vars.username}/Games 0755 ${vars.username} users -"
  ];

  system.stateVersion = vars.stateVersion;
}