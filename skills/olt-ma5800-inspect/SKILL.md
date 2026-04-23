---
name: olt-ma5800-inspect
description: |
  华为 MA5800 OLT 设备自动巡检技能。支持自然语言描述，自动理解用户意图并执行对应的检查项。
  
  用户可以用自然语言描述要检查的内容，如"检查主控板电子开关"、"看看单板状态"、
  "查查温度是否正常"，技能会自动映射到对应的检查命令。
  
  检查项包括：告警参数校验、单板状态、温度、活动告警、ONT光功率、电源、风扇、版本等。
  
  触发词：巡检、检查、校验、inspect、check、validate、健康检查、看看、查查
author: pkuCactus
version: 1.1.0
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

自动巡检华为 MA5800 OLT 设备，支持**自然语言描述**，自动理解意图并执行检查。

## 自然语言意图映射

| 用户说法 | 自动映射到 | 实际执行 |
|---------|-----------|---------|
| "检查主控板电子开关" | alarm-param | 查告警ID 0x02310018 的 Parameter1/Parameter2 |
| "看看单板状态" | board | display board 0 |
| "查查温度" | temperature | display temperature 0 |
| "看看有没有告警" | alarm | display alarm active |
| "查查光功率" | ont-optical | display ont optical-info |
| "看看电源" | power | display power 0 |
| "风扇正常吗" | fan | display emu |
| "什么版本" | version | display version |
| "全部检查一遍" | all | 所有检查项 |

## 支持的检查项

| 检查项 | 命令 | 判断逻辑 |
|--------|------|---------|
| **告警参数检查** | `display alarm history` | Parameter1=67 且 Parameter2=35 → 不通过 |
| **单板状态检查** | `display board 0` | 有 Failed/Abnormal → 不通过 |
| **温度检查** | `display temperature 0` | 有 High/Critical → 警告 |
| **活动告警检查** | `display alarm active` | 有活动告警 → 警告 |
| **ONT光功率检查** | `display ont optical-info` | 有 low/high/error → 警告 |
| **电源检查** | `display power 0` | 有 fail/error → 警告 |
| **风扇检查** | `display emu` | 有 fail/stop → 警告 |
| **版本检查** | `display version` | 获取版本信息 |

## 用法

### 自然语言描述

```bash
# 检查主控板电子开关（自动映射到告警参数检查）
./scripts/olt_inspect.sh "检查主控板电子开关"

# 看看单板状态
./scripts/olt_inspect.sh "看看单板有没有问题"

# 查查温度
./scripts/olt_inspect.sh "查查温度是否正常"

# 全部检查
./scripts/olt_inspect.sh "全部检查一遍"
```

### 直接指定检查项

```bash
# 设置连接参数
export OLT_IP=70.32.37.65
export OLT_USER=root
export OLT_PASS=Admin@huawei123

# 执行所有检查项
./scripts/olt_inspect.sh

# 只检查告警参数
./scripts/olt_inspect.sh alarm-param

# 检查指定告警ID
./scripts/olt_inspect.sh alarm-param 0x02310019
```

## 输出示例

### 自然语言输入

```bash
$ ./scripts/olt_inspect.sh "检查主控板电子开关"

╔══════════════════════════════════════╗
║     MA5800 OLT 设备巡检报告          ║
╚══════════════════════════════════════╝
设备IP: 70.32.37.65
检查时间: 2026-04-23 20:15:00

[i] 解析用户意图: '检查主控板电子开关'
[i] 匹配到检查项: alarm-param

========================================
  检查项1: 告警参数检查 (ID: 0x02310018)
========================================
[i] 查询历史告警 ID=0x02310018...
[i] Parameter1=12, Parameter2=8
[✓] Parameter1=12, Parameter2=8，不符合告警条件 (67,35)，检查通过

========================================
           巡检结果汇总
========================================
通过: 1 项
失败: 0 项
警告: 0 项

结论: ✅ 巡检全部通过
```

### 全部检查

```bash
$ ./scripts/olt_inspect.sh

========================================
  检查项1: 告警参数检查 (ID: 0x02310018)
========================================
[✓] 未找到告警 ID=0x02310018，检查通过

========================================
  检查项2: 主控板状态检查
========================================
[✓] 所有单板状态正常

========================================
  检查项3: 温度检查
========================================
[✓] 温度正常

========================================
           巡检结果汇总
========================================
通过: 3 项
失败: 0 项
警告: 0 项

结论: ✅ 巡检全部通过
```

## 检查失败示例

```bash
========================================
  检查项1: 告警参数检查 (ID: 0x02310018)
========================================
[i] 查询历史告警 ID=0x02310018...
[i] Parameter1=67, Parameter2=35
[✗] Parameter1=67 且 Parameter2=35，检查不通过

========================================
           巡检结果汇总
========================================
通过: 2 项
失败: 1 项
警告: 0 项

结论: ❌ 巡检不通过，存在 1 项异常
```

## 添加新的检查项

在 `olt_inspect.sh` 中：

1. **添加意图识别关键词**（在 `parse_intent()` 函数中）：

```bash
# 检查项X: XXX检查
if contains "关键词1" "${input}" || \
   contains "关键词2" "${input}"; then
    echo "intent:xxx"
    return
fi
```

2. **添加检查函数**：

```bash
check_xxx() {
    print_header "检查项X: XXX检查"
    
    local output
    output="$(exec_cmd "display xxx")"
    
    if [ "条件满足" ]; then
        print_pass "描述"
        return 0
    else
        print_fail "描述"
        return 1
    fi
}
```

3. **在 `run_check()` 中注册**：

```bash
xxx)
    check_xxx
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
    └── olt_inspect.sh    # 巡检主脚本（支持自然语言）
```

## 与查询技能的关系

- **olt-ma5800-query**: 查询设备信息，输出原始数据
- **olt-ma5800-inspect**: 基于查询结果做判断，支持自然语言，输出检查结论

配合使用：
1. 先用 `olt-ma5800-query` 查看原始数据
2. 再用 `olt-ma5800-inspect` 自动检查是否符合预期
