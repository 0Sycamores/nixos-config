/*
  ===================================================================================
  Nix Mirror Configuration (China)
  ===================================================================================
  配置国内镜像源以加速 Nix 下载。
  适用于位于中国大陆的物理机或虚拟机。
  海外云服务器不建议导入此模块。
*/
{ config, pkgs, ... }:

{
  nix.settings = {
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
}