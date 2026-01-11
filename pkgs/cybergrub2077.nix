{ lib, stdenv, fetchFromGitHub, logoName ? "samurai" }:

stdenv.mkDerivation rec {
  pname = "cyber-grub-2077";
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "adnksharp";    # GitHub 用户名/组织名
    repo = "CyberGRUB-2077";   # 仓库名
    rev = "${version}";   # Tag 或 Commit Hash
    hash = "sha256-0axygrxkdlg2xr2ixxb3dwn5f9ka73gw00p3dxbnham9akwj036n";
  };

  installPhase = ''
    mkdir -p $out
    
    # 1. 将子目录中的主题文件复制到主输出目录（扁平化文件结构）
    cp -r CyberGRUB-2077/* $out/

    # 2. 从 img/logos 文件夹中选择徽标，并将其另存为 logo.png
    if [ -f "img/logos/${logoName}.png" ]; then
      cp "img/logos/${logoName}.png" $out/logo.png
    else
      echo "Warning: The logo '${logoName}' does not exist, using the default 'samurai'."
    fi
  '';

  meta = with lib; {
    description = "Cyberpunk 2077 inspired GRUB theme";
    homepage = "https://github.com/adnksharp/CyberGRUB-2077";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
