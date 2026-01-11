# ===================================================================================
# Home Manager Configuration for Host 'iroha'
# ===================================================================================
# 此文件定义了主机 'iroha' 特有的 Home Manager 配置。
#
# 功能:
# 1. 导入通用 Home Manager 配置 (hosts/common.nix)。
# 2. 可在此处添加仅针对 'iroha' 主机的用户级定制 (如特定软件包、Git 配置覆盖等)。
#
# 当前状态:
# 已配置 Niri 桌面环境。
# ===================================================================================
{ config, pkgs, inputs, ... }:

{
  imports = [
    # 导入通用配置模块
    ../common.nix
    # 注意：inputs.niri.homeModules.niri 会由系统级模块自动导入，此处无需重复
  ];

  home.packages = with pkgs; [
    alacritty       # 终端
    firefox         # 浏览器
    fuzzel          # 启动菜单
  ];

  programs.niri.settings = {
    # === 启动项 ===
    spawn-at-startup = [
      { command = [ "fcitx5" "-d" ]; }
    ];

    # === 输入设置 ===
    input = {
      keyboard.xkb.layout = "us";
      touchpad = {
        tap = true;
        dwt = true;
      };
    };

    # === 快捷键绑定 (Binds) ===
    binds = {
      # 核心操作
      "Mod+Shift+E".action.quit = [];
      "Mod+Q".action.close-window = [];

      # --- 关键应用 ---
      "Mod+Return".action.spawn = "alacritty";
      "Mod+D".action.spawn = "fuzzel";

      # --- 窗口管理 ---
      # Niri 是无限卷动平铺，左右移动列
      "Mod+Left".action.focus-column-left = [];
      "Mod+Right".action.focus-column-right = [];
      "Mod+H".action.focus-column-left = [];
      "Mod+L".action.focus-column-right = [];

      # 移动窗口位置
      "Mod+Shift+Left".action.move-column-left = [];
      "Mod+Shift+Right".action.move-column-right = [];
      
      # 调整窗口大小
      "Mod+R".action.switch-preset-column-width = [];
      "Mod+F".action.maximize-column = [];
      "Mod+Shift+F".action.fullscreen-window = [];

      # 截图 (存到家目录)
      "Print".action.screenshot = [];
    };
  };
}