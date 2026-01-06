{
  disko.devices.disk.main = {
    device = "__DISK_DEVICE__";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          start = "1M";
          end = "1G"; # EFI 分区大小为 1G
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ]; 
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              # 挂载根目录
              "/@" = { 
                mountpoint = "/";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              
              # 挂载 /home
              "/@home" = { 
                mountpoint = "/home"; 
                mountOptions = [ "compress=zstd" "noatime" ];
              };

              # NixOS 核心目录
              "/@nix" = { 
                mountpoint = "/nix"; 
                mountOptions = [ "compress=zstd" "noatime" ]; 
              };

              # 快照目录 (配合 snapper)
              "/@snapshots" = { 
                mountpoint = "/home/.snapshots"; 
                mountOptions = [ "compress=zstd" "noatime" ]; 
              };
              
              # # 游戏目录：禁用 CoW (nodatacow)
              # "/@games" = { 
              #   mountpoint = "/games";
              #   mountOptions = [ "nodatacow" "noatime" ]; 
              # };
            };
          };
        };
      };
    };
  };
}
