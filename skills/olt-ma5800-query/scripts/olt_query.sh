#!/bin/sh
# ============================================================================
# MA5800 OLT 查询入口脚本 (olt_query.sh)
# ============================================================================
# 功能: 查询类型分发器，将简化的查询类型映射为完整的 display CLI 命令
# 兼容: BusyBox 1.34.1 ash / POSIX sh
#
# 用法:
#   标准查询: ./olt_query.sh <query_type> [args...]
#   随机参数: ./olt_query.sh random <query_type>
#   默认参数: ./olt_query.sh default <query_type>
#   文档搜索: ./olt_query.sh search <keyword>
#
# 支持的查询类型:
#   board, version, ont, ont-optical, alarm, interface, mac-address, arp,
#   cpu, memory, temperature, config, port-state, ont-state, service-port,
#   vlan, traffic, log, health, fan/emu, power, power-detail
#
# 默认参数策略:
#   机框 frameid → 0
#   槽位 slotid → 0/1
#   PON端口 portid → 0/1/1
#   ONT ID → all
#   VLAN → all
#   业务端口 → all
# ============================================================================

set -eu

# 脚本所在目录 (用于引用同目录的 olt_connect.sh)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONNECT_SCRIPT="${SCRIPT_DIR}/olt_connect.sh"

# 命令文档目录 (用于 search 模式查找命令说明)
DOC_DIR="${DOC_DIR:-~/.openclaw/ma5800_md/cmd}"

# 默认参数配置 (与 olt_smart_query.sh 保持一致)
DEFAULT_FRAME="0"
DEFAULT_SLOT="0/1"
DEFAULT_PORT="0/1/1"
DEFAULT_ONTID="all"
DEFAULT_VLAN="all"
DEFAULT_SP="all"

# 检查连接参数是否已设置 (环境变量或脚本内置默认值)
if [ -z "${OLT_IP:-}" ] || [ -z "${OLT_USER:-}" ] || [ -z "${OLT_PASS:-}" ]; then
    echo "错误: 请设置 OLT_IP, OLT_USER, OLT_PASS" >&2
    echo "默认值: OLT_IP=70.32.37.65 OLT_USER=root OLT_PASS=Admin@huawei123" >&2
    exit 1
fi

# 查询类型 (第一个参数)
QUERY_TYPE="${1:-}"
shift 2>/dev/null || true

# ============================================================================
# 辅助函数: 生成指定范围的随机整数 (BusyBox 兼容)
# ============================================================================
# 参数:
#   $1 - 最大值 max (默认10)
#   $2 - 最小值 min (默认0)
# 返回: [min, max] 范围内的随机整数
#
# 随机数来源优先级:
#   1. /dev/urandom (熵源, 最可靠)
#   2. date +%s 时间戳 (fallback, 低质量但可用)
# ============================================================================
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

# ============================================================================
# 辅助函数: 从 Markdown 文档中提取命令格式和参数说明
# ============================================================================
# 参数: $1 - 命令名称 (如 "ont_optical-info" 或 "temperature")
# 功能:
#   1. 精确匹配: display_${cmd_name}.md
#   2. 模糊匹配: 在目录中 grep 匹配 display_${cmd_name}
#   3. 提取并打印: 命令格式 + 使用实例 + 举例
# ============================================================================
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

# ============================================================================
# 辅助函数: 获取指定查询类型的默认参数
# ============================================================================
# 参数: $1 - 命令名称
# 返回: 该命令的推荐默认参数字符串
#
# 设计原则:
#   - 槽位类命令 (board/version/temperature/power) → 默认机框 0
#   - ONT 类命令 → 完整路径: 0(机框) 0/1(槽位) 0/1/1(端口) all(全部ONT)
#   - 端口类命令 → 默认端口 0/1/1
#   - 全局类命令 (interface/mac-address/arp/health) → 无需参数
#   - 告警/日志 → 默认查询 active/operation
# ============================================================================
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

# ============================================================================
# 辅助函数: 生成指定查询类型的随机参数 (用于测试和探索)
# ============================================================================
# 参数: $1 - 命令名称
# 返回: 随机生成的参数字符串
#
# 随机范围 (基于 MA5800 典型硬件规格):
#   - 机框 frameid: 0~2
#   - 槽位 slotid: 1~16
#   - PON端口 portid: 1~16
#   - ONT ID: 0~127
#   - VLAN: 1~4094
#   - 业务端口 SP: 1~1000
#
# 警告: 随机参数可能指向不存在的槽位/端口/ONT, 执行可能失败
# ============================================================================
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

# ============================================================================
# 主逻辑: 根据查询类型构建 display 命令
# ============================================================================
# 每个 case 分支的处理模式:
#   1. 无参数 → 使用 DEFAULT_XXX 默认值
#   2. 有参数 → 直接使用用户提供的参数
#   3. 特殊模式 (random/default/search) → 独立处理
#
# 命令构建完成后, 最后统一通过 olt_connect.sh 执行
# ============================================================================
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
    
    # ============================================================================
    # 特殊模式: random (随机参数模式)
    # ============================================================================
    # 功能: 为指定查询类型生成随机参数并执行，用于测试或探索
    # 用法: ./olt_query.sh random <查询类型>
    # 示例: ./olt_query.sh random board → 可能执行 display board 0/7
    # 注意: 随机参数可能指向不存在的硬件，执行可能失败
    # ============================================================================
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
    
    # ============================================================================
    # 特殊模式: default (默认参数模式)
    # ============================================================================
    # 功能: 使用预定义的默认参数执行查询
    # 用法: ./olt_query.sh default <查询类型>
    # 示例: ./olt_query.sh default ont → 执行 display ont info 0 0/1 0/1/1 all
    # ============================================================================
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
    
    # ============================================================================
    # 特殊模式: search (文档搜索模式)
    # ============================================================================
    # 功能: 在 ma5800_md 命令文档中搜索关键词
    # 用法: ./olt_query.sh search <关键词>
    # 示例: ./olt_query.sh search 光功率
    # 搜索范围: ${OPENCLAW_ROOT}/ma5800_md/cmd/*.md 文件内容
    # ============================================================================
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
    
    # ============================================================================
    # 兜底处理: 未识别的查询类型
    # ============================================================================
    # 策略: 将用户输入原样拼接为 display 命令尝试执行
    # 适用场景: 用户直接传入完整的 display 命令片段
    # 风险: 如果参数格式错误，OLT 会返回错误
    # ============================================================================
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

# ============================================================================
# 执行阶段: 将构建好的 display 命令提交给 olt_connect.sh
# ============================================================================
# 输出执行信息 → 调用底层 SSH 连接脚本 → 返回结果
# ============================================================================
echo "执行: ${CMD}"
echo "----------------------------------------"
"${CONNECT_SCRIPT}" "${OLT_IP}" "${OLT_USER}" "${OLT_PASS}" "${CMD}"
