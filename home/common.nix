/*
  ===================================================================================
  Home Manager Common Configuration
  ===================================================================================
  此文件定义了所有用户的通用 Home Manager 配置。
  
  包含:
  1. 基础用户目录和 Shell 配置 (Bash/Fish)
  2. 代理函数脚本 (Fish)
  3. 常用 CLI 工具 (fastfetch, htop 等)
  4. Git 全局配置
  5. Vim 编辑器配置
  6. Home Manager 自身状态管理
  
  使用方法:
  被具体用户的 home.nix 导入 (e.g. home/yukino.nix).
*/
{ config, pkgs, vars, ... }:

{
  # =================================================================================
  # Basic User Info
  # =================================================================================
  
  # 用户名和家目录设置 (引用全局 vars)
  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";


  # XDG 标准用户目录管理
  xdg.userDirs = {
    enable = true;
    createDirectories = true; # 自动创建缺失的目录 (如 ~/Downloads, ~/Pictures 等)
  };

  # =================================================================================
  # Shell Configuration
  # =================================================================================

  # 启用 Bash (作为基础 Shell)
  programs.bash.enable = true;

  # Fish Shell 配置 (作为交互式 Shell)
  programs.fish = {
    enable = true;
    
    # Fish 函数定义
    functions = {
      # 开启代理 (proxy_on [address])
      # 默认地址: 127.0.0.1:10808
      proxy_on = ''
        set -l proxy_addr $argv[1]
        if test -z "$proxy_addr"
            set proxy_addr "127.0.0.1:10808"
        end
        
        set -gx http_proxy "http://$proxy_addr"
        set -gx https_proxy "http://$proxy_addr"
        set -gx HTTP_PROXY "http://$proxy_addr"
        set -gx HTTPS_PROXY "http://$proxy_addr"
        set -gx no_proxy "localhost,127.0.0.1,::1"
        
        echo "✅ 代理已开启: http://$proxy_addr"
      '';
      
      # 关闭代理 (proxy_off)
      proxy_off = ''
        set -e http_proxy
        set -e https_proxy
        set -e HTTP_PROXY
        set -e HTTPS_PROXY
        set -e no_proxy
        
        echo "❌ 代理已关闭"
      '';
      
      # 查看代理状态 (proxy_status)
      proxy_status = ''
        if set -q http_proxy
            echo "✅ 代理已开启: $http_proxy"
        else
            echo "❌ 代理未开启"
        end
      '';
    };
    
    # Shell 缩写 (Abbreviations)
    shellAbbrs = {
      pon = "proxy_on";
      poff = "proxy_off";
      pst = "proxy_status";
    };
  };

  # =================================================================================
  # Packages
  # =================================================================================

  # 用户级常用软件包
  home.packages = with pkgs; [
    fastfetch   # 快速系统信息显示
    htop        # 交互式进程查看器
    ripgrep     # 快速 grep 替代品 (rg)
    fd          # 快速 find 替代品
    tree        # 目录树状显示
  ];

  # =================================================================================
  # Git Configuration
  # =================================================================================

  # Git 全局配置
  programs.git = {
    enable = true;
    settings.user.name = vars.userFullName;
    settings.user.email = vars.userEmail;
  };

  # =================================================================================
  # Editor Configuration
  # =================================================================================

  # Vim 配置
  programs.vim = {
    enable = true;
    defaultEditor = true; # 设置为默认编辑器 ($EDITOR)
    extraConfig = ''
      set number          " 显示行号
      set relativenumber  " 显示相对行号
      syntax on           " 开启语法高亮
    '';
  };

  # =================================================================================
  # Home Manager State
  # =================================================================================

  # 启用 Home Manager 自身管理
  programs.home-manager.enable = true;

  # Home Manager 状态版本 (保持兼容性)
  home.stateVersion = vars.stateVersion;
}