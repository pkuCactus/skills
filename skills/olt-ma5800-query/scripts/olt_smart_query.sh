#!/bin/sh
# MA5800 OLT 智能查询匹配脚本
# 兼容 BusyBox 1.34.1 ash
# 用法: ./olt_smart_query.sh "<用户查询描述>"

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUERY_SCRIPT="${SCRIPT_DIR}/olt_query.sh"
CONNECT_SCRIPT="${SCRIPT_DIR}/olt_connect.sh"

USER_INPUT="${1:-}"
if [ -z "${USER_INPUT}" ]; then
    echo "用法: $0 \"<查询描述>\"" >&2
    exit 1
fi

# 转换为小写用于匹配
INPUT_LOWER="$(echo "${USER_INPUT}" | tr '[:upper:]' '[:lower:]')"

# 辅助函数：检查是否包含关键词
contains() {
    echo "$2" | grep -qE "$1"
}

# 提取数字参数
extract_nums() {
    echo "$1" | grep -oE '[0-9]+' | tr '\n' ' ' | sed 's/ *$//'
}

# 提取 MAC 地址
extract_mac() {
    echo "$1" | grep -oiE '([0-9a-f]{4}-){2}[0-9a-f]{4}|([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1
}

# 提取 IP 地址
extract_ip() {
    echo "$1" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1
}

# 提取 LOID
extract_loid() {
    echo "$1" | grep -oE 'loid[ :]*[A-Za-z0-9_]+' | sed 's/loid[ :]*/\1/' | sed 's/^\([ :]*\)//' | head -1
}

# 提取 ONT SN
extract_sn() {
    echo "$1" | grep -oiE 'sn[ :]*[A-Za-z0-9]+' | sed 's/sn[ :]*/\1/' | sed 's/^\([ :]*\)//' | head -1
}

# 提取端口格式: 0/1/1
extract_port() {
    echo "$1" | grep -oE '[0-9]+/[0-9]+/[0-9]+' | head -1
}

# 提取槽位: 0/1
extract_slot() {
    echo "$1" | grep -oE '[0-9]+/[0-9]+' | head -1
}

# 提取单个数字
extract_first_num() {
    echo "$1" | grep -oE '[0-9]+' | head -1
}

# 解析端口参数
parse_port_args() {
    local input_text="$1"
    local nums_str=""
    nums_str="$(extract_nums "${input_text}")"
    local port=""
    port="$(extract_port "${input_text}")"
    
    if [ -n "${port}" ]; then
        echo "${port}"
    else
        # 取第一个数字
        local first_num=""
        first_num="$(echo "${nums_str}" | awk '{print $1}')"
        if [ -n "${first_num}" ]; then
            echo "${first_num}"
        fi
    fi
}

# 智能匹配查询类型
determine_query() {
    local input="$1"
    local nums_str=""
    nums_str="$(extract_nums "${input}")"
    local first_num=""
    first_num="$(echo "${nums_str}" | awk '{print $1}')"
    
    # 单板/板卡相关
    if contains "(board|单板|板卡|slot|槽位|paf|subboard|子卡)" "${input}"; then
        local slot=""
        slot="$(extract_slot "${input}")"
        if [ -n "${slot}" ]; then
            echo "board:${slot}"
        elif [ -n "${first_num}" ]; then
            echo "board:${first_num}"
        else
            echo "board"
        fi
        return
    fi
    
    # 风扇/EMU 模块
    if contains "(fan|风扇|emu|散热|cooling|风机|转速|rpm)" "${input}"; then
        echo "raw:display emu"
        return
    fi
    
    # 电源/功率/功耗
    if contains "(power|电源|功率|功耗|供电|psu|电池|battery)" "${input}"; then
        local slot=""
        slot="$(extract_slot "${input}")"
        if [ -n "${slot}" ]; then
            echo "raw:display power ${slot}"
        elif contains "(detail|详情|详细|明细)" "${input}"; then
            echo "raw:display power detail 0"
        else
            echo "raw:display power 0"
        fi
        return
    fi
    
    # 版本/软件版本
    if contains "(version|版本|软件|firmware|patch|版本号)" "${input}"; then
        local slot=""
        slot="$(extract_slot "${input}")"
        if [ -n "${slot}" ]; then
            echo "version:${slot}"
        else
            echo "version"
        fi
        return
    fi
    
    # ONT 光功率/光模块
    if contains "(optical|光功率|光模块|光衰|rx|tx|收光|发光|光信号|光强)" "${input}"; then
        local port=""
        port="$(parse_port_args "${input}")"
        local ont_id=""
        ont_id="$(extract_first_num "${input}")"
        if [ -n "${port}" ]; then
            if [ -n "${ont_id}" ] && ! echo "${port}" | grep -q "${ont_id}"; then
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
    if contains "(ont|onu|终端|光猫|用户端|家庭网关|hg|hgw)" "${input}"; then
        local port=""
        port="$(parse_port_args "${input}")"
        local ont_id=""
        ont_id="$(extract_first_num "${input}")"
        
        # 如果有MAC地址，用MAC查询
        local mac=""
        mac="$(extract_mac "${input}")"
        if [ -n "${mac}" ]; then
            echo "raw:display ont info by-mac ${mac}"
            return
        fi
        
        # 如果有IP地址
        local ip=""
        ip="$(extract_ip "${input}")"
        if [ -n "${ip}" ]; then
            echo "raw:display ont info by-ip ${ip}"
            return
        fi
        
        # 如果有LOID
        local loid=""
        loid="$(extract_loid "${input}")"
        if [ -n "${loid}" ]; then
            echo "raw:display ont info by-loid ${loid}"
            return
        fi
        
        # 如果有SN
        local sn=""
        sn="$(extract_sn "${input}")"
        if [ -n "${sn}" ]; then
            echo "raw:display ont info by-sn ${sn}"
            return
        fi
        
        # 默认按端口查询
        if [ -n "${port}" ]; then
            if [ -n "${ont_id}" ] && ! echo "${port}" | grep -q "${ont_id}"; then
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
    if contains "(alarm|告警|警告|alert|fault|故障)" "${input}"; then
        if contains "(history|历史|以往|曾经)" "${input}"; then
            echo "alarm:history"
        else
            echo "alarm:active"
        fi
        return
    fi
    
    # 接口/端口状态
    if contains "(interface|接口|port|端口|if|状态|up|down|链路)" "${input}"; then
        if contains "(pon|光口|pon口|olt口|光纤口)" "${input}"; then
            local port=""
            port="$(parse_port_args "${input}")"
            if [ -n "${port}" ]; then
                echo "raw:display interface ${port}"
            else
                echo "interface"
            fi
        elif [ -n "${first_num}" ]; then
            echo "raw:display interface ${first_num}"
        else
            echo "interface"
        fi
        return
    fi
    
    # MAC 地址表
    if contains "(mac-address|mac|mac地址|mac表|二层地址|桥接表|l2)" "${input}"; then
        local mac=""
        mac="$(extract_mac "${input}")"
        if [ -n "${mac}" ]; then
            echo "raw:display mac-address ${mac}"
        else
            echo "mac-address"
        fi
        return
    fi
    
    # ARP 表
    if contains "(arp|arp表|三层地址|ip地址表)" "${input}"; then
        local ip=""
        ip="$(extract_ip "${input}")"
        if [ -n "${ip}" ]; then
            echo "raw:display arp ${ip}"
        else
            echo "arp"
        fi
        return
    fi
    
    # CPU/内存
    if contains "(cpu|处理器|负载|load)" "${input}"; then
        echo "cpu"
        return
    fi
    
    if contains "(memory|mem|内存|ram|存储)" "${input}"; then
        echo "memory"
        return
    fi
    
    # 温度
    if contains "(temperature|temp|温度|thermal|高温|发热)" "${input}"; then
        echo "temperature"
        return
    fi
    
    # 配置
    if contains "(config|配置|current-config|当前配置|running-config|运行配置)" "${input}"; then
        echo "config"
        return
    fi
    
    # 业务端口
    if contains "(service-port|sp|业务端口|业务流|gemport|tcont|traffic|flow)" "${input}"; then
        local sp_id=""
        sp_id="$(extract_first_num "${input}")"
        if [ -n "${sp_id}" ]; then
            echo "service-port:${sp_id}"
        else
            echo "service-port"
        fi
        return
    fi
    
    # VLAN
    if contains "(vlan|虚拟局域网|广播域|tag|untag)" "${input}"; then
        local vlan_id=""
        vlan_id="$(extract_first_num "${input}")"
        if [ -n "${vlan_id}" ]; then
            echo "raw:display vlan ${vlan_id}"
        else
            echo "vlan"
        fi
        return
    fi
    
    # 流量统计
    if contains "(traffic|流量|统计|字节|包|packet|byte|counter|性能|perf)" "${input}"; then
        local port=""
        port="$(parse_port_args "${input}")"
        if [ -n "${port}" ]; then
            echo "traffic:${port}"
        else
            echo "traffic"
        fi
        return
    fi
    
    # 日志
    if contains "(log|日志|记录|audit|操作记录|security|安全日志)" "${input}"; then
        if contains "(security|安全|登录|认证|鉴权)" "${input}"; then
            echo "log:security"
        else
            echo "log:operation"
        fi
        return
    fi
    
    # 健康/综合状态
    if contains "(health|健康|状态|summary|overview|概览|综合|总览|整体)" "${input}"; then
        echo "health"
        return
    fi
    
    # DHCP
    if contains "(dhcp|ip分配|地址分配|租约|lease)" "${input}"; then
        echo "raw:display dhcp server lease"
        return
    fi
    
    # 默认: 尝试直接作为 display 命令
    echo "raw:display ${input}"
}

# 执行查询
RESULT="$(determine_query "${INPUT_LOWER}")"
QUERY_TYPE="${RESULT%%:*}"
QUERY_ARGS="${RESULT#*:}"

if [ "${QUERY_TYPE}" = "raw" ]; then
    # 原始命令模式
    CMD="${QUERY_ARGS}"
    echo "[智能匹配] 执行原始命令: ${CMD}"
    "${CONNECT_SCRIPT}" "${OLT_IP}" "${OLT_USER}" "${OLT_PASS}" "${CMD}"
else
    # 查询脚本模式
    echo "[智能匹配] 查询类型: ${QUERY_TYPE}, 参数: ${QUERY_ARGS}"
    "${QUERY_SCRIPT}" "${QUERY_TYPE}" ${QUERY_ARGS}
fi
