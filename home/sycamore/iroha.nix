{ config, pkgs, ... }:

{
  home.username = "sycamore";
  home.homeDirectory = "/home/sycamore";

  # 启用 Home Manager 管理 Shell 环境
  programs.bash.enable = true;

  users.users.sycamore.shell = pkgs.fish;
  
  # Fish Shell 配置
  programs.fish = {
    enable = true;
    
    # 定义 Fish 函数
    functions = {
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
      
      proxy_off = ''
        set -e http_proxy
        set -e https_proxy
        set -e HTTP_PROXY
        set -e HTTPS_PROXY
        set -e no_proxy
        
        echo "❌ 代理已关闭"
      '';
      
      proxy_status = ''
        if set -q http_proxy
            echo "✅ 代理已开启: $http_proxy"
        else
            echo "❌ 代理未开启"
        end
      '';
    };
    
    # 快捷别名
    shellAbbrs = {
      pon = "proxy_on";
      poff = "proxy_off";
      pst = "proxy_status";
    };
  };

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