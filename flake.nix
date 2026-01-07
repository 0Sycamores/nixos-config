{
  description = "Sycamore's Multi-System Nix Config";

  inputs = {
    # 核心包仓库
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager (用户环境管理)
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # macOS 系统管理 (nix-darwin)
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # WSL 支持 (NixOS-WSL)
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    
    # 磁盘分区工具
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, darwin, nixos-wsl, disko, ... }@inputs: {
    
    # NixOS Configurations
    nixosConfigurations = {
      
      # [Test VM] - Iroha
      iroha = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/iroha/default.nix
          
          # Home Manager 模块
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sycamore = import ./home/iroha.nix;
          }
        ];
      };

      # [Desktop] - Yukino
      yukino = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # disko.nixosModules.disko # 稍后启用
          ./hosts/yukino/default.nix
        ];
      };

    };

    # Expose Disko package for installation script
    packages.x86_64-linux.disko = disko.packages.x86_64-linux.disko;
  };
}