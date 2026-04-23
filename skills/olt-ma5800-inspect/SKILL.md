---
name: olt-ma5800-inspect
description: |
  华为 MA5800 OLT 设备自动巡检技能。执行设备状态检查、告警验证、参数校验等，
  输出巡检报告（通过/失败）。支持检查告警参数、单板状态、温度等。
  
  使用场景：
  - 每日/每周自动巡检
  - 故障排查前的状态确认
  - 设备健康度检查
  
  检查项：
  1. 告警参数检查 - 检查指定告警ID的参数是否符合预期
  2. 单板状态检查 - 检查是否有异常状态的单板
  3. 温度检查 - 检查设备温度是否正常
  
  触发词：巡检、检查、校验、inspect、check、validate、健康检查
author: pkuCactus
version: 1.0.0
tags:
  - huawei
  - ma5800
  - olt
  - inspect
  - check
  - validation
  - 巡检
  - 检查
  - 校验
---

# MA5800 OLT 设备巡检技能

## 功能

自动巡检华为 MA5800 OLT 设备，检查关键参数并生成巡检报告。

## 支持的检查项

| 检查项 | 命令 | 说明 |
|--------|------|------|
| 告警参数检查 | `display alarm history` | 检查指定告警ID的参数值 |
| 单板状态检查 | `display board 0` | 检查单板是否有 Failed/Abnormal |
| 温度检查 | `display temperature 0` | 检查设备温度是否正常 |

## 用法

### 直接执行

```bash
# 设置连接参数
export OLT_IP=70.32.37.65
export OLT_USER=root
export OLT_PASS=Admin@huawei123

# 执行所有检查项
./scripts/olt_inspect.sh

# 只检查告警参数
./scripts/olt_inspect.sh alarm-param

# 检查单板状态
./scripts/olt_inspect.sh board

# 检查温度
./scripts/olt_inspect.sh temperature
```

### 检查告警参数

```bash
# 默认检查告警ID 0x02310018
./scripts/olt_inspect.sh alarm-param

# 检查指定告警ID
./scripts/olt_inspect.sh alarm-param 0x02310019
```

**告警参数检查逻辑：**
- 查询历史告警，找到指定告警ID的记录
- 提取 PARAMETERS 行的 Parameter1 和 Parameter2
- 如果 Parameter1=67 且 Parameter2=35，则检查**不通过**
- 否则检查**通过**

## 输出示例

```
╔══════════════════════════════════════╗
║     MA5800 OLT 设备巡检报告          ║
╚══════════════════════════════════════╝
设备IP: 70.32.37.65
检查时间: 2026-04-23 20:00:00

========================================
  检查项1: 告警参数检查 (ID: 0x02310018)
========================================
[i] 查询历史告警 ID=0x02310018...
[i] Parameter1=12, Parameter2=8
[✓] Parameter1=12, Parameter2=8，不符合告警条件 (67,35)，检查通过

========================================
  检查项2: 主控板状态检查
========================================
[i] 查询单板状态...
[✓] 所有单板状态正常

========================================
  检查项3: 温度检查
========================================
[i] 查询设备温度...
[✓] 温度正常

========================================
           巡检结果汇总
========================================
通过: 3 项
失败: 0 项
警告: 0 项

结论: ✅ 巡检全部通过
```

## 添加新的检查项

在 `olt_inspect.sh` 中添加新的检查函数：

```bash
# 检查项X: XXX检查
check_xxx() {
    print_header "检查项X: XXX检查"
    
    local output
    output="$(exec_cmd "display xxx")"
    
    # 解析输出并判断
    if [ "条件满足" ]; then
        print_pass "描述"
        return 0
    else
        print_fail "描述"
        return 1
    fi
}
```

然后在 `main()` 函数中调用：

```bash
all|*)
    check_alarm_param
    check_board_status
    check_temperature
    check_xxx  # 新增
    ;;
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `OLT_IP` | 70.32.37.65 | OLT 管理IP |
| `OLT_USER` | root | SSH 用户名 |
| `OLT_PASS` | Admin@huawei123 | SSH 密码 |
| `OLT_PORT` | 22 | SSH 端口 |
| `OLT_ENABLE` | true | 是否执行 enable |
| `OLT_CONFIG` | true | 是否执行 config |
| `OLT_MMIMODE` | true | 是否执行 mmi-mode enable |

## 依赖

- sshpass
- ssh

## 兼容性

- BusyBox 1.34.1 ash
- POSIX sh

## 文件结构

```
olt-ma5800-inspect/
├── SKILL.md              # 技能定义
└── scripts/
    ├── olt_connect.sh    # SSH 连接脚本（复用）
    └── olt_inspect.sh    # 巡检主脚本
```

## 与查询技能的关系

- **olt-ma5800-query**: 查询设备信息，输出原始数据
- **olt-ma5800-inspect**: 基于查询结果做判断，输出检查结论

两个技能可以配合使用：
1. 先用 `olt-ma5800-query` 查看原始数据
2. 再用 `olt-ma5800-inspect` 自动检查是否符合预期
