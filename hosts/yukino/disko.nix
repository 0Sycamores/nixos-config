{ vars, ... }:

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
              "/@log" = {
                mountpoint = "/var/log";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "/@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "/@downloads" = {
                mountpoint = "/home/${vars.username}/Downloads";
                mountOptions = [ "nodatacow" "noatime" ];
              };
              "/@videos" = {
                mountpoint = "/home/${vars.username}/Videos";
                mountOptions = [ "nodatacow" "noatime" ];
              };
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