/*
  ===================================================================================
  Desktop Configuration (Hosts Shared)
  ===================================================================================
  配置桌面环境相关的系统级设置。
  目前主要包含 Niri (Scrollable Tiling Wayland Compositor) 配置。
  
  使用方法:
  被桌面主机的 default.nix 导入 (e.g. hosts/iroha/default.nix).
*/
{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.niri.nixosModules.niri
  ];

  programs.niri = {
    enable = true;
  };

  # 基础 Wayland 环境依赖
  environment.systemPackages = with pkgs; [
    wl-clipboard   # 命令行剪贴板工具
    libnotify      # 通知发送工具 (notify-send)
    wayland-utils  # wayland-info 等工具
  ];

  # 推荐配置: 启用 Polkit 认证代理 (GUI 提权弹窗)
  # Niri 本身不带 Polkit agent，需要配合如 polkit-gnome 或 polkit-kde 使用
  # 这里暂时安装，具体自启动可以在 home manager 中配置
  environment.systemPackages = with pkgs; [
    polkit_gnome
  ];
}