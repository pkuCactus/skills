#!/bin/sh
# MA5800 OLT 查询入口脚本
# 兼容 BusyBox 1.34.1 ash
# 支持默认值、随机参数、文档搜索
#
# 用法: ./olt_query.sh <query_type> [args...]
#   或: ./olt_query.sh random <query_type>
#   或: ./olt_query.sh default <query_type>
#   或: ./olt_query.sh search <keyword>

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONNECT_SCRIPT="${SCRIPT_DIR}/olt_connect.sh"
DOC_DIR="${DOC_DIR:-/tmp/ma5800_md/cmd}"

# 默认值配置
DEFAULT_FRAME="0"
DEFAULT_SLOT="0/1"
DEFAULT_PORT="0/1/1"
DEFAULT_ONTID="all"
DEFAULT_VLAN="all"
DEFAULT_SP="all"

# 检查连接参数
if [ -z "${OLT_IP:-}" ] || [ -z "${OLT_USER:-}" ] || [ -z "${OLT_PASS:-}" ]; then
    echo "错误: 请设置 OLT_IP, OLT_USER, OLT_PASS" >&2
    echo "默认值: OLT_IP=70.32.37.65 OLT_USER=root OLT_PASS=Admin@huawei123" >&2
    exit 1
fi

# 查询类型
QUERY_TYPE="${1:-}"
shift 2>/dev/null || true

# 随机数生成 (BusyBox 兼容)
random_num() {
    local max="${1:-10}"
    local min="${2:-0}"
    # 使用 /dev/urandom
    local rand
    rand="$(head -c 4 /dev/urandom 2>/dev/null | od -An -tu4 | awk '{print $1 % ('${max}' - '${min}' + 1) + '${min}'}')"
    if [ -z "${rand}" ]; then
        # fallback
        rand="$(date +%s | tail -c 3 | sed 's/^0//')"
        rand=$(( rand % (max - min + 1) + min ))
    fi
    echo "${rand}"
}

# 从文档搜索命令参数
search_doc_for_params() {
    local cmd_name="$1"
    local doc_file="${DOC_DIR}/display_${cmd_name}.md"
    
    if [ ! -f "${doc_file}" ]; then
        # 尝试模糊匹配
        doc_file="$(ls "${DOC_DIR}" | grep -i "display_${cmd_name}" | head -1)"
        if [ -n "${doc_file}" ]; then
            doc_file="${DOC_DIR}/${doc_file}"
        fi
    fi
    
    if [ -f "${doc_file}" ]; then
        # 提取参数说明和默认值
        echo "=== 命令文档: display ${cmd_name} ===" >&2
        grep -A2 "命令格式" "${doc_file}" | head -5 >&2
        grep "使用实例" "${doc_file}" | head -1 >&2
        grep -B1 -A1 "举例：" "${doc_file}" | head -6 >&2
    fi
}

# 获取命令的默认参数建议
get_default_params() {
    local cmd_name="$1"
    case "${cmd_name}" in
        board) echo "${DEFAULT_FRAME}" ;;
        ont) echo "${DEFAULT_FRAME} ${DEFAULT_SLOT} ${DEFAULT_PORT} ${DEFAULT_ONTID}" ;;
        ont-optical) echo "${DEFAULT_PORT} ${DEFAULT_ONTID}" ;;
        ont-state) echo "${DEFAULT_PORT} ${DEFAULT_ONTID}" ;;
        port-state) echo "${DEFAULT_PORT}" ;;
        traffic) echo "${DEFAULT_PORT}" ;;
        temperature) echo "${DEFAULT_FRAME}" ;;
        power) echo "${DEFAULT_FRAME}" ;;
        power-detail) echo "${DEFAULT_FRAME}" ;;
        interface) echo "" ;;
        version) echo "" ;;
        alarm) echo "active" ;;
        mac-address) echo "" ;;
        arp) echo "" ;;
        cpu) echo "" ;;
        memory) echo "" ;;
        config) echo "" ;;
        service-port) echo "${DEFAULT_SP}" ;;
        vlan) echo "${DEFAULT_VLAN}" ;;
        log) echo "operation" ;;
        health) echo "" ;;
        fan|emu) echo "" ;;
        *) echo "" ;;
    esac
}

# 生成随机参数
generate_random_params() {
    local cmd_name="$1"
    case "${cmd_name}" in
        board)
            echo "0/$(random_num 16 1)"
            ;;
        ont)
            local fid="$(random_num 2 0)"
            local sid="$(random_num 16 1)"
            local pid="$(random_num 16 1)"
            local oid="$(random_num 127 0)"
            echo "${fid} ${sid} ${pid} ${oid}"
            ;;
        ont-optical|ontoptical)
            local pid="$(random_num 16 1)"
            local oid="$(random_num 127 0)"
            echo "0/1/${pid} ${oid}"
            ;;
        ont-state)
            local pid="$(random_num 16 1)"
            local oid="$(random_num 127 0)"
            echo "0/1/${pid} ${oid}"
            ;;
        port-state)
            local pid="$(random_num 16 1)"
            echo "0/1/${pid}"
            ;;
        traffic)
            local pid="$(random_num 16 1)"
            echo "0/1/${pid}"
            ;;
        temperature)
            local sid="$(random_num 16 1)"
            echo "0/${sid}"
            ;;
        power)
            local sid="$(random_num 16 1)"
            echo "0/${sid}"
            ;;
        power-detail)
            local sid="$(random_num 16 1)"
            echo "0/${sid}"
            ;;
        vlan)
            echo "$(random_num 4094 1)"
            ;;
        service-port|sp)
            echo "$(random_num 1000 1)"
            ;;
        interface)
            local types="meth vlanif loopback tunnel null"
            local num="$(random_num 5 1)"
            echo "$(echo "${types}" | awk '{print $'${num}'}')"
            ;;
        *)
            echo ""
            ;;
    esac
}

# 构建命令
case "${QUERY_TYPE}" in
    board)
        if [ $# -eq 0 ]; then
            CMD="display board ${DEFAULT_FRAME}"
        elif [ $# -eq 1 ]; then
            CMD="display board ${1}"
        else
            CMD="display board ${1}/${2}"
        fi
        ;;
    
    version)
        if [ $# -eq 0 ]; then
            CMD="display version"
        else
            CMD="display version ${1}"
        fi
        ;;
    
    ont)
        if [ $# -lt 3 ]; then
            CMD="display ont info ${DEFAULT_FRAME} ${DEFAULT_SLOT} ${DEFAULT_PORT} ${DEFAULT_ONTID}"
        else
            local_oid="${4:-${DEFAULT_ONTID}}"
            CMD="display ont info ${1} ${2} ${3} ${local_oid}"
        fi
        ;;
    
    ont-optical|ontoptical|optical)
        if [ $# -lt 1 ]; then
            CMD="display ont optical-info ${DEFAULT_PORT} ${DEFAULT_ONTID}"
        else
            CMD="display ont optical-info ${1} ${2:-${DEFAULT_ONTID}}"
        fi
        ;;
    
    alarm|alarms)
        local_alarm_type="${1:-active}"
        CMD="display alarm ${local_alarm_type}"
        ;;
    
    interface|if)
        if [ $# -eq 0 ]; then
            CMD="display interface"
        else
            CMD="display interface ${1}"
        fi
        ;;
    
    mac-address|mac)
        CMD="display mac-address"
        ;;
    
    arp)
        CMD="display arp"
        ;;
    
    cpu)
        CMD="display health"
        ;;
    
    memory|mem)
        CMD="display memory"
        ;;
    
    temperature|temp)
        if [ $# -eq 0 ]; then
            CMD="display temperature ${DEFAULT_FRAME}"
        else
            CMD="display temperature ${1}"
        fi
        ;;
    
    config|current-config)
        CMD="display current-configuration"
        ;;
    
    port-state|portstate)
        if [ $# -lt 1 ]; then
            CMD="display port state ${DEFAULT_PORT}"
        else
            CMD="display port state ${1}"
        fi
        ;;
    
    ont-state|ontstate)
        if [ $# -lt 1 ]; then
            CMD="display ont state ${DEFAULT_PORT} ${DEFAULT_ONTID}"
        else
            CMD="display ont state ${1} ${2:-${DEFAULT_ONTID}}"
        fi
        ;;
    
    service-port|sp)
        CMD="display service-port ${1:-${DEFAULT_SP}}"
        ;;
    
    vlan)
        CMD="display vlan ${1:-${DEFAULT_VLAN}}"
        ;;
    
    traffic)
        if [ $# -lt 1 ]; then
            CMD="display port traffic ${DEFAULT_PORT}"
        else
            CMD="display port traffic ${1}"
        fi
        ;;
    
    log|logs)
        local_log_type="${1:-operation}"
        CMD="display log ${local_log_type}"
        ;;
    
    health)
        CMD="display health"
        ;;
    
    fan|emu|cooling)
        CMD="display emu"
        ;;
    
    power|psu|battery)
        if [ $# -ge 1 ]; then
            CMD="display power ${1}"
        else
            CMD="display power ${DEFAULT_FRAME}"
        fi
        ;;
    
    power-detail|powerdetail)
        if [ $# -ge 1 ]; then
            CMD="display power detail ${1}"
        else
            CMD="display power detail ${DEFAULT_FRAME}"
        fi
        ;;
    
    # 特殊模式: random
    random)
        local subcmd="${1:-}"
        if [ -z "${subcmd}" ]; then
            echo "用法: random <查询类型>" >&2
            exit 1
        fi
        local rand_params
        rand_params="$(generate_random_params "${subcmd}")"
        echo "[随机参数] ${subcmd} ${rand_params}" >&2
        "$0" "${subcmd}" ${rand_params}
        exit $?
        ;;
    
    # 特殊模式: default
    default)
        local subcmd="${1:-}"
        if [ -z "${subcmd}" ]; then
            echo "用法: default <查询类型>" >&2
            exit 1
        fi
        local def_params
        def_params="$(get_default_params "${subcmd}")"
        echo "[默认参数] ${subcmd} ${def_params}" >&2
        "$0" "${subcmd}" ${def_params}
        exit $?
        ;;
    
    # 特殊模式: search
    search|find|doc)
        local keyword="${1:-}"
        if [ -z "${keyword}" ]; then
            echo "用法: search <关键词>" >&2
            exit 1
        fi
        echo "=== 在文档中搜索: ${keyword} ===" >&2
        if [ -d "${DOC_DIR}" ]; then
            local results
            results="$(grep -l "${keyword}" "${DOC_DIR}"/*.md 2>/dev/null | head -10)"
            if [ -n "${results}" ]; then
                echo "找到以下相关命令:" >&2
                for f in ${results}; do
                    local cmd
                    cmd="$(basename "$f" .md | sed 's/^display_//' | sed 's/_/ /g')"
                    echo "  - display ${cmd}" >&2
                done
            else
                echo "未找到相关命令" >&2
            fi
        else
            echo "文档目录不存在: ${DOC_DIR}" >&2
        fi
        exit 0
        ;;
    
    *)
        if [ -n "${QUERY_TYPE}" ]; then
            CMD="${QUERY_TYPE} ${*}"
        else
            echo "错误: 未指定查询类型" >&2
            echo "支持的查询类型: board, version, ont, ont-optical, alarm, interface, mac-address, arp, cpu, memory, temperature, config, port-state, ont-state, service-port, vlan, traffic, log, health, fan/emu, power, power-detail" >&2
            echo "特殊模式: random, default, search" >&2
            exit 1
        fi
        ;;
esac

# 执行命令
echo "执行: ${CMD}"
echo "----------------------------------------"
"${CONNECT_SCRIPT}" "${OLT_IP}" "${OLT_USER}" "${OLT_PASS}" "${CMD}"
