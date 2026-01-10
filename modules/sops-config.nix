/*
  ===================================================================================
  SOPS Secrets Management Configuration
  ===================================================================================
  该模块配置 SOPS (Secrets OPerationS) 用于加密和管理敏感信息。
  
  功能:
  1. 指定密钥文件位置 (age keys)。
  2. 定义敏感信息文件 (secrets.yaml)。
  3. 声明具体的 secrets 并设置其权限。
  
  注意:
  加密文件 (secrets.yaml) 应提交到 Git，但 key 文件绝对不能提交。
*/
{ config, ... }:

{
  sops = {
    # 默认 SOPS 文件路径 (相对于当前文件或使用绝对路径)
    defaultSopsFile = ../secrets/secrets.yaml;
    
    # 默认文件格式 (YAML, JSON, BINARY 等)
    defaultSopsFormat = "yaml";

    # Age 密钥相关配置
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.sshKeyPaths = [ ]; # 设置空的 SSH KEY 路径，强制使用 Age Key

    # 声明 Secrets (敏感信息)
    secrets = {
      # Root 用户密码 Hash
      root_password = {
        neededForUsers = true; # 指示该 secret 在用户创建/修改时需要
      };

      # 主用户密码 Hash
      user_password = {
        neededForUsers = true;
      };
    };
  };
}
