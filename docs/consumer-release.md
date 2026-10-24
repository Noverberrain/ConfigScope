# 消费方版本绑定与回归归因（仓库新增，尚未发布）

本轮核心 API 为 `ConfigConsumerBinding::new` 和
`ConfigConsumerReleaseReport::check`，均由根包导出。
它们补充版本关联，不替代现有 `contract-check`；版本绑定 CLI 见文末。

## 输入与关系

每条 binding 显式绑定：消费方名称、版本、历史快照标签、规则对象和历史
配置对象。一次检查使用同一个候选配置；每条 binding 用自己的同一份规则
分别检查历史和候选。所有传入版本均视为仍需支持，不自动推断版本范围。
标签由调用者提供，不证明快照来源，不进行文件持久化或版本自动发现。

## 可复现案例

`consumer_release_test.mbt` 中的首个测试绑定同一服务的两个版本：
规则要求 `port` 为 1～65535 的数值、`token` 为必填字符串。

| 绑定 | 历史配置 | 候选配置 | 归因 |
|---|---|---|---|
| service@v1 / snapshot-v1 | `{"port":80,"token":"old"}` | `{"port":80}` | token 缺失为新增违规 |
| service@v2 / snapshot-v2 | `{"port":0}` | `{"port":80}` | token 缺失为已有违规；port 下限问题已修复 |

因此同一个候选、同一个 token 问题，在不同历史绑定下归因不同。
两个版本都拒绝候选，整体 `passes()` 为 false；不能因“不是新增问题”就放行。
另一测试为 v2 绑定不要求 token 的规则，证明规则由版本绑定而非全局套用。

```sh
moon test consumer_release_test.mbt --deny-warn
```

## 精确边界

- 违规身份是 `(路径, 问题种类)`；同路径从类型错误变为越界，计为旧问题
  已修复、新问题引入，而不是已有问题。已有问题不表示配置值相同。
- 结果按名称、版本字典序排列（不是语义版本排序），每类问题按路径排序。
- 空支持集合和重复名称／版本组合报错；空白名称、版本、快照标签报错。
- `passes()` 仅表示所有绑定版本的候选校验通过，不包含结构差异门禁。
- 已有违规仍阻断；归因用于解释，不是隐式豁免策略。
- 已增加声明内的有效值与受限的逐字段规则演进分析，详见后文；
  不证明任意业务兼容。

## 第二轮：默认值与条件启停的有效值分析（尚未发布）

同一绑定契约分别选择历史与候选的声明值：条件不成立为 `Inactive`，
字段存在为 `Explicit`，字段缺失但有默认值为 `Default`，否则为 `Missing`。
显式 null 不会被默认值覆盖。仅分析声明路径；不修改输入或执行实际应用。

| 历史 timeout | 候选 timeout | 消费方声明默认值 | 来源变化 | 有效值变化 |
|---|---|---|---|---|
| 30 | 缺失 | v1：30 | Explicit → Default | 否 |
| 30 | 缺失 | v2：10 | Explicit → Default | 是 |

可执行案例为 `consumer_effective_test.mbt` 的首个测试：

```sh
moon test consumer_effective_test.mbt --deny-warn
```

原有 `passes()` 仍仅判断候选是否满足全部绑定规则；上述两个版本均通过。
新增 `preserves_effective_values()` 是独立、显式调用的保守检查，v1 为 true、
v2 为 false，整体为 false。它不是现有 CLI 的默认发布策略。

每条回归记录提供 `effective_comparable()` 和 `effective_changes()`：
- 历史与候选都满足同一契约才可比较；任一违规，整条绑定标为不可比较，
  变化数组为空，有效值保持检查为 false。不推测非法数据的读取行为。
- 变化条目仅包含路径、前后来源和 `value_changed()`，不返回配置值。
- 相等值从显式值切换到默认值仍记录来源变化，但不阻断有效值保持检查。
- 条件启停、缺失与存在之间的切换也视为声明选择状态变化；不能从中推断
  实际业务影响严重程度。条件始终复用既有默认值与单相等判断语义。
- 对象用结构相等比较，数组比较整个值；不把未声明路径计为消费方读取。
- 不可比较不等于不兼容已被证明；返回 false 表示无法确认保持不变。
- 名称、版本与快照标签沿用第一轮绑定；已有文末的 CLI 提示输出，但有效值保持尚非 CLI 门禁，且尚未发布到 Mooncakes。

## 第三轮：逐字段契约演进（尚未发布）

`old_contract.evolution_to(new_contract)` 返回按路径排序的变更条目：
路径、`impact()` 和稳定原因码 `reason()`，不返回规则中的配置值。
输入必须先通过既有契约解析器；本 API 不接受未验证的原始规则。

| 分类 | 含义（仅针对该字段声明的输入集合） |
|---|---|
| Equivalent | 语法变化，但已支持语义内的接纳集合相同 |
| Tightened | 新规则接纳集合为旧规则的严格子集 |
| Relaxed | 新规则接纳集合为旧规则的严格超集 |
| Incomparable | 两边各有能接受而对方不能接受的输入 |
| Unknown | 本轮不能证明包含关系；不代表兼容或不兼容 |

支持：单独改变必填标记、两个显式枚举集合的包含关系，以及保持数值类型和
integer 模式不变的上下限变化。整数上下限先向内取整；相同显式枚举已被
新旧解析器校验过时，边界变化不再改变接纳集合。相同默认值可以使必填变化
不影响缺失字段的接纳，但不意味着其他默认值行为都已完成分析。

以下情况保守返回 Unknown：规则新增／移除、默认值变动、类型或 integer
模式变化、条件规则的变动、多个约束维度同时改变、同契约存在祖先／后代
重叠路径，以及有限枚举与未限定值域之间的切换。未变化规则不返回条目。

### 历史、规则和候选关联案例

历史快照 release-30 为 `{"timeout":30}`，候选为 `{"timeout":45}`：
- service@v1 绑定规则 `1 <= timeout <= 60`；
- service@v2 绑定规则 `1 <= timeout <= 40`；
- 两个版本都绑定历史快照 release-30，声明仍需同时支持。

演进分析指出 timeout 上限收紧；回归分析指出 v1 接受候选，v2 新增
AboveMaximum。由于要求同时支持 v1、v2，候选接纳门禁失败。
这不是“数值变化就阻断”：若候选为 35，两个版本的接纳检查均可通过，
是否允许读取值变化仍由第二轮的独立有效值保持策略决定。

```sh
moon test consumer_evolution_test.mbt --deny-warn
```

该文件最后一个测试联合演进 API 与版本绑定 API 复现上述案例；另有有界
样本对照测试验证范围分类与实际校验结果一致，但不将有限样本当作通用证明。

本轮不是整个契约的蕴含求解器：字段间关系可能影响整体可满足性，不能用
若干 Relaxed／Equivalent 条目直接推断全局兼容。没有自动发布决策 API，
也没有隐式替换版本所绑定的规则或改动现有 CLI 门禁。报告提供规则演进证据，
实际候选仍需针对所有支持版本执行检查；Unknown 不能用于自动放行。

## 第四轮：版本绑定文件与 CLI（尚未发布）

新增独立命令 `release-check <release.json>`，不改变 `contract-check`。
清单示例（两个版本共享历史配置，但绑定不同规则）：

```json
{
  "candidate": "empty.json",
  "bindings": [
    {"consumer":"service","version":"v1","baseline_id":"release-30","contract":"v1.json","baseline":"historical.json"},
    {"consumer":"service","version":"v2","baseline_id":"release-30","contract":"v2.json","baseline":"historical.json"}
  ]
}
```

candidate、bindings 及绑定内所有字段必填；字符串不得为空白。bindings 至少一项，禁止重复 consumer/version。
可选 policy 的含义见下一节。
未知字段、错拼字段及多余选项均报错，不接受忽略规则或版本跳过开关。
路径相对于清单所在目录解析，也允许绝对路径；这不是受限文件访问沙箱。
baseline_id 为调用者标签，不证明文件内容身份或来源。

仓库根目录运行：

```sh
moon run cmd/main -- release-check cmd/main/testdata/release/defaults.release.json
moon run cmd/main -- release-check cmd/main/testdata/release/rejected.release.json
```

第一条退出码 0：两个版本都接受缺失字段，但报告分别展示 v1 的默认值接管
不改变有效值、v2 的默认值接管改变有效值。第二条为预期失败，退出码 1：
候选 timeout=45，v1 接受，v2 新增 above_maximum 违规。

文本报告按消费方／版本排序，列出历史标签、规则和快照文件路径，以及新增、
已有、已修复违规和不含配置值的有效值来源变化。所有用户标签和路径经 JSON
字符串转义，避免换行伪造报告。非法快照的有效值分析明确标为不可比较。

**未填写 policy 时，退出码仍只代表候选对全部绑定规则的接纳结果。**
有效值变化在默认模式下为提示，并非放行保证。严格策略见下一节。
规则演进仍为库 API，不自动从清单中推断新旧规则关系。
仅支持文本，不支持 `--format`，不修改旧的结构门禁。
命令只读文件，不写快照、不发布配置。

## 第五轮：显式发布策略与阻断原因（尚未发布）

清单顶层可增加 `"policy": "preserve-effective"`；省略时为 `accept`。
仅接受这两个精确字符串，null、拼写错误和未知策略都会失败。
不支持 CLI 覆盖，也不提供按版本跳过或忽略路径的豁免。

| 策略 | 允许条件 |
|---|---|
| accept（默认） | 候选满足全部绑定版本规则；历史已有违规仍不能在候选中残留 |
| preserve-effective | 上述条件成立，且每个版本的历史／候选都合法可比较，声明有效值与选择状态均保持 |

来源从 explicit 切为 default，但值相等时不阻断；条件启停、缺失／存在切换
属于选择状态变化，会阻断严格模式。未声明字段不属于本策略保证范围。
历史不合法而候选已修复时，accept 可以允许，但严格模式因无法比较而阻断。

文本报告保留 `candidate acceptance`，另列 `policy`、逐版本 `release allowed`
及总体 `release decision`，避免把“校验通过”误读为“策略允许发布”。
阻断代码为：
- `candidate_<issue_kind>`：候选仍违反规则，附路径；
- `effective_value_changed`：声明有效值或选择状态改变，附路径；
- `effective_incomparable`：历史或候选非法，无法进行有效值比较。

阻断原因与退出决策复用同一计算函数，不包含配置值；前文的消费方版本、
历史标签和规则／快照文件信息用于定位原因。

```sh
# 两个版本均接受候选，但 v2 有效值改变：预期退出码 1
moon run cmd/main -- release-check cmd/main/testdata/release/preserve.release.json
# 仅绑定 v1，来源改变但有效值相等：预期退出码 0
moon run cmd/main -- release-check cmd/main/testdata/release/preserve-equal.release.json
# 候选合法、历史非法，无法比较：预期退出码 1
moon run cmd/main -- release-check cmd/main/testdata/release/preserve-unknown.release.json
```

`allowed` 仅表示所声明策略成立，不保证运行时或未声明业务关系安全。
本轮不将规则演进诊断自动合并为发布策略；它的 Unknown 与这里的快照不可比较
是不同概念，不能互相替代。机器可读 JSON 报告仍未接入。
