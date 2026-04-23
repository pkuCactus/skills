#!/bin/bash
# MA5800 OLT 智能查询匹配脚本
# 根据用户输入的自然语言，匹配最合适的 display 命令
#
# 用法: ./olt_smart_query.sh "<用户查询描述>"
# 示例:
#   ./olt_smart_query.sh "查询0槽位单板"
#   ./olt_smart_query.sh "查看ONT光功率"
#   ./olt_smart_query.sh "看看设备温度"
#   ./olt_smart_query.sh "所有端口的状态"
#
# 环境变量:
#   OLT_IP, OLT_USER, OLT_PASS

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUERY_SCRIPT="${SCRIPT_DIR}/olt_query.sh"
CONNECT_SCRIPT="${SCRIPT_DIR}/olt_connect.sh"

USER_INPUT="${1:-}"
if [[ -z "${USER_INPUT}" ]]; then
    echo "用法: $0 \"<查询描述>\"" >&2
    exit 1
fi

# 转换为小写用于匹配
INPUT_LOWER="$(echo "${USER_INPUT}" | tr '[:upper:]' '[:lower:]')"

# 提取数字参数（如果有的话）
extract_nums() {
    echo "$1" | grep -oP '\d+' | tr '\n' ' ' | sed 's/ *$//'
}

# 提取 MAC 地址
extract_mac() {
    echo "$1" | grep -oiP '([0-9a-f]{4}-){2}[0-9a-f]{4}|([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1
}

# 提取 IP 地址
extract_ip() {
    echo "$1" | grep -oP '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' | head -1
}

# 提取 LOID
extract_loid() {
    echo "$1" | grep -oP 'loid[ :]*\S+' | sed 's/loid[ :]*/\1/' | head -1
}

# 提取 ONT SN
extract_sn() {
    echo "$1" | grep -oiP 'sn[ :]*\S+' | sed 's/sn[ :]*/\1/' | head -1
}

# 提取端口格式: 0/1/1 -> frame/slot/port
extract_port() {
    echo "$1" | grep -oP '\d+/\d+/\d+' | head -1
}

# 提取槽位: 0/1 -> frame/slot
extract_slot() {
    echo "$1" | grep -oP '\d+/\d+' | head -1
}

# 提取单个数字
extract_first_num() {
    echo "$1" | grep -oP '\d+' | head -1
}

# 解析端口参数
parse_port_args() {
    local nums=($(extract_nums "$1"))
    local port=$(extract_port "$1")
    
    if [[ -n "${port}" ]]; then
        echo "${port}"
    elif [[ ${#nums[@]} -ge 3 ]]; then
        echo "${nums[0]}/${nums[1]}/${nums[2]}"
    elif [[ ${#nums[@]} -ge 1 ]]; then
        echo "${nums[0]}"
    fi
}

# 智能匹配查询类型
determine_query() {
    local input="$1"
    local nums=($(extract_nums "${input}"))
    
    # 单板/板卡相关
    if [[ "${input}" =~ (board|单板|板卡|slot|槽位|paf|subboard|子卡) ]]; then
        local slot=$(extract_slot "${input}")
        if [[ -n "${slot}" ]]; then
            echo "board:${slot}"
        elif [[ ${#nums[@]} -ge 1 ]]; then
            echo "board:${nums[0]}"
        else
            echo "board"
        fi
        return
    fi
    
    # 风扇/EMU 模块
    if [[ "${input}" =~ (fan|风扇|emu|散热|cooling|风机|转速|rpm) ]]; then
        echo "raw:display emu"
        return
    fi
    
    # 版本/软件版本
    if [[ "${input}" =~ (version|版本|软件|firmware|patch|版本号) ]]; then
        local slot=$(extract_slot "${input}")
        if [[ -n "${slot}" ]]; then
            echo "version:${slot}"
        else
            echo "version"
        fi
        return
    fi
    
    # ONT 光功率/光模块
    if [[ "${input}" =~ (optical|光功率|光模块|光衰|rx|tx|收光|发光|光信号|光强) ]]; then
        local port=$(parse_port_args "${input}")
        local ont_id=$(extract_first_num "${input}")
        if [[ -n "${port}" ]]; then
            if [[ -n "${ont_id}" && ! "${port}" =~ "${ont_id}" ]]; then
                echo "ont-optical:${port} ${ont_id}"
            else
                echo "ont-optical:${port} all"
            fi
        else
            echo "ont-optical"
        fi
        return
    fi
    
    # ONT 信息/状态
    if [[ "${input}" =~ (ont|onu|终端|光猫|用户端|家庭网关|hg|hgw) ]]; then
        local port=$(parse_port_args "${input}")
        local ont_id=$(extract_first_num "${input}")
        
        # 如果有MAC地址，用MAC查询
        local mac=$(extract_mac "${input}")
        if [[ -n "${mac}" ]]; then
            echo "raw:display ont info by-mac ${mac}"
            return
        fi
        
        # 如果有IP地址
        local ip=$(extract_ip "${input}")
        if [[ -n "${ip}" ]]; then
            echo "raw:display ont info by-ip ${ip}"
            return
        fi
        
        # 如果有LOID
        local loid=$(extract_loid "${input}")
        if [[ -n "${loid}" ]]; then
            echo "raw:display ont info by-loid ${loid}"
            return
        fi
        
        # 如果有SN
        local sn=$(extract_sn "${input}")
        if [[ -n "${sn}" ]]; then
            echo "raw:display ont info by-sn ${sn}"
            return
        fi
        
        # 默认按端口查询
        if [[ -n "${port}" ]]; then
            if [[ -n "${ont_id}" && ! "${port}" =~ "${ont_id}" ]]; then
                echo "ont:${port} ${ont_id}"
            else
                echo "ont:${port} all"
            fi
        else
            echo "ont"
        fi
        return
    fi
    
    # 告警
    if [[ "${input}" =~ (alarm|告警|警告|alert|fault|故障) ]]; then
        if [[ "${input}" =~ (history|历史|以往|曾经) ]]; then
            echo "alarm:history"
        else
            echo "alarm:active"
        fi
        return
    fi
    
    # 接口/端口状态
    if [[ "${input}" =~ (interface|接口|port|端口|if|状态|up|down|链路) ]]; then
        if [[ "${input}" =~ (pon|光口|pon口|olt口|光纤口) ]]; then
            local port=$(parse_port_args "${input}")
            if [[ -n "${port}" ]]; then
                echo "raw:display interface ${port}"
            else
                echo "interface"
            fi
        elif [[ ${#nums[@]} -ge 1 ]]; then
            echo "raw:display interface ${nums[0]}"
        else
            echo "interface"
        fi
        return
    fi
    
    # MAC 地址表
    if [[ "${input}" =~ (mac-address|mac|mac地址|mac表|二层地址|桥接表|l2) ]]; then
        local mac=$(extract_mac "${input}")
        if [[ -n "${mac}" ]]; then
            echo "raw:display mac-address ${mac}"
        else
            echo "mac-address"
        fi
        return
    fi
    
    # ARP 表
    if [[ "${input}" =~ (arp|arp表|三层地址|ip地址表) ]]; then
        local ip=$(extract_ip "${input}")
        if [[ -n "${ip}" ]]; then
            echo "raw:display arp ${ip}"
        else
            echo "arp"
        fi
        return
    fi
    
    # CPU/内存
    if [[ "${input}" =~ (cpu|处理器|负载|load) ]]; then
        echo "cpu"
        return
    fi
    
    if [[ "${input}" =~ (memory|mem|内存|ram|存储) ]]; then
        echo "memory"
        return
    fi
    
    # 温度
    if [[ "${input}" =~ (temperature|temp|温度|thermal|高温|发热) ]]; then
        echo "temperature"
        return
    fi
    
    # 配置
    if [[ "${input}" =~ (config|配置|current-config|当前配置|running-config|运行配置) ]]; then
        echo "config"
        return
    fi
    
    # 业务端口
    if [[ "${input}" =~ (service-port|sp|业务端口|业务流|gemport|tcont|traffic|flow) ]]; then
        local sp_id=$(extract_first_num "${input}")
        if [[ -n "${sp_id}" ]]; then
            echo "service-port:${sp_id}"
        else
            echo "service-port"
        fi
        return
    fi
    
    # VLAN
    if [[ "${input}" =~ (vlan|虚拟局域网|广播域|tag|untag) ]]; then
        local vlan_id=$(extract_first_num "${input}")
        if [[ -n "${vlan_id}" ]]; then
            echo "raw:display vlan ${vlan_id}"
        else
            echo "vlan"
        fi
        return
    fi
    
    # 流量统计
    if [[ "${input}" =~ (traffic|流量|统计|字节|包|packet|byte|counter|性能|perf) ]]; then
        local port=$(parse_port_args "${input}")
        if [[ -n "${port}" ]]; then
            echo "traffic:${port}"
        else
            echo "traffic"
        fi
        return
    fi
    
    # 日志
    if [[ "${input}" =~ (log|日志|记录|audit|操作记录|security|安全日志) ]]; then
        if [[ "${input}" =~ (security|安全|登录|认证|鉴权) ]]; then
            echo "log:security"
        else
            echo "log:operation"
        fi
        return
    fi
    
    # 健康/综合状态
    if [[ "${input}" =~ (health|健康|状态|summary|overview|概览|综合|总览|整体) ]]; then
        echo "health"
        return
    fi
    
    # DHCP
    if [[ "${input}" =~ (dhcp|ip分配|地址分配|租约|lease) ]]; then
        echo "raw:display dhcp server lease"
        return
    fi
    
    # 默认: 尝试直接作为 display 命令
    echo "raw:display ${input}"
}

# 执行查询
RESULT=$(determine_query "${INPUT_LOWER}")
QUERY_TYPE="${RESULT%%:*}"
QUERY_ARGS="${RESULT#*:}"

if [[ "${QUERY_TYPE}" == "raw" ]]; then
    # 原始命令模式
    CMD="${QUERY_ARGS}"
    echo "[智能匹配] 执行原始命令: ${CMD}"
    "${CONNECT_SCRIPT}" "${OLT_IP}" "${OLT_USER}" "${OLT_PASS}" "${CMD}"
else
    # 查询脚本模式
    echo "[智能匹配] 查询类型: ${QUERY_TYPE}, 参数: ${QUERY_ARGS}"
    "${QUERY_SCRIPT}" "${QUERY_TYPE}" ${QUERY_ARGS}
fi
