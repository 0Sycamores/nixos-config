# ===================================================================================
# Nix Mirror Configuration (China)
# ===================================================================================
# 配置国内镜像源以加速 Nix 下载。
# 适用于位于中国大陆的物理机或虚拟机。
# 海外云服务器不建议导入此模块。
# ===================================================================================
{ config, pkgs, ... }:

{
  nix.settings = {
    # 配置二进制缓存服务器 (Substituters)
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store" # USTC 镜像
      "https://mirror.sjtu.edu.cn/nix-channels/store"  # 上海交大镜像
      "https://cache.nixos.org/"                         # 官方缓存 (作为备用)
    ];
    
    # 信任的公钥，用于验证缓存签名
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
}