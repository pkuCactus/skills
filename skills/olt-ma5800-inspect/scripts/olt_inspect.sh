#!/bin/sh
# MA5800 OLT 智能巡检脚本
# 兼容 BusyBox 1.34.1 ash
# 支持自然语言描述，自动映射到检查项
#
# 用法:
#   ./olt_inspect.sh                    # 执行所有检查项
#   ./olt_inspect.sh alarm-param        # 只检查告警参数
#   ./olt_inspect.sh "检查主控板电子开关"  # 智能匹配检查项
#   ./olt_inspect.sh "看看单板有没有问题"  # 智能匹配检查项

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONNECT_SCRIPT="${SCRIPT_DIR}/olt_connect.sh"

# 检查连接参数
if [ -z "${OLT_IP:-}" ] || [ -z "${OLT_USER:-}" ] || [ -z "${OLT_PASS:-}" ]; then
    echo "错误: 请设置 OLT_IP, OLT_USER, OLT_PASS" >&2
    echo "默认值: OLT_IP=70.32.37.65 OLT_USER=root OLT_PASS=Admin@huawei123" >&2
    exit 1
fi

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

# 字符串包含检查 (POSIX 兼容)
contains() {
    case "$2" in
        *"$1"*) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================
# 智能意图识别
# 将用户自然语言描述映射到检查项
# ============================================
parse_intent() {
    local input="$1"
    local lowered
    lowered="$(echo "${input}" | sed 's/.*/\L&/')"
    
    # 检查项: 主控板SRAM检查
    # 关键词: SRAM、主控板SRAM、H801SCUN
    if contains "SRAM" "${input}" || \
       contains "主控板SRAM" "${input}" || \
       contains "H801SCUN" "${input}"; then
        echo "intent:sram"
        return
    fi
    
    # 检查项1: 主控板电子开关 / 告警参数检查
    # 关键词: 电子开关、主控板开关、开关状态、0x02310018
    if contains "电子开关" "${input}" || \
       contains "主控板开关" "${input}" || \
       contains "开关状态" "${input}" || \
       contains "0x02310018" "${input}" || \
       contains "告警参数" "${input}" || \
       contains "参数检查" "${input}" || \
       contains "parameter" "${lowered}" || \
       contains "electronic switch" "${lowered}"; then
        echo "intent:alarm-param"
        return
    fi
    
    # 检查项2: 单板状态
    # 关键词: 单板、board、状态、有没有问题、是否正常
    if contains "单板" "${input}" || \
       contains "board" "${lowered}" || \
       contains "板卡" "${input}" || \
       (contains "状态" "${input}" && contains "板" "${input}"); then
        echo "intent:board"
        return
    fi
    
    # 检查项3: 温度
    # 关键词: 温度、temperature、发热、过热
    if contains "温度" "${input}" || \
       contains "temperature" "${lowered}" || \
       contains "发热" "${input}" || \
       contains "过热" "${input}" || \
       contains "高温" "${input}"; then
        echo "intent:temperature"
        return
    fi
    
    # 检查项4: 告警
    # 关键词: 告警、alarm、警告、故障
    if contains "告警" "${input}" || \
       contains "alarm" "${lowered}" || \
       contains "警告" "${input}" || \
       contains "故障" "${input}"; then
        echo "intent:alarm"
        return
    fi
    
    # 检查项5: 光功率/ONT
    # 关键词: 光功率、ONT、ONU、光猫、终端
    if contains "光功率" "${input}" || \
       contains "optical" "${lowered}" || \
       contains "ont" "${lowered}" || \
       contains "onu" "${lowered}" || \
       contains "光猫" "${input}" || \
       contains "终端" "${input}"; then
        echo "intent:ont-optical"
        return
    fi
    
    # 检查项6: 电源
    # 关键词: 电源、power、功率、供电
    if contains "电源" "${input}" || \
       contains "power" "${lowered}" || \
       contains "功率" "${input}" || \
       contains "供电" "${input}"; then
        echo "intent:power"
        return
    fi
    
    # 检查项7: 风扇
    # 关键词: 风扇、fan、转速、散热
    if contains "风扇" "${input}" || \
       contains "fan" "${lowered}" || \
       contains "转速" "${input}" || \
       contains "散热" "${input}"; then
        echo "intent:fan"
        return
    fi
    
    # 检查项8: 版本
    # 关键词: 版本、version、软件版本
    if contains "版本" "${input}" || \
       contains "version" "${lowered}" || \
       contains "software" "${lowered}"; then
        echo "intent:version"
        return
    fi
    
    # 默认: 全部检查
    echo "intent:all"
}

# ============================================
# 检查项: 主控板SRAM检查
# 逻辑:
#   1. 查主控板型号，如果是 H801SCUN 则继续检查
#   2. 查告警ID 0x02310018，如果 Parameter1=75 且 Parameter2=12 则不通过
# ============================================
check_sram() {
    print_header "检查项: 主控板SRAM检查"
    
    # 第一步: 查主控板型号
    print_info "查询主控板型号..."
    local board_output
    board_output="$(exec_cmd "display board 0")"
    
    # 查找是否有 H801SCUN 主控板
    local is_scun
    is_scun="$(echo "${board_output}" | grep -i "H801SCUN" | head -1)"
    
    if [ -z "${is_scun}" ]; then
        print_pass "主控板不是 H801SCUN，SRAM检查通过"
        return 0
    fi
    
    print_info "检测到 H801SCUN 主控板，继续检查告警参数..."
    
    # 第二步: 查告警参数
    local alarm_id="0x02310018"
    print_info "查询历史告警 ID=${alarm_id}..."
    
    local alarm_output
    alarm_output="$(exec_cmd "display alarm history")"
    
    # 查找指定告警ID的记录块
    local alarm_block
    alarm_block="$(echo "${alarm_output}" | awk '/AlarmID.*'"${alarm_id}"'/,/PARAMETERS/')"
    
    if [ -z "${alarm_block}" ]; then
        print_pass "主控板是 H801SCUN，但未找到告警 ID=${alarm_id}，SRAM检查通过"
        return 0
    fi
    
    # 提取 Parameter1 和 Parameter2
    local param1 param2
    param1="$(echo "${alarm_block}" | grep -oE 'Parameter1[^0-9]*([0-9]+)' | grep -oE '[0-9]+' | tail -1)"
    param2="$(echo "${alarm_block}" | grep -oE 'Parameter2[^0-9]*([0-9]+)' | grep -oE '[0-9]+' | tail -1)"
    
    print_info "Parameter1=${param1:-未找到}, Parameter2=${param2:-未找到}"
    
    # 判断: 如果 Parameter1=75 且 Parameter2=12，则检查不通过
    if [ "${param1}" = "75" ] && [ "${param2}" = "12" ]; then
        print_fail "主控板是 H801SCUN，且 Parameter1=75 且 Parameter2=12，SRAM检查不通过"
        return 1
    else
        print_pass "主控板是 H801SCUN，但 Parameter1=${param1}, Parameter2=${param2}，SRAM检查通过"
        return 0
    fi
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
# 检查项2: 主控板状态检查
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
# 检查项3: 温度检查
# ============================================
check_temperature() {
    print_header "检查项3: 温度检查"
    
    print_info "查询设备温度..."
    local temp_output
    temp_output="$(exec_cmd "display temperature 0")"
    
    # 检查是否有高温告警
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
# 检查项4: 告警检查
# ============================================
check_alarm() {
    print_header "检查项4: 活动告警检查"
    
    print_info "查询活动告警..."
    local alarm_output
    alarm_output="$(exec_cmd "display alarm active")"
    
    # 检查是否有活动告警
    local active_alarms
    active_alarms="$(echo "${alarm_output}" | grep -E '^[[:space:]]*[0-9]' | head -5)"
    
    if [ -n "${active_alarms}" ]; then
        print_warn "发现活动告警:"
        echo "${active_alarms}" | while read -r line; do
            echo "    ${line}"
        done
        return 1
    else
        print_pass "无活动告警"
        return 0
    fi
}

# ============================================
# 检查项5: ONT光功率检查
# ============================================
check_ont_optical() {
    print_header "检查项5: ONT光功率检查"
    
    print_info "查询ONT光功率..."
    local optical_output
    optical_output="$(exec_cmd "display ont optical-info 0/1/1 all")"
    
    # 检查是否有异常光功率 (简化检查)
    local abnormal_optical
    abnormal_optical="$(echo "${optical_output}" | grep -iE '(low|high|error|fail)' | head -5)"
    
    if [ -n "${abnormal_optical}" ]; then
        print_warn "发现光功率异常:"
        echo "${abnormal_optical}" | while read -r line; do
            echo "    ${line}"
        done
        return 1
    else
        print_pass "ONT光功率正常"
        return 0
    fi
}

# ============================================
# 检查项6: 电源检查
# ============================================
check_power() {
    print_header "检查项6: 电源状态检查"
    
    print_info "查询电源状态..."
    local power_output
    power_output="$(exec_cmd "display power 0")"
    
    # 检查是否有异常电源
    local abnormal_power
    abnormal_power="$(echo "${power_output}" | grep -iE '(fail|error|abnormal)' | head -5)"
    
    if [ -n "${abnormal_power}" ]; then
        print_warn "发现电源异常:"
        echo "${abnormal_power}" | while read -r line; do
            echo "    ${line}"
        done
        return 1
    else
        print_pass "电源状态正常"
        return 0
    fi
}

# ============================================
# 检查项7: 风扇检查
# ============================================
check_fan() {
    print_header "检查项7: 风扇状态检查"
    
    print_info "查询风扇状态..."
    local fan_output
    fan_output="$(exec_cmd "display emu")"
    
    # 检查是否有异常风扇
    local abnormal_fan
    abnormal_fan="$(echo "${fan_output}" | grep -iE '(fail|error|abnormal|stop)' | head -5)"
    
    if [ -n "${abnormal_fan}" ]; then
        print_warn "发现风扇异常:"
        echo "${abnormal_fan}" | while read -r line; do
            echo "    ${line}"
        done
        return 1
    else
        print_pass "风扇状态正常"
        return 0
    fi
}

# ============================================
# 检查项8: 版本检查
# ============================================
check_version() {
    print_header "检查项8: 版本信息检查"
    
    print_info "查询版本信息..."
    local version_output
    version_output="$(exec_cmd "display version")"
    
    # 显示版本信息摘要
    local version_line
    version_line="$(echo "${version_output}" | grep -i 'version' | head -1)"
    
    if [ -n "${version_line}" ]; then
        print_info "版本: ${version_line}"
        print_pass "版本信息获取成功"
        return 0
    else
        print_warn "无法获取版本信息"
        return 1
    fi
}

# ============================================
# 执行单个检查项
# ============================================
run_check() {
    local check_name="$1"
    case "${check_name}" in
        sram)
            check_sram
            ;;
        alarm-param)
            check_alarm_param
            ;;
        board)
            check_board_status
            ;;
        temperature)
            check_temperature
            ;;
        alarm)
            check_alarm
            ;;
        ont-optical)
            check_ont_optical
            ;;
        power)
            check_power
            ;;
        fan)
            check_fan
            ;;
        version)
            check_version
            ;;
        *)
            echo "未知检查项: ${check_name}" >&2
            return 1
            ;;
    esac
}

# ============================================
# 主函数
# ============================================
main() {
    local input="${1:-all}"
    
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║     MA5800 OLT 设备巡检报告          ║"
    echo "╚══════════════════════════════════════╝"
    echo "设备IP: ${OLT_IP}"
    echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 判断输入是命令还是自然语言描述
    local intent=""
    
    case "${input}" in
        sram|alarm-param|board|temperature|alarm|ont-optical|power|fan|version|all)
            # 直接是命令
            intent="${input}"
            ;;
        *)
            # 自然语言描述，解析意图
            print_info "解析用户意图: '${input}'"
            intent="$(parse_intent "${input}")"
            intent="${intent#intent:}"  # 去掉前缀
            print_info "匹配到检查项: ${intent}"
            echo ""
            ;;
    esac
    
    # 执行检查
    case "${intent}" in
        all)
            check_sram
            check_alarm_param
            check_board_status
            check_temperature
            check_alarm
            check_ont_optical
            check_power
            check_fan
            check_version
            ;;
        *)
            run_check "${intent}"
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
