{ config, pkgs, vars, ... }:

{
  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";

  # 让 Home Manager 接管 Bash，便于环境变量管理
  programs.bash.enable = true;

  programs.fish = {
    enable = true;
    
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
    
    shellAbbrs = {
      pon = "proxy_on";
      poff = "proxy_off";
      pst = "proxy_status";
    };
  };

  home.packages = with pkgs; [
    fastfetch
    htop
    ripgrep
    fd
    tree
  ];

  programs.git = {
    enable = true;
    userName = vars.userFullName;
    userEmail = vars.userEmail;
  };

  programs.vim = {
    enable = true;
    defaultEditor = true;
    extraConfig = ''
      set number
      set relativenumber
      syntax on
    '';
  };

  # 必须开启，让 Home Manager 管理自身
  programs.home-manager.enable = true;

  home.stateVersion = vars.stateVersion;
}