/*
  ===================================================================================
  NixOS Configuration Flake
  ===================================================================================
  这是整个 NixOS 配置的入口点 (Flake)。
  
  作用:
  1. 定义输入源 (Inputs): 指定 Nixpkgs、Home Manager 等依赖的版本。
  2. 定义输出 (Outputs): 构建 NixOS 系统配置、软件包等。
  3. 统一管理多主机配置 (yukino, iroha)。
  
  使用方法:
  - 部署 yukino: sudo nixos-rebuild switch --flake .#yukino
  - 部署 iroha: sudo nixos-rebuild switch --flake .#iroha
*/
{
  description = "Sycamore's Multi-System Nix Config";

  # =================================================================================
  # Inputs (依赖源)
  # =================================================================================
  inputs = {
    # NixOS 官方软件源 (使用 unstable 分支以获取最新软件)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager (用户环境管理)
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs"; # 强制使用与系统一致的 nixpkgs

    # Nix-Darwin (macOS 支持 - 暂时保留，可能未来用到)
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # NixOS WSL (WSL 支持)
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # Disko (声明式磁盘分区工具)
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # SOPS-Nix (敏感信息加密管理)
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  # =================================================================================
  # Outputs (构建结果)
  # =================================================================================
  outputs = { self, nixpkgs, home-manager, darwin, nixos-wsl, disko, sops-nix, ... }@inputs:
    let
      # 导入全局变量模块，供后续配置使用
      vars = import ./modules/vars.nix;
      # 导入自定义pkgs的 overlay
      customPkgsOverlay = import ./pkgs/overlay.nix;
    in
    {
    
    # NixOS 系统配置定义
    nixosConfigurations = {

      # 主机: yukino
      yukino = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # 将 inputs 和 vars 传递给模块
        specialArgs = { inherit inputs vars; };
        modules = [
          # 导入主机特定配置
          ./hosts/yukino/default.nix

          # 导入自定义包
          {
            nixpkgs.overlays = [ customPkgsOverlay ]
          }
        ];
      };
      
      # 主机: iroha
      iroha = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs vars; };
        modules = [
          ./hosts/iroha/default.nix
        ];
      };
    };

    # 导出 Disko 工具包 (方便在未安装 NixOS 的环境中使用)
    packages.x86_64-linux.disko = disko.packages.x86_64-linux.disko;
  };
}