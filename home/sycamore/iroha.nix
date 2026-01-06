{ config, pkgs, ... }:

{
  home.username = "sycamore";
  home.homeDirectory = "/home/sycamore";

  # 启用 Home Manager 管理 Shell 环境
  programs.bash.enable = true;

  # 基础工具
  home.packages = with pkgs; [
    fastfetch
    htop
    ripgrep
    fd
    tree
  ];

  # Git 配置
  programs.git = {
    enable = true;
    userName = "Sycamore";
    userEmail = "hi@sycamore.icu";
  };

  # Vim 配置
  programs.vim = {
    enable = true;
    defaultEditor = true;
    extraConfig = ''
      set number
      set relativenumber
      syntax on
    '';
  };

  # 必须开启，为了让 Home Manager 管理自己
  programs.home-manager.enable = true;

  # 状态版本 (必须匹配引入时的版本)
  home.stateVersion = "25.11";
}