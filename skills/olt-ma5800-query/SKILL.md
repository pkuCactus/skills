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
| OLT_IP | `70.32.37.65` |
| OLT_USER | `root` |
| OLT_PASS | `Admin@huawei123` |
| OLT_TIMEOUT | `30` 秒 |
| OLT_WIDTH | `200` |

无需手动设置环境变量即可使用默认值。如需修改，执行：

```bash
export OLT_IP=70.32.37.65
export OLT_USER=root
export OLT_PASS=Admin@huawei123
export OLT_TIMEOUT=30
export OLT_WIDTH=200
```

## 核心脚本

所有脚本位于 `scripts/` 目录下：

| 脚本 | 用途 |
|------|------|
| `olt_connect.sh` | 底层 SSH 连接，**自动执行特权模式切换**，执行 CLI 命令 |
| `olt_query.sh`   | 查询入口，按类型分发命令 |
| `olt_smart_query.sh` | 智能查询，自然语言→display 命令 |

## 特权模式切换流程

脚本自动处理以下 CLI 模式切换，无需用户干预：

```
SSH 登录 → enable → config → mmi-mode enable → [执行 display 命令]
```

- **enable** — 从用户视图进入特权视图
- **config** — 进入全局配置视图
- **mmi-mode enable** — 启用 MMI 模式（MA5800 特定模式）

此后即可执行 `display` 系列查询命令。

## 使用方法

### 方式一：直接执行查询（推荐）

```bash
# 使用默认连接参数（无需 export）
./scripts/olt_smart_query.sh "查询所有单板状态"
./scripts/olt_smart_query.sh "看看 0/1/1 端口 ONT 光功率"
./scripts/olt_smart_query.sh "查一下告警"
./scripts/olt_smart_query.sh "设备温度"
./scripts/olt_smart_query.sh "版本信息"
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

### 方式三：直接执行原始命令

```bash
# 任何 display 命令（脚本自动处理特权模式）
./scripts/olt_connect.sh "display board 0"
./scripts/olt_connect.sh "display ont info 0 1 1 all"
./scripts/olt_connect.sh "display ont optical-info 0/1/1 all"
```

**脚本会自动添加 enable → config → mmi-mode enable 前置步骤。**

如果需要跳过某个前置步骤，可设置环境变量：

```bash
OLT_ENABLE=false OLT_CONFIG=false ./scripts/olt_connect.sh "display board 0"
```

## 智能查询映射表

`olt_smart_query.sh` 支持的自然语言→命令映射：

| 用户输入关键词 | 映射命令 |
|-------------|---------|
| 单板、板卡、slot | `display board` |
| 版本、软件 | `display version` |
| ONT、光猫、ONU | `display ont info` / `display ont optical-info` |
| 光功率、光模块、rx、tx | `display ont optical-info` |
| 告警、警告、故障 | `display alarm active` / `display alarm history` |
| 接口、端口、状态 | `display interface` / `display port state` |
| MAC、二层地址 | `display mac-address` |
| ARP、三层地址 | `display arp` |
| CPU、负载 | `display health` |
| 内存、ram | `display memory` |
| 温度、thermal | `display temperature` |
| 配置、当前配置 | `display current-configuration` |
| 业务端口、service-port | `display service-port` |
| VLAN | `display vlan` |
| 流量、统计 | `display port traffic` |
| 日志 | `display log` |
| 健康、综合状态 | `display health` |
| 风扇、EMU、散热、风机 | `display emu` |
| 电源、功率、功耗、供电、电池 | `display power 0` / `display power detail 0` |
| DHCP | `display dhcp server lease` |

## OLT CLI 特性处理

### 分页提示
MA5800 display 命令输出超过一屏时会暂停，提示 `--- More ---`。脚本通过以下方式处理：
1. 设置终端宽度为 200 字符（减少分页）
2. SSH 伪终端自动处理
3. 对 More 提示行做 sed 过滤

### 命令模式
- SSH 登录后默认处于 **用户视图**
- 脚本自动执行 `enable` → `config` → `mmi-mode enable` 进入 **MMI 模式**
- `display` 系列命令在 MMI 模式下执行
- 返回数据是只读的，不会影响设备运行

### 参数格式
- 端口格式: `frameid/slotid/portid` 如 `0/1/1`
- ONT ID: 数字，如 `0`, `1`, `all`
- 槽位: `frameid/slotid` 如 `0/1`

## 完整命令参考

所有支持的 `display` 命令详见转换后的 Markdown 文档：`/tmp/ma5800_md/cmd/` 目录下 7000+ 条命令文档。

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
| SSH 连接超时 | 检查 OLT_IP (70.32.37.65) 和端口 22，检查网络连通性 |
| 认证失败 | 检查用户名 root 和密码 Admin@huawei123 |
| enable/config/mmi-mode 命令失败 | 部分设备命令差异，可在 `olt_connect.sh` 中调整前置命令 |
| 命令执行无输出 | 检查命令语法是否正确，部分命令需要特定视图 |
| 分页中断 | 脚本已处理，如仍中断可增加 OLT_WIDTH |
