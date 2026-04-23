#!/bin/sh
# MA5800 OLT 智能查询匹配脚本
# 兼容 BusyBox 1.34.1 ash
# 支持: 智能匹配、文档搜索、随机参数、默认参数
#
# 用法: ./olt_smart_query.sh "<用户查询描述>"
#   随机查询: ./olt_smart_query.sh "random 查询光模块"
#   默认查询: ./olt_smart_query.sh "default 查询ONT"
#   文档搜索: ./olt_smart_query.sh "search 光功率"

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUERY_SCRIPT="${SCRIPT_DIR}/olt_query.sh"
CONNECT_SCRIPT="${SCRIPT_DIR}/olt_connect.sh"
DOC_DIR="${DOC_DIR:-~/.openclaw/ma5800_md/cmd}"

# 默认值
DEFAULT_FRAME="0"
DEFAULT_SLOT="0/1"
DEFAULT_PORT="0/1/1"
DEFAULT_ONTID="all"

USER_INPUT="${1:-}"
if [ -z "${USER_INPUT}" ]; then
    echo "用法: $0 \"<查询描述>\"" >&2
    echo "  随机: $0 \"random <查询>\"" >&2
    echo "  默认: $0 \"default <查询>\"" >&2
    echo "  搜索: $0 \"search <关键词>\"" >&2
    exit 1
fi

# 检查是否是特殊模式
if echo "${USER_INPUT}" | grep -qiE "^random\s+"; then
    mode="random"
    USER_INPUT="$(echo "${USER_INPUT}" | sed 's/^random\s*//i')"
elif echo "${USER_INPUT}" | grep -qiE "^default\s+"; then
    mode="default"
    USER_INPUT="$(echo "${USER_INPUT}" | sed 's/^default\s*//i')"
elif echo "${USER_INPUT}" | grep -qiE "^search\s+"; then
    mode="search"
    USER_INPUT="$(echo "${USER_INPUT}" | sed 's/^search\s*//i')"
else
    mode="normal"
fi

# 转换为小写
INPUT_LOWER="$(echo "${USER_INPUT}" | tr '[:upper:]' '[:lower:]')"

# 辅助函数
contains() {
    echo "$2" | grep -qE "$1"
}

extract_nums() {
    echo "$1" | grep -oE '[0-9]+' | tr '\n' ' ' | sed 's/ *$//'
}

extract_port() {
    echo "$1" | grep -oE '[0-9]+/[0-9]+/[0-9]+' | head -1
}

extract_slot() {
    echo "$1" | grep -oE '[0-9]+/[0-9]+' | head -1
}

extract_first_num() {
    echo "$1" | grep -oE '[0-9]+' | head -1
}

# 解析端口参数
parse_port_args() {
    local input_text="$1"
    local port=""
    port="$(extract_port "${input_text}")"
    
    if [ -n "${port}" ]; then
        echo "${port}"
    else
        local first_num=""
        first_num="$(echo "$(extract_nums "${input_text}")" | awk '{print $1}')"
        if [ -n "${first_num}" ]; then
            echo "${first_num}"
        fi
    fi
}

# 文档搜索函数
search_in_docs() {
    local keyword="$1"
    echo "[搜索文档] 关键词: ${keyword}" >&2
    
    if [ ! -d "${DOC_DIR}" ]; then
        echo "[警告] 文档目录不存在: ${DOC_DIR}" >&2
        return 1
    fi
    
    # 搜索文件名匹配
    local file_matches=""
    file_matches="$(ls "${DOC_DIR}" 2>/dev/null | grep -i "${keyword}" | head -5)"
    
    # 搜索内容匹配
    local content_matches=""
    content_matches="$(grep -l "${keyword}" "${DOC_DIR}"/*.md 2>/dev/null | head -5)"
    
    echo "=== 找到的相关命令 ===" >&2
    local found=0
    
    # 合并结果
    local all_matches="${file_matches}"
    for f in ${content_matches}; do
        local base="$(basename "$f")"
        if ! echo "${all_matches}" | grep -q "${base}"; then
            all_matches="${all_matches} ${base}"
        fi
    done
    
    for f in ${all_matches}; do
        if [ -f "${DOC_DIR}/${f}" ]; then
            local cmd
            cmd="$(echo "$f" | sed 's/^display_//' | sed 's/_/ /g' | sed 's/\.md$//')"
            echo "  - display ${cmd}" >&2
            # 尝试提取命令格式
            grep -A1 "命令格式" "${DOC_DIR}/${f}" 2>/dev/null | head -2 >&2
            found=$((found + 1))
        fi
    done
    
    if [ ${found} -eq 0 ]; then
        echo "  未找到相关命令" >&2
        return 1
    fi
    
    return 0
}

# 智能匹配查询类型
determine_query() {
    local input="$1"
    local nums_str=""
    nums_str="$(extract_nums "${input}")"
    local first_num=""
    first_num="$(echo "${nums_str}" | awk '{print $1}')"
    local port=""
    port="$(parse_port_args "${input}")"
    
    # 单板/板卡
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
    
    # 风扇/EMU
    if contains "(fan|风扇|emu|散热|cooling|风机|转速|rpm)" "${input}"; then
        echo "raw:display emu"
        return
    fi
    
    # 电源/功率
    if contains "(power|电源|功率|功耗|供电|psu|电池|battery)" "${input}"; then
        local slot=""
        slot="$(extract_slot "${input}")"
        if [ -n "${slot}" ]; then
            echo "raw:display power ${slot}"
        elif contains "(detail|详情|详细|明细)" "${input}"; then
            echo "power-detail:${DEFAULT_FRAME}"
        else
            echo "power:${DEFAULT_FRAME}"
        fi
        return
    fi
    
    # 版本
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
    
    # ONT 光功率
    if contains "(optical|光功率|光模块|光衰|rx|tx|收光|发光|光信号|光强)" "${input}"; then
        local ont_id=""
        ont_id="$(extract_first_num "${input}")"
        if [ -n "${port}" ]; then
            if [ -n "${ont_id}" ] && ! echo "${port}" | grep -q "${ont_id}"; then
                echo "ont-optical:${port} ${ont_id}"
            else
                echo "ont-optical:${port} ${DEFAULT_ONTID}"
            fi
        else
            echo "ont-optical:${DEFAULT_PORT} ${DEFAULT_ONTID}"
        fi
        return
    fi
    
    # ONT 信息
    if contains "(ont|onu|终端|光猫|用户端|家庭网关|hg|hgw)" "${input}"; then
        local ont_id=""
        ont_id="$(extract_first_num "${input}")"
        
        if [ -n "${port}" ]; then
            if [ -n "${ont_id}" ] && ! echo "${port}" | grep -q "${ont_id}"; then
                echo "ont:${port} ${ont_id}"
            else
                echo "ont:${port} ${DEFAULT_ONTID}"
            fi
        else
            echo "ont:${DEFAULT_FRAME} ${DEFAULT_SLOT} ${DEFAULT_PORT} ${DEFAULT_ONTID}"
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
    
    # 接口/端口
    if contains "(interface|接口|port|端口|if|状态|up|down|链路)" "${input}"; then
        if [ -n "${port}" ]; then
            echo "raw:display interface ${port}"
        else
            echo "interface"
        fi
        return
    fi
    
    # MAC
    if contains "(mac-address|mac|mac地址|mac表|二层地址)" "${input}"; then
        echo "mac-address"
        return
    fi
    
    # ARP
    if contains "(arp|arp表|三层地址|ip地址表)" "${input}"; then
        echo "arp"
        return
    fi
    
    # CPU
    if contains "(cpu|处理器|负载|load)" "${input}"; then
        echo "cpu"
        return
    fi
    
    # 内存
    if contains "(memory|mem|内存|ram|存储)" "${input}"; then
        echo "memory"
        return
    fi
    
    # 温度
    if contains "(temperature|temp|温度|thermal|高温|发热)" "${input}"; then
        local slot=""
        slot="$(extract_slot "${input}")"
        if [ -n "${slot}" ]; then
            echo "raw:display temperature ${slot}"
        else
            echo "temperature:${DEFAULT_FRAME}"
        fi
        return
    fi
    
    # 配置
    if contains "(config|配置|current-config|当前配置|running-config)" "${input}"; then
        echo "config"
        return
    fi
    
    # 端口状态
    if contains "(port-state|portstate|端口状态|链路状态)" "${input}"; then
        if [ -n "${port}" ]; then
            echo "port-state:${port}"
        else
            echo "port-state:${DEFAULT_PORT}"
        fi
        return
    fi
    
    # ONT状态
    if contains "(ont-state|ontstate|ont状态|终端状态|光猫状态)" "${input}"; then
        if [ -n "${port}" ]; then
            echo "ont-state:${port} ${DEFAULT_ONTID}"
        else
            echo "ont-state:${DEFAULT_PORT} ${DEFAULT_ONTID}"
        fi
        return
    fi
    
    # 业务端口
    if contains "(service-port|sp|业务端口|业务流|gemport|tcont|flow)" "${input}"; then
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
    
    # 流量
    if contains "(traffic|流量|统计|字节|包|packet|byte|counter|perf)" "${input}"; then
        if [ -n "${port}" ]; then
            echo "traffic:${port}"
        else
            echo "traffic:${DEFAULT_PORT}"
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
    
    # 健康
    if contains "(health|健康|状态|summary|overview|概览|综合|总览|整体)" "${input}"; then
        echo "health"
        return
    fi
    
    # DHCP
    if contains "(dhcp|ip分配|地址分配|租约|lease)" "${input}"; then
        echo "raw:display dhcp server lease"
        return
    fi
    
    # 无法匹配 - 返回空，触发文档搜索
    echo ""
}

# 处理特殊模式
if [ "${mode}" = "search" ]; then
    search_in_docs "${USER_INPUT}"
    exit 0
fi

# 智能匹配
RESULT="$(determine_query "${INPUT_LOWER}")"

# 如果无法匹配，尝试文档搜索
if [ -z "${RESULT}" ]; then
    echo "[智能匹配] 无法直接匹配，尝试文档搜索..." >&2
    search_in_docs "${INPUT_LOWER}"
    
    # 尝试模糊匹配常见命令
    if contains "(光|optical|pon|ont)" "${INPUT_LOWER}"; then
        echo "[建议] 尝试: display ont optical-info ${DEFAULT_PORT} ${DEFAULT_ONTID}" >&2
        RESULT="ont-optical:${DEFAULT_PORT} ${DEFAULT_ONTID}"
    elif contains "(板|板卡|board|slot|槽)" "${INPUT_LOWER}"; then
        echo "[建议] 尝试: display board ${DEFAULT_FRAME}" >&2
        RESULT="board:${DEFAULT_FRAME}"
    elif contains "(口|端口|port|接口|if)" "${INPUT_LOWER}"; then
        echo "[建议] 尝试: display interface ${DEFAULT_PORT}" >&2
        RESULT="interface"
    elif contains "(告警|alarm|故障|fault|错误|error)" "${INPUT_LOWER}"; then
        echo "[建议] 尝试: display alarm active" >&2
        RESULT="alarm:active"
    else
        echo "[错误] 无法匹配查询类型，请使用: $0 \"search <关键词>\" 查找正确命令" >&2
        exit 1
    fi
fi

QUERY_TYPE="${RESULT%%:*}"
QUERY_ARGS="${RESULT#*:}"

# 执行查询
echo "[智能匹配] 查询类型: ${QUERY_TYPE}, 参数: ${QUERY_ARGS}" >&2

if [ "${mode}" = "random" ]; then
    echo "[模式] 使用随机参数" >&2
    "${QUERY_SCRIPT}" "random" "${QUERY_TYPE}"
elif [ "${mode}" = "default" ]; then
    echo "[模式] 使用默认参数" >&2
    "${QUERY_SCRIPT}" "default" "${QUERY_TYPE}"
else
    if [ "${QUERY_TYPE}" = "raw" ]; then
        CMD="${QUERY_ARGS}"
        echo "[执行] ${CMD}" >&2
        "${CONNECT_SCRIPT}" "${OLT_IP}" "${OLT_USER}" "${OLT_PASS}" "${CMD}"
    else
        "${QUERY_SCRIPT}" "${QUERY_TYPE}" ${QUERY_ARGS}
    fi
fi
