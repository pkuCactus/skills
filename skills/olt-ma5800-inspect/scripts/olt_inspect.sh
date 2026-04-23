#!/bin/sh
# MA5800 OLT 巡检脚本
# 兼容 BusyBox 1.34.1 ash
# 用法: ./olt_inspect.sh [check_type]
#
# 检查项:
#   alarm-param    - 检查告警ID 0x02310018 的 Parameter1/Parameter2 是否为 67/35
#   all            - 执行所有检查项

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONNECT_SCRIPT="${SCRIPT_DIR}/olt_connect.sh"

# 检查连接参数
if [ -z "${OLT_IP:-}" ] || [ -z "${OLT_USER:-}" ] || [ -z "${OLT_PASS:-}" ]; then
    echo "错误: 请设置 OLT_IP, OLT_USER, OLT_PASS" >&2
    echo "默认值: OLT_IP=70.32.37.65 OLT_USER=root OLT_PASS=Admin@huawei123" >&2
    exit 1
fi

# 颜色定义 (如果终端支持)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查结果计数
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# 输出函数
print_header() {
    echo ""
    echo "========================================"
    echo "  $1"
    echo "========================================"
}

print_pass() {
    echo "[✓] $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

print_fail() {
    echo "[✗] $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

print_warn() {
    echo "[!] $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

print_info() {
    echo "[i] $1"
}

# 执行命令并获取输出
exec_cmd() {
    local cmd="$1"
    "${CONNECT_SCRIPT}" "${OLT_IP}" "${OLT_USER}" "${OLT_PASS}" "${cmd}"
}

# ============================================
# 检查项1: 告警参数检查
# 检查告警ID 0x02310018 的 Parameter1/Parameter2 是否为 67/35
# ============================================
check_alarm_param() {
    print_header "检查项1: 告警参数检查 (ID: 0x02310018)"
    
    local alarm_id="${1:-0x02310018}"
    print_info "查询历史告警 ID=${alarm_id}..."
    
    local alarm_output
    alarm_output="$(exec_cmd "display alarm history")"
    
    # 查找指定告警ID的记录块 (从 AlarmID 到 PARAMETERS 之间的内容)
    local alarm_block
    alarm_block="$(echo "${alarm_output}" | awk '/AlarmID.*'"${alarm_id}"'/,/PARAMETERS/')"
    
    if [ -z "${alarm_block}" ]; then
        print_pass "未找到告警 ID=${alarm_id}，检查通过"
        return 0
    fi
    
    print_info "找到告警记录，提取参数..."
    
    # 提取 Parameter1 和 Parameter2
    local param1 param2
    param1="$(echo "${alarm_block}" | grep -oE 'Parameter1[^0-9]*([0-9]+)' | grep -oE '[0-9]+' | tail -1)"
    param2="$(echo "${alarm_block}" | grep -oE 'Parameter2[^0-9]*([0-9]+)' | grep -oE '[0-9]+' | tail -1)"
    
    print_info "Parameter1=${param1:-未找到}, Parameter2=${param2:-未找到}"
    
    # 判断: 如果 Parameter1=67 且 Parameter2=35，则检查不通过
    if [ "${param1}" = "67" ] && [ "${param2}" = "35" ]; then
        print_fail "Parameter1=67 且 Parameter2=35，检查不通过"
        return 1
    else
        print_pass "Parameter1=${param1}, Parameter2=${param2}，不符合告警条件 (67,35)，检查通过"
        return 0
    fi
}

# ============================================
# 检查项2: 主控板状态检查 (示例，后续扩展)
# ============================================
check_board_status() {
    print_header "检查项2: 主控板状态检查"
    
    print_info "查询单板状态..."
    local board_output
    board_output="$(exec_cmd "display board 0")"
    
    # 检查是否有 Failed/Abnormal 状态的单板
    local failed_boards
    failed_boards="$(echo "${board_output}" | grep -E '(Failed|Abnormal|Offline)' | grep -v 'Normal')"
    
    if [ -n "${failed_boards}" ]; then
        print_fail "发现异常单板:"
        echo "${failed_boards}" | while read -r line; do
            echo "    ${line}"
        done
        return 1
    else
        print_pass "所有单板状态正常"
        return 0
    fi
}

# ============================================
# 检查项3: 温度检查 (示例，后续扩展)
# ============================================
check_temperature() {
    print_header "检查项3: 温度检查"
    
    print_info "查询设备温度..."
    local temp_output
    temp_output="$(exec_cmd "display temperature 0")"
    
    # 检查是否有高温告警 (这里简化处理，实际应根据阈值判断)
    local high_temp
    high_temp="$(echo "${temp_output}" | grep -iE '(High|Critical|Over)' | head -5)"
    
    if [ -n "${high_temp}" ]; then
        print_warn "发现温度异常:"
        echo "${high_temp}" | while read -r line; do
            echo "    ${line}"
        done
        return 1
    else
        print_pass "温度正常"
        return 0
    fi
}

# ============================================
# 主函数
# ============================================
main() {
    local check_type="${1:-all}"
    
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║     MA5800 OLT 设备巡检报告          ║"
    echo "╚══════════════════════════════════════╝"
    echo "设备IP: ${OLT_IP}"
    echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    case "${check_type}" in
        alarm-param|alarmparam)
            check_alarm_param
            ;;
        board)
            check_board_status
            ;;
        temperature|temp)
            check_temperature
            ;;
        all|*)
            check_alarm_param
            check_board_status
            check_temperature
            ;;
    esac
    
    # 输出汇总
    echo ""
    echo "========================================"
    echo "           巡检结果汇总"
    echo "========================================"
    echo "通过: ${PASS_COUNT} 项"
    echo "失败: ${FAIL_COUNT} 项"
    echo "警告: ${WARN_COUNT} 项"
    echo ""
    
    if [ ${FAIL_COUNT} -gt 0 ]; then
        echo "结论: ❌ 巡检不通过，存在 ${FAIL_COUNT} 项异常"
        exit 1
    elif [ ${WARN_COUNT} -gt 0 ]; then
        echo "结论: ⚠️ 巡检通过，但存在 ${WARN_COUNT} 项警告"
        exit 0
    else
        echo "结论: ✅ 巡检全部通过"
        exit 0
    fi
}

main "$@"
