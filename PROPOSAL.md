# ConfigScope 项目申报书

## 作者与项目信息

- 项目名称：ConfigScope：配置契约演进兼容性检查器
- 作者 / 参赛者：Noverberrain
- 联系邮箱：2455251391@qq.com
- GitHub 用户名：Noverberrain
- GitHub 仓库：https://github.com/Noverberrain/ConfigScope
- 项目方向：MoonBit 开发者基础设施 / 发布安全
- 是否为移植项目：否

## 项目简介

ConfigScope 用 MoonBit 检查配置契约在版本演进中的兼容性。它比较候选版本和多个历史版本的 JSON 配置快照，识别新增、值变化、删除和类型变化，并将结果分类为兼容、行为变化或破坏性变化，帮助项目在发布前发现配置升级风险。

## 核心功能与交付

- JSON 配置值和路径的确定性递归比较；
- 面向版本演进的兼容性影响分类；
- 包含路径、前后值、影响等级和统计信息的报告 API；
- `compat` CLI、多版本兼容性矩阵，以及可配置的 `breaking`、`behavioral`、`any` 发布门禁；
- 版本化契约清单和 `contract-check` CLI，避免每次发布手动拼接参数；
- 完整的 MoonBit 测试、README 示例、CI 和 Apache-2.0 开源代码。

## 验收说明

验收以仓库中的可运行源码、测试、示例和 GitHub Actions 为准，不依赖人工演示环境。评审者可以在仓库根目录执行以下命令：

```text
moon update
moon check --deny-warn --warn-list +73
moon test --deny-warn
moon info
moon run cmd/main -- contract-check configscope.contract.json
```

验收标准如下：

1. 项目能够通过 MoonBit 的检查和测试，当前测试套件为 102 项，全部通过且不产生被禁止的警告；
2. `contract-check` 能读取版本化契约清单，按清单比较候选配置与多个历史基线，并输出每个基线的兼容性结论和汇总结果；
3. 没有超出所选门禁等级的变化时命令返回成功；使用 `cmd/main/testdata/configscope-breaking.contract.json` 时返回非零退出码，可以直接阻止 CI 或发布流程；
4. `cmd/main/testdata` 中提供了兼容、破坏和文件缺失场景，评审者可以据此复核正常路径和错误处理；
5. GitHub Actions 会在 `main` 分支推送和 Pull Request 时自动执行依赖更新、检查、测试、生成接口校验和契约门禁，README 和 Apache-2.0 许可证作为项目交付材料一并提供。

## 与现有项目的边界

MoonConfigKit 适合配置文本解析、分层视图构建和单个配置视图的校验；ConfigScope 的主入口不实现 INI/Properties 解析、运行时分层合并或通用审计，而是消费已经生成的 JSON 快照，专注于跨版本兼容性判断和发布门禁。仓库中早期的 merge/layer/audit API 仅作为迁移基础保留在显式的 `legacy` 包中，不属于主 CLI 和主宣传边界。两者可以串联使用，但解决的问题不同。

## 计划与原创说明

当前版本已让 GitHub Actions 直接执行契约清单检查；后续可继续补充更多配置格式的导入适配。项目不是现有代码移植，核心 API 面向 MoonBit 独立设计，使用 Apache-2.0 协议开源。
