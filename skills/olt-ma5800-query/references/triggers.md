# OLT MA5800 查询触发词列表

本文档列出 `olt-ma5800-query` skill 的所有触发关键词和短语。当用户输入包含以下内容时，应触发此 skill。

## 中文触发词

### 通用查询
- 查询 OLT、查询 MA5800、查看设备
- 查一下、看看、看看状态

### 单板与硬件
- 看看单板、板卡、slot、槽位
- 版本信息、软件版本、firmware
- 设备温度、thermal、高温
- 风扇状态、EMU、散热、风机、转速
- 电源功率、功耗、供电、PSU、电池

### ONT / 光猫
- ONT 光功率、光模块、光衰、收光、发光
- ONT 状态、光猫状态、终端状态
- 光猫、ONU、用户端、家庭网关

### 端口与接口
- 端口状态、PON口状态、链路状态
- 接口状态、接口信息

### 网络表项
- mac地址表、MAC表、二层地址
- arp表、三层地址、IP地址表

### 配置与业务
- 当前配置、running-config
- 业务端口、service-port
- VLAN查询、虚拟局域网
- DHCP租约、IP分配、地址分配

### 告警与日志
- 查告警、警告、故障、fault
- 查日志、操作记录、安全日志

### 流量与性能
- 流量统计、字节统计、包统计
- 设备健康、综合状态、整体状态

## 英文触发词

- query OLT, query MA5800, check device
- board status, slot status, card status
- ONT optical power, ONT status, ONU status
- port state, interface status
- alarm, fault, warning
- traffic statistics, traffic counter
- device health, system health
- MAC address table, ARP table
- current configuration, running config
- VLAN, service port, DHCP lease
- temperature, fan, PSU, power

## 混合表达示例

用户可能这样表达查询意图：
- "帮我查一下 OLT 的告警"
- "看看 0/1/1 端口的光功率"
- "查所有光猫的状态"
- "看一下设备温度高不高"
- "MAC 地址表给我看看"
- "当前配置导出来"
