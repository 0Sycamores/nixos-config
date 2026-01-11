# ===================================================================================
# Desktop Configuration (Hosts Shared)
# ===================================================================================
# 配置桌面环境相关的系统级设置。
# 目前主要包含 Niri (Scrollable Tiling Wayland Compositor) 配置。
#
# 使用方法:
# 被桌面主机的 default.nix 导入 (e.g. hosts/iroha/default.nix).
# ===================================================================================
{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.niri.nixosModules.niri
  ];

  programs.niri.enable = true;
  programs.niri.package = pkgs.niri-unstable;

  # PipeWire 音频 (Wayland 标配)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Polkit 认证服务 (解决 GUI 应用无法获取 root 权限的问题)
  security.polkit.enable = true;

  # 字体配置
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans  # 思源黑体
    noto-fonts-cjk-serif # 思源宋体
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono # 代码和图标字体
  ];

  # 基础 Wayland 环境依赖
  environment.systemPackages = with pkgs; [
    wl-clipboard   # 命令行剪贴板工具
    libnotify      # 通知发送工具 (notify-send)
    wayland-utils  # wayland-info 等工具
  ];
}