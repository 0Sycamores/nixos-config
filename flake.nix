{
  description = "Automated NixOS Install Flake";

  inputs = {
    # 锁定版本为 25.11
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    
    # 磁盘分区工具
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }: {
    nixosConfigurations = {
      # 这里的名字 "new-machine" 很重要，install.sh 脚本里会用到
      "new-machine" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/template/default.nix
        ];
      };
    };
  };
}