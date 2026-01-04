{
  disko.devices.disk.main = {
    device = "__DISK_DEVICE__"; # <--- 这是一个占位符，不要手动改
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          start = "1M";
          end = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            # 设置权限掩码为 0077 (即 700 权限，仅 root 可读写)
            mountOptions = [ "umask=0077" ]; 
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ]; # 强制格式化
            subvolumes = {
              "/@" = { mountpoint = "/"; };
              "/@home" = { mountpoint = "/home"; };
              "/@nix" = { mountpoint = "/nix"; mountOptions = [ "compress=zstd" "noatime" ]; };
            };
          };
        };
      };
    };
  };
}