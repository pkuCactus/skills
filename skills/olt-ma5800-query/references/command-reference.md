# MA5800 OLT 完整命令速查

本文档作为 `olt-ma5800-query` skill 的参考手册，按需加载。当用户查询**不在标准映射表**中时，查阅此文档。

## 快速导航

- [按对象分类的查询命令](#按对象分类)
- [命令参数速查](#参数速查)
- [文档搜索方法](#文档搜索)

---

## 按对象分类

### 单板与硬件
```
display board
display board 0/1
display version
display version 0/1
display temperature 0
display health
```

### PON 端口与 ONT
```
display ont info 0 1 1 all
display ont info 0 1 1 0
display ont optical-info 0/1/1 all
display ont state 0/1/1 all
display port state 0/1/1
display port traffic 0/1/1
```

### 二层/三层
```
display mac-address
display mac-address vlan 100
display arp
display arp all
```

### 接口与链路
```
display interface
display interface 0/1/1
display interface brief
```

### 配置与状态
```
display current-configuration
display saved-configuration
display service-port all
display service-port 100
display vlan all
display vlan 100
```

### 告警与日志
```
display alarm active
display alarm history
display log operation
display log security
```

### 系统资源
```
display cpu-usage
display memory
display buffer occupancy
```

---

## 参数速查

| 参数对象 | 格式 | 默认值 | 说明 |
|---------|------|--------|------|
| 机框 | `frameid` | `0` | 0号机框 |
| 槽位 | `frameid/slotid` | `0/1` | 0框1槽 |
| PON端口 | `frameid/slotid/portid` | `0/1/1` | 0框1槽1口 |
| ONT ID | `ontid` 或 `all` | `all` | 查询所有ONT |
| VLAN | `vlanid` 或 `all` | `all` | 查询所有VLAN |
| 业务端口 | `spid` 或 `all` | `all` | 查询所有业务端口 |

---

## 文档搜索

7000+ 条命令 Markdown 文档位于 `${OPENCLAW_ROOT}/ma5800_md/cmd/` 目录下。

当用户查询无法匹配时，使用以下命令搜索：

```bash
# 按文件名搜索
ls ${OPENCLAW_ROOT}/ma5800_md/cmd/ | grep -i "关键词"

# 按内容搜索
grep -l "关键词" ${OPENCLAW_ROOT}/ma5800_md/cmd/*.md

# 提取命令格式
grep -A3 "命令格式" ${OPENCLAW_ROOT}/ma5800_md/cmd/display_xxx.md

# 提取参数说明
grep -A10 "参数说明" ${OPENCLAW_ROOT}/ma5800_md/cmd/display_xxx.md
```

### 参数推断规则
- **必选参数**（无方括号）— 必须提供，否则命令报错
- **可选参数**（有方括号）— 可以省略
- `{ frameid \| slotid }` — 二选一，通常默认选 `0` 或 `0/1`
- `[ all \| ontid ]` — 可选，默认选 `all`
