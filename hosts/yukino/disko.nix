{
  disko.devices.disk.main = {
    device = "/dev/nvme0n1"; 
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          start = "1M";
          end = "1G";
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
              "/@" = { 
                mountpoint = "/";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "/@home" = { 
                mountpoint = "/home"; 
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "/@nix" = { 
                mountpoint = "/nix"; 
                mountOptions = [ "compress=zstd" "noatime" ]; 
              };
              "/@snapshots" = { 
                mountpoint = "/home/.snapshots"; 
                mountOptions = [ "compress=zstd" "noatime" ]; 
              };
              "/@games" = { 
                mountpoint = "/games";
                mountOptions = [ "nodatacow" "noatime" ]; 
              };
            };
          };
        };
      };
    };
  };
}