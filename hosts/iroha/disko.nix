/*
  ===================================================================================
  Disko Partitioning Configuration for Host 'iroha'
  ===================================================================================
  此文件使用 Disko 工具定义磁盘分区布局。
  
  磁盘: /dev/sda (虚拟机或物理硬盘)
  分区方案: GPT
  
  布局:
  1. ESP (EFI System Partition): 1GB, FAT32, 挂载于 /boot
  2. Root (根分区): 剩余空间, Btrfs
  
  Btrfs 子卷策略:
  - @ (root): 根目录 /
  - @home: 用户家目录 /home
  - @nix: Nix store /nix (避免系统回滚时重新下载包)
  - @log: 日志目录 /var/log (避免回滚丢失日志)
  - @snapshots: Btrfs 快照存放点
  - @downloads/videos/games: 媒体/游戏目录，禁用 COW (Copy-on-Write) 以提升性能
*/
{ vars, ... }:

{
  disko.devices.disk.main = {
    device = "/dev/sda"; # 目标磁盘设备路径
    type = "disk";
    content = {
      type = "gpt"; # 使用 GPT 分区表
      partitions = {
        # EFI 系统分区 (Boot Loader)
        ESP = {
          priority = 1;      # 分区优先级
          name = "ESP";      # 分区名称
          start = "1M";      # 起始位置 (留空 1M 用于对齐)
          end = "1G";        # 大小 1GB
          type = "EF00";     # EFI 分区类型代码
          content = {
            type = "filesystem";
            format = "vfat"; # FAT32 格式
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ]; # 仅 root 可读写
          };
        };
        
        # 根分区 (Btrfs)
        root = {
          size = "100%"; # 占用剩余所有空间
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ]; # 强制格式化
            
            # Btrfs 子卷定义
            subvolumes = {
              # 根文件系统
              "/@" = { 
                mountpoint = "/";
                mountOptions = [ "compress=zstd" "noatime" ]; # 启用 zstd 压缩，禁用访问时间更新
              };
              
              # 用户家目录
              "/@home" = { 
                mountpoint = "/home";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              
              # Nix Store (独立子卷)
              "/@nix" = { 
                mountpoint = "/nix";
                mountOptions = [ "compress=zstd" "noatime" ]; 
              };
              
              # 系统日志 (独立子卷)
              "/@log" = {
                mountpoint = "/var/log";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              
              # 快照目录
              "/@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              
              # 下载目录 (禁用 COW)
              "/@downloads" = {
                mountpoint = "/home/${vars.username}/Downloads";
                mountOptions = [ "nodatacow" "noatime" ]; # nodatacow 提升大文件写入性能
              };
              
              # 视频目录 (禁用 COW)
              "/@videos" = {
                mountpoint = "/home/${vars.username}/Videos";
                mountOptions = [ "nodatacow" "noatime" ];
              };
              
              # 游戏目录 (禁用 COW)
              "/@games" = {
                mountpoint = "/home/${vars.username}/Games";
                mountOptions = [ "nodatacow" "noatime" ];
              };
            };
          };
        };
      };
    };
  };
}