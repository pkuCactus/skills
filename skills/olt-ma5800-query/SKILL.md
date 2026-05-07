---
name: olt-ma5800-query
description: Query Huawei MA5800 OLT device status, boards, ONTs, optical power, alarms, interfaces, MAC/ARP tables, configuration, traffic, and health via SSH CLI. Use when the user asks to query, view, check, or display any MA5800 device information. Triggers on OLT/MA5800-related queries in Chinese or English. See references/triggers.md for the full trigger phrase list. Supports natural language mapping to display commands and auto privilege mode switching.
---

# OLT MA5800 查询技能

通过 sshpass SSH 登录 MA5800 OLT CLI，**自动切换特权模式**（enable → config → mmi-mode enable），执行 display 查询命令，返回设备信息。

## 前置要求

- 本机已安装 `sshpass`
- OLT 设备 IP 可达，SSH 端口 22 开放

## 连接参数

通过环境变量配置（均为可选，有默认值）：

| 环境变量 | 默认值 |
|----------|--------|
| `OLT_IP` | `70.32.37.65` |
| `OLT_USER` | `root` |
| `OLT_PASS` | （内置默认） |
| `OLT_TIMEOUT` | `30` 秒 |

> ⚠️ **安全提示**：密码通过环境变量 `OLT_PASS` 传入，脚本内置默认值仅供首次测试。生产环境请务必覆盖为实际密码。

## 核心脚本

| 脚本 | 用途 |
|------|------|
| `scripts/olt_connect.sh` | 底层 SSH 连接，自动执行特权模式切换 |
| `scripts/olt_query.sh` | 查询入口，按类型分发命令 |
| `scripts/olt_smart_query.sh` | 智能查询，自然语言 → display 命令 |

## 使用方式

### 方式一：自然语言查询（推荐）

```bash
./scripts/olt_smart_query.sh "查询所有单板状态"
./scripts/olt_smart_query.sh "看看 0/1/1 端口 ONT 光功率"
./scripts/olt_smart_query.sh "查一下告警"
./scripts/olt_smart_query.sh "设备温度"
```

### 方式二：指定查询类型

```bash
./scripts/olt_query.sh board              # 查询单板
./scripts/olt_query.sh version            # 查询版本
./scripts/olt_query.sh ont 0 1 1 all      # 查询ONT
./scripts/olt_query.sh alarm              # 查询当前告警
./scripts/olt_query.sh interface          # 查询接口
./scripts/olt_query.sh mac-address        # 查询MAC表
./scripts/olt_query.sh temperature        # 查询温度
./scripts/olt_query.sh health             # 查询健康状态
./scripts/olt_query.sh fan                # 查询风扇/EMU
./scripts/olt_query.sh power              # 查询功率
```

### 方式三：文档搜索（不确定命令时）

```bash
./scripts/olt_smart_query.sh "search 光功率"
./scripts/olt_query.sh search 光功率
```

### 方式四：直接执行原始命令

```bash
./scripts/olt_connect.sh "display board 0"
./scripts/olt_connect.sh "display ont optical-info 0/1/1 all"
```

## 智能查询映射（核心命令）

`olt_smart_query.sh` 支持的自然语言 → 命令映射：

| 用户输入关键词 | 映射命令 | 默认参数 |
|---------------|---------|---------|
| 单板、板卡、slot | `display board` | `0` |
| 版本、软件 | `display version` | 无 |
| ONT、光猫 | `display ont info` | `0 0/1 0/1/1 all` |
| 光功率、光模块 | `display ont optical-info` | `0/1/1 all` |
| 告警、故障 | `display alarm active` | `active` |
| 接口、端口 | `display interface` | 无 |
| MAC | `display mac-address` | 无 |
| ARP | `display arp` | 无 |
| CPU、负载 | `display health` | 无 |
| 内存 | `display memory` | 无 |
| 温度 | `display temperature` | `0` |
| 配置 | `display current-configuration` | 无 |
| 业务端口 | `display service-port` | `all` |
| VLAN | `display vlan` | `all` |
| 流量 | `display port traffic` | `0/1/1` |
| 日志 | `display log` | `operation` |
| 风扇/EMU | `display emu` | 无 |
| 电源/功率 | `display power` | `0` |
| DHCP | `display dhcp server lease` | 无 |

> 完整命令速查表和 7000+ 条命令文档搜索方法，参见 `references/command-reference.md`

## 当查询无法匹配时

1. **提取关键词** — 从用户输入中提取核心名词
2. **搜索文档** — 在 `${OPENCLAW_ROOT}/ma5800_md/cmd/` 目录搜索相关 Markdown 文档
3. **查看命令格式** — 提取参数说明和默认值
4. **推断参数** — 使用默认参数（`0` 机框、`0/1` 槽位、`0/1/1` 端口、`all` 全部）
5. **执行前告知** — 告诉用户将要执行的命令和参数含义
6. **如果失败** — 重新查文档，或询问用户具体参数

> 详细的失败处理流程和参数推断规则，参见 `references/troubleshooting.md`

## 参考文档

| 文件 | 内容 | 何时加载 |
|------|------|---------|
| `references/command-reference.md` | 完整命令速查 + 7000+ 命令搜索方法 | 需要完整命令列表时 |
| `references/troubleshooting.md` | 故障排查、分页处理、CLI 模式、参数推断规则 | 命令执行失败或需深入了解时 |
| `references/triggers.md` | 完整触发词列表（中英文） | 扩展触发识别时 |

---

## 返回结果示例

```
[OLT连接] root@70.32.37.65
[前置步骤] enable → config → mmi-mode enable
[执行命令] display board 0
========================================
  ------------------------------------------------------------------------
  Board Name        : H901MPLA
  Board Type        : MPLA
  BarCode           : 03023JTP10B2001234
  Status            : Normal
  ...
  ------------------------------------------------------------------------
```

## 故障速查

| 问题 | 解决 |
|------|------|
| `sshpass: command not found` | `sudo apt-get install sshpass` |
| SSH 连接超时 | 检查 OLT_IP 和端口 22 |
| 认证失败 | 检查用户名和密码 |
| 命令执行失败 | 用 `search` 模式查看正确命令格式 |
| 命令不完整 | 参数缺失，查看文档确认必需参数 |

> 完整故障排查、分页处理、CLI 模式说明，参见 `references/troubleshooting.md`
