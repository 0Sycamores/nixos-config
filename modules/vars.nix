/*
  ===================================================================================
  System Variables Configuration (Global)
  ===================================================================================
  此文件定义了整个 NixOS 配置中使用的全局变量。
  
  作用:
  1. 作为配置的 "Single Source of Truth" (单一事实来源)。
  2. 统一管理用户名、全名、邮箱、系统版本和时区等核心参数。
  3. 避免在多个模块中硬编码这些值，方便后续维护和迁移。
  
  使用方法:
  在其他模块中通过 `vars.variableName` 进行引用 (需在模块参数中传入 `vars`)。
*/
{
  # 主机主要用户的登录用户名
  username = "sycamore";

  # 主用户的显示名称 (用于 UI 显示等)
  userFullName = "Sycamore";

  # 主用户的电子邮箱 (用于 Git 等配置)
  userEmail = "hi@sycamore.icu";

  # NixOS 状态版本 (用于保持向后兼容性，通常对应首次安装的版本)
  stateVersion = "25.11";

  # 系统时区设置
  timeZone = "Asia/Shanghai";
}