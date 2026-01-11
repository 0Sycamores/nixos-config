/*
  ===================================================================================
  Boot & Kernel Configuration
  ===================================================================================
  此模块定义了物理机的引导和内核配置。
  
  包含:
  1. 启动引导 (Bootloader - GRUB)
  2. 内核参数与模块管理
  3. 内存管理 (ZRAM)
  
  注意: 
  此模块通常仅适用于物理机或完整虚拟机。
  WSL 或特殊嵌入式设备可能不需要此模块。
*/
{ config, pkgs, ... }:

{
  # =================================================================================
  # Bootloader (GRUB)
  # =================================================================================

  # 禁用 systemd-boot, 使用 GRUB
  boot.loader.systemd-boot.enable = false;
  
  # 允许修改 EFI 变量
  boot.loader.efi.canTouchEfiVariables = true;

  # GRUB 引导加载程序配置
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";      # EFI 系统不需要指定设备
    useOSProber = true;    # 自动检测其他操作系统
    default = "saved";     # 记住上次选择的启动项
    # CyberGrub-2077 主题配置
    theme = pkgs.cybergrub2077;
  };

  # =================================================================================
  # Kernel Settings
  # =================================================================================

  # 内核参数调优
  boot.kernelParams = [
    "nowatchdog"      # 禁用硬件看门狗
    "zswap.enabled=0" # 禁用 ZSwap (使用 ZRam 代替)
    "loglevel=5"      # 设置引导日志级别
  ];

  # 禁用不需要的内核模块
  boot.blacklistedKernelModules = [
    "iTCO_wdt"     # Intel Watchdog
    "sp5100_tco"   # AMD/ATI Watchdog
  ];

  # =================================================================================
  # Memory & Performance
  # =================================================================================

  # 启用 ZRam (内存压缩交换)
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50; # 使用 50% 内存作为 ZRam
}