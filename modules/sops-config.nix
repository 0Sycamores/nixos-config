{ config, ... }:

{ 
  sops = {
    # 加密文件路径 
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.keyFile = "/var/lib/sops-nix/key.txt";

    # 声明要解密的字段
    secrets = {
      # Root 密码
      root_password = {
        neededForUsers = true;
      };
      
      # Weel 用户密码
      user_password = {
        neededForUsers = true;
      };
    };
  }  
}
