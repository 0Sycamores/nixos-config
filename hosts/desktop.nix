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

    
    # Wayland 基础工具 (配合 Niri 使用)
    # fuzzel      # 应用启动器
    # waybar      # 状态栏
    # dunst       # 通知守护进程
    # alacritty   # 终端模拟器 (GPU 加速)
    # polkit_gnome
  ];
}