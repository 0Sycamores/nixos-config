final: prev: {
  # 使用 callPackage 来调用 nix 文件
  cybergrub2077 = prev.callPackage ./cybergrub2077.nix { };
}