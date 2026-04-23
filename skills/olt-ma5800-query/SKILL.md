---
name: olt-ma5800-query
description: Query Huawei MA5800 OLT device information through SSH CLI. Use when the user asks to query, view, check, or display OLT/MA5800 device status, board information, ONT status, optical power, alarms, interfaces, MAC/ARP tables, configuration, traffic statistics, or any device health information. Triggers on phrases like "查询 OLT", "查询 MA5800", "查看设备", "看看单板", "ONT 光功率", "查告警", "端口状态", "设备温度", "版本信息", "mac地址表", "arp表", "当前配置", "流量统计", "查日志", "设备健康", "风扇状态", "电源功率". Supports smart natural language query mapping to display commands. Automatically handles privilege mode switching (enable → config → mmi-mode enable).
---

# OLT MA5800 查询技能

通过 sshpass SSH 登录 MA5800 OLT CLI，**自动切换特权模式**（enable → config → mmi-mode enable），执行 display 查询命令，返回设备信息。

## 前置要求

- 本机已安装 `sshpass`
- OLT 设备 IP 可达，SSH 端口 22 开放

## 默认连接参数

| 参数 | 默认值 |
|------|--------|
 OLT_IP | `70.32.37.65` |
| OLT_USER | `root` |
| OLT_PASS | `Admin@huawei123` |
| OLT_TIMEOUT | `30` 秒 |

无需手动设置环境变量即可使用默认值。

## 核心脚本

所有脚本位于 `scripts/` 目录下：

| 脚本 | 用途 |
|------|------|
| `olt_connect.sh` | 底层 SSH 连接，**自动执行特权模式切换**，执行 CLI 命令 |
| `olt_query.sh`   | 查询入口，按类型分发命令 |
| `olt_smart_query.sh` | 智能查询，自然语言→display 命令 |

## 特权模式切换流程

脚本自动处理 CLI 模式切换：

```
SSH 登录 → enable → config → mmi-mode enable → [执行 display 命令] → return → quit
```

## 查询失败处理策略（重要！）

当用户查询**无法直接匹配**已知命令时，**不要瞎猜乱试**！按以下优先级处理：

### 第一步：文档搜索（最优先）

用关键词在 `~/.openclaw/ma5800_md/cmd/` 目录下搜索相关命令：

```bash
# 搜索文件名匹配
ls ~/.openclaw/ma5800_md/cmd/ | grep -i "<关键词>"

# 搜索内容匹配
grep -l "<关键词>" ~/.openclaw/ma5800_md/cmd/*.md

# 提取命令格式和参数说明
cat ~/.openclaw/ma5800_md/cmd/display_<命令名>.md | grep -A3 "命令格式"
cat ~/.openclaw/ma5800_md/cmd/display_<命令名>.md | grep -A10 "参数说明"
cat ~/.openclaw/ma5800_md/cmd/display_<命令名>.md | grep -B2 -A2 "举例"
```

### 第二步：智能匹配优先级

搜索后按以下优先级选择最可能的命令：

1. **精确匹配** — 命令名完全匹配用户意图（如 `ont optical-info` 匹配"光功率"）
2. **功能匹配** — 命令功能描述匹配（如 `display emu` 匹配"风扇"）
3. **参数匹配** — 命令参数包含用户提到的对象（如 `display alarm active` 匹配"告警"）
4. **模糊匹配** — 关键词在文档中出现次数最多的命令

### 第三步：参数推断

找到命令后，查看其**命令格式**和**参数说明**：

```bash
# 示例：查看 display ont optical-info 的参数
cat ~/.openclaw/ma5800_md/cmd/display_ont_optical-info.md | grep -A20 "参数说明"
```

**参数推断规则：**
- 必选参数（无方括号）— 必须提供，否则命令报错
- 可选参数（有方括号）— 可以省略
- `{ frameid | slotid }` — 二选一，通常默认选 `0` 或 `0/1`
- `[ all | ontid ]` — 可选，默认选 `all`

### 第四步：默认值策略

对于常见对象，使用以下默认参数：

| 对象 | 默认参数 | 说明 |
|------|---------|------|
| 整框/机框 | `0` | 0号机框 |
| 槽位 | `0/1` | 0框1槽 |
| PON端口 | `0/1/1` | 0框1槽1口 |
| ONT ID | `all` | 查询所有 |
| VLAN | `all` | 查询所有 |
| 业务端口 | `all` | 查询所有 |

### 第五步：执行与验证

执行前**先告诉用户**将要执行的命令：

```bash
echo "[推断] 根据您的需求，执行: display <命令> <参数>"
echo "[参数说明] <解释参数含义>"
```

如果命令执行失败（如"命令不完整"、"参数错误"），**不要继续瞎试**，而是：
1. 重新查看文档确认参数格式
2. 询问用户具体参数（如"请指定PON端口号"）
3. 或者使用 `search` 模式让用户选择

## 使用方法

### 方式一：直接执行查询（推荐）

```bash
# 使用默认连接参数（无需 export）
./scripts/olt_smart_query.sh "查询所有单板状态"
./scripts/olt_smart_query.sh "看看 0/1/1 端口 ONT 光功率"
./scripts/olt_smart_query.sh "查一下告警"
./scripts/olt_smart_query.sh "设备温度"
```

### 方式二：使用查询入口

```bash
# 查询单板
./scripts/olt_query.sh board
./scripts/olt_query.sh board 0       # 查询0框
./scripts/olt_query.sh board 0/1     # 查询0框1槽位

# 查询版本
./scripts/olt_query.sh version

# 查询 ONT
./scripts/olt_query.sh ont 0 1 1 all     # 查询0/1/1端口所有ONT
./scripts/olt_query.sh ont-optical 0/1/1 all  # 查询ONT光功率

# 查询告警
./scripts/olt_query.sh alarm
./scripts/olt_query.sh alarm history

# 其他查询
./scripts/olt_query.sh interface
./scripts/olt_query.sh mac-address
./scripts/olt_query.sh arp
./scripts/olt_query.sh cpu
./scripts/olt_query.sh memory
./scripts/olt_query.sh temperature
./scripts/olt_query.sh config
./scripts/olt_query.sh health
./scripts/olt_query.sh fan              # 查询风扇/EMU状态
./scripts/olt_query.sh power            # 查询整框功率（默认0号机框）
./scripts/olt_query.sh power 0/1           # 查询0/1槽位功率
./scripts/olt_query.sh power detail 0      # 查询整框功耗详情
./scripts/olt_query.sh port-state 0/1/1
./scripts/olt_query.sh ont-state 0/1/1
./scripts/olt_query.sh service-port
./scripts/olt_query.sh vlan
./scripts/olt_query.sh traffic 0/1/1
./scripts/olt_query.sh log
```

### 方式三：文档搜索模式

当不确定命令时，先搜索文档：

```bash
./scripts/olt_smart_query.sh "search 光功率"
./scripts/olt_query.sh search 光功率
```

输出示例：
```
=== 找到的相关命令 ===
  - display ont optical-info
    命令格式: display ont optical-info portid { all | ontid }
  - display port optic-power-threshold
    命令格式: display port optic-power-threshold frameid/slotid/portid
  - display xpon optical-parameter-threshold
    命令格式: display xpon optical-parameter-threshold
```

### 方式四：默认参数模式

查看并执行某查询类型的默认参数：

```bash
./scripts/olt_smart_query.sh "default 查询ONT"
./scripts/olt_query.sh default ont

# 输出
[默认参数] ont 0 0/1 0/1/1 all
执行: display ont info 0 0/1 0/1/1 all
```

### 方式五：随机参数模式

用于测试或探索：

```bash
./scripts/olt_smart_query.sh "random 查询光模块"
./scripts/olt_query.sh random ont-optical

# 输出
[随机参数] ont-optical 0/1/7 42
执行: display ont optical-info 0/1/7 42
```

### 方式六：直接执行原始命令

```bash
./scripts/olt_connect.sh "display board 0"
./scripts/olt_connect.sh "display ont info 0 1 1 all"
```

## 智能查询映射表

`olt_smart_query.sh` 支持的自然语言→命令映射：

| 用户输入关键词 | 映射命令 | 默认参数 |
|-------------|---------|---------|
| 单板、板卡、slot | `display board` | `0` |
| 版本、软件 | `display version` | 无 |
| ONT、光猫、ONU | `display ont info` | `0 0/1 0/1/1 all` |
| 光功率、光模块、rx、tx | `display ont optical-info` | `0/1/1 all` |
| 告警、警告、故障 | `display alarm active` | `active` |
| 接口、端口、状态 | `display interface` | 无 |
| MAC、二层地址 | `display mac-address` | 无 |
| ARP、三层地址 | `display arp` | 无 |
| CPU、负载 | `display health` | 无 |
| 内存、ram | `display memory` | 无 |
| 温度、thermal | `display temperature` | `0` |
| 配置、当前配置 | `display current-configuration` | 无 |
| 业务端口、service-port | `display service-port` | `all` |
| VLAN | `display vlan` | `all` |
| 流量、统计 | `display port traffic` | `0/1/1` |
| 日志 | `display log` | `operation` |
| 健康、综合状态 | `display health` | 无 |
| 风扇、EMU、散热、风机 | `display emu` | 无 |
| 电源、功率、功耗、供电、电池 | `display power` | `0` |
| 电源详情、功耗明细 | `display power detail` | `0` |
| DHCP | `display dhcp server lease` | 无 |

## 文档搜索与推断流程

当用户查询**不在上述映射表**中时，按以下流程处理：

### 1. 提取关键词

从用户输入中提取核心名词：
- "查询**光功率**阈值" → 关键词: `光功率`, `阈值`
- "看看**保护组**状态" → 关键词: `保护组`, `状态`
- "查**MAC**老化时间" → 关键词: `MAC`, `老化`

### 2. 搜索文档

```bash
# 在 ~/.openclaw/ma5800_md/cmd/ 目录下搜索
ls ~/.openclaw/ma5800_md/cmd/ | grep -i "光功率\|阈值"
grep -l "光功率\|阈值" ~/.openclaw/ma5800_md/cmd/*.md
```

### 3. 查看候选命令

```bash
# 查看找到命令的格式和参数
cat ~/.openclaw/ma5800_md/cmd/display_port_optic-power-threshold.md | grep -A5 "命令格式"
cat ~/.openclaw/ma5800_md/cmd/display_port_optic-power-threshold.md | grep -A15 "参数说明"
```

### 4. 推断参数

根据命令格式推断必需参数：

```markdown
命令格式: display port optic-power-threshold frameid/slotid/portid
→ 需要 1个参数: 端口号 (如 0/1/1)
→ 默认值: 0/1/1
```

### 5. 执行并反馈

```bash
echo "[推断] 您可能想查询: display port optic-power-threshold"
echo "[参数] 默认使用端口 0/1/1"
./scripts/olt_connect.sh "display port optic-power-threshold 0/1/1"
```

### 6. 如果失败

不要继续乱试！而是：
- 重新查看文档确认参数
- 询问用户具体参数
- 或者提供候选命令让用户选择

## OLT CLI 特性处理

### 分页提示
MA5800 display 命令输出超过一屏时提示 `--- More ---`。脚本通过以下方式处理：
1. 设置终端宽度为 200 字符（减少分页）
2. SSH 伪终端自动处理
3. 对 More 提示行做 sed 过滤

### 命令模式
- SSH 登录后默认处于 **用户视图**
- 脚本自动执行 `enable` → `config` → `mmi-mode enable` 进入 **MMI 模式**
- `display` 系列命令在 MMI 模式下执行

### 参数格式
- 端口格式: `frameid/slotid/portid` 如 `0/1/1`
- ONT ID: 数字，如 `0`, `1`, `all`
- 槽位: `frameid/slotid` 如 `0/1`

## 完整命令参考

所有支持的 `display` 命令详见转换后的 Markdown 文档：`~/.openclaw/ma5800_md/cmd/` 目录下 7000+ 条命令文档。

常用查询命令速查：

```bash
# 单板与硬件
display board
display board 0/1
display version
display version 0/1
display temperature
display health

# PON 端口与 ONT
display ont info 0 1 1 all
display ont info 0 1 1 0
display ont optical-info 0/1/1 all
display ont state 0/1/1 all
display port state 0/1/1
display port traffic 0/1/1

# 二层/三层
display mac-address
display mac-address vlan 100
display arp
display arp all

# 接口与链路
display interface
display interface 0/1/1
display interface brief

# 配置与状态
display current-configuration
display saved-configuration
display service-port all
display service-port 100
display vlan all
display vlan 100

# 告警与日志
display alarm active
display alarm history
display log operation
display log security

# 系统资源
display cpu-usage
display memory
display buffer occupancy
```

## 返回结果处理

脚本输出为纯文本，可直接呈现给用户。典型输出结构：

```
[OLT连接] root@70.32.37.65
[前置步骤] enable → config → mmi-mode enable → [命令] → return → quit
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

## 故障排查

| 问题 | 解决 |
|------|------|
| `sshpass: command not found` | `sudo apt-get install sshpass` |
| SSH 连接超时 | 检查 OLT_IP (70.32.37.65) 和端口 22 |
| 认证失败 | 检查用户名 root 和密码 Admin@huawei123 |
| 命令执行失败 | 用 `search` 模式查看正确命令格式 |
| 分页中断 | 脚本已处理，如仍中断可增加 OLT_WIDTH |
| 命令不完整 | 参数缺失，查看文档确认必需参数 |
