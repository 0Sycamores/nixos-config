{
  description = "Sycamore's Multi-System Nix Config";

  inputs = {
    # 核心包仓库
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # 用户环境管理
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # macOS 系统管理
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # WSL 支持
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    
    # 磁盘分区工具
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # 密钥管理
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, darwin, nixos-wsl, disko, sops-nix, ... }@inputs:
    let
      vars = import ./modules/vars.nix;
    in
    {
    
    nixosConfigurations = {

      # [主力机] Yukino
      yukino = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs vars; };
        modules = [
          ./hosts/yukino/default.nix
        ];
      };
      
      # [虚拟机] Iroha
      iroha = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs vars; };
        modules = [
          ./hosts/iroha/default.nix
        ];
      };
    };

    # 暴露 Disko 包供安装脚本使用
    packages.x86_64-linux.disko = disko.packages.x86_64-linux.disko;
  };
}