{
  description = "Sycamore's NixOS Install Flake";

  inputs = {
    # 锁定版本为 25.11
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    
    # 磁盘分区工具
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }: {
    nixosConfigurations = {
      # 最小化安装
      "minimal" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/minimal/default.nix
        ];
      };
    };
  };
}