# ConfigScope 项目申报书

## 基本信息

- 项目名称：ConfigScope：配置契约演进兼容性检查器
- 参赛者：Noverberrain
- GitHub：https://github.com/Noverberrain/ConfigScope
- 项目方向：MoonBit 开发者基础设施 / 发布安全
- 是否为移植项目：否

## 项目简介

ConfigScope 用 MoonBit 检查配置契约在版本演进中的兼容性。它比较旧版和新版的 JSON 配置快照，识别新增、值变化、删除和类型变化，并将结果分类为兼容、行为变化或破坏性变化，帮助项目在发布前发现配置升级风险。

## 核心功能与交付

- JSON 配置值和路径的确定性递归比较；
- 面向版本演进的兼容性影响分类；
- 包含路径、前后值、影响等级和统计信息的报告 API；
- 后续提供 `compat` CLI 和 GitHub Actions 门禁；
- 完整的 MoonBit 测试、README 示例、CI 和 Apache-2.0 开源代码。

## 与现有项目的边界

MoonConfigKit 适合配置文本解析、分层视图构建和单个配置视图的校验；ConfigScope 不实现 INI/Properties 解析、运行时分层合并或通用审计，而是消费已经生成的 JSON 快照，专注于跨版本兼容性判断和发布门禁。两者可以串联使用，但解决的问题不同。

## 计划与原创说明

先完成兼容性模型和稳定报告，再加入策略文件、命令行退出码和 CI 示例。项目不是现有代码移植，核心 API 面向 MoonBit 独立设计，使用 Apache-2.0 协议开源。
