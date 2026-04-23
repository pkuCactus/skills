#!/bin/bash
# MA5800 OLT 查询入口脚本
# 用法: ./olt_query.sh <query_type> [args...]
# 
# 支持的查询类型:
#   board [frameid] [slotid]          - 查询单板信息
#   version [frameid/slotid]          - 查询版本信息
#   ont <frameid> <slotid> <portid> [ontid|all]  - 查询ONT信息
#   ont-optical <portid> [ontid|all]  - 查询ONT光模块
#   alarm [active|history]            - 查询告警
#   interface [ifname]               - 查询接口状态
#   mac-address                       - 查询MAC地址表
#   arp                                - 查询ARP表
#   cpu                                - 查询CPU使用率
#   memory                             - 查询内存使用率
#   temperature                        - 查询温度
#   config                             - 查询当前配置
#   port-state <portid>               - 查询端口状态
#   ont-state <portid> [ontid|all]    - 查询ONT状态
#   service-port [id|all]             - 查询业务端口
#   vlan [vlanid|all]                 - 查询VLAN信息
#   traffic [portid]                  - 查询流量统计
#   log [operation|security]          - 查询日志
#   health                             - 查询设备健康状态
#   fan|emu|cooling                    - 查询风扇/EMU状态
#   power|psu|battery [slot]           - 查询电源/功率信息
#
# 环境变量:
#   OLT_IP, OLT_USER, OLT_PASS, OLT_TIMEOUT, OLT_WIDTH

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONNECT_SCRIPT="${SCRIPT_DIR}/olt_connect.sh"

# 检查连接脚本
if [[ ! -x "${CONNECT_SCRIPT}" ]]; then
    chmod +x "${CONNECT_SCRIPT}" 2>/dev/null || true
fi

# 检查 OLT 连接参数
if [[ -z "${OLT_IP:-}" || -z "${OLT_USER:-}" || -z "${OLT_PASS:-}" ]]; then
    echo "错误: 请设置环境变量 OLT_IP, OLT_USER, OLT_PASS" >&2
    echo "默认值: OLT_IP=70.32.37.65 OLT_USER=root OLT_PASS=Admin@huawei123" >&2
    echo "示例: export OLT_IP=70.32.37.65 OLT_USER=root OLT_PASS=Admin@huawei123" >&2
    exit 1
fi

# 查询类型
QUERY_TYPE="${1:-}"
shift || true

case "${QUERY_TYPE}" in
    board)
        # display board [frameid] [frameid/slotid]
        if [[ $# -eq 0 ]]; then
            CMD="display board"
        elif [[ $# -eq 1 ]]; then
            CMD="display board ${1}"
        else
            CMD="display board ${1}/${2}"
        fi
        ;;
    
    version)
        # display version [frameid/slotid]
        if [[ $# -eq 0 ]]; then
            CMD="display version"
        else
            CMD="display version ${1}"
        fi
        ;;
    
    ont)
        # display ont info <frameid> <slotid> <portid> [ontid|all]
        if [[ $# -lt 3 ]]; then
            echo "用法: ont <frameid> <slotid> <portid> [ontid|all]" >&2
            exit 1
        fi
        local_fid="${1}"
        local_sid="${2}"
        local_pid="${3}"
        local_oid="${4:-all}"
        CMD="display ont info ${local_fid} ${local_sid} ${local_pid} ${local_oid}"
        ;;
    
    ont-optical|ontoptical|optical)
        # display ont optical-info <portid> [ontid|all]
        if [[ $# -lt 1 ]]; then
            echo "用法: ont-optical <portid> [ontid|all]" >&2
            exit 1
        fi
        CMD="display ont optical-info ${1} ${2:-all}"
        ;;
    
    alarm|alarms)
        # display alarm active / display alarm history
        local_alarm_type="${1:-active}"
        CMD="display alarm ${local_alarm_type}"
        ;;
    
    interface|if)
        # display interface [ifname]
        if [[ $# -eq 0 ]]; then
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
        CMD="display temperature"
        ;;
    
    config|current-config)
        CMD="display current-configuration"
        ;;
    
    port-state|portstate)
        # display port state <portid>
        if [[ $# -lt 1 ]]; then
            echo "用法: port-state <portid>" >&2
            exit 1
        fi
        CMD="display port state ${1}"
        ;;
    
    ont-state|ontstate)
        # display ont state <portid> [ontid|all]
        if [[ $# -lt 1 ]]; then
            echo "用法: ont-state <portid> [ontid|all]" >&2
            exit 1
        fi
        CMD="display ont state ${1} ${2:-all}"
        ;;
    
    service-port|sp)
        # display service-port [id|all]
        CMD="display service-port ${1:-all}"
        ;;
    
    vlan)
        # display vlan [vlanid|all]
        CMD="display vlan ${1:-all}"
        ;;
    
    traffic)
        # display port traffic <portid>
        if [[ $# -lt 1 ]]; then
            echo "用法: traffic <portid>" >&2
            exit 1
        fi
        CMD="display port traffic ${1}"
        ;;
    
    log|logs)
        local_log_type="${1:-operation}"
        CMD="display log ${local_log_type}"
        ;;
    
    health)
        CMD="display health"
        ;;
    
    fan|emu|cooling)
        # display emu
        CMD="display emu"
        ;;
    
    power|psu|battery)
        # display power / display power detail
        if [[ $# -ge 1 ]]; then
            CMD="display power detail ${1}"
        else
            CMD="display power"
        fi
        ;;
    
    *)
        # 未识别的查询类型，尝试作为原始命令传递
        if [[ -n "${QUERY_TYPE}" ]]; then
            CMD="${QUERY_TYPE} ${*}"
        else
            echo "错误: 未指定查询类型" >&2
            echo "支持的查询类型: board, version, ont, ont-optical, alarm, interface, mac-address, arp, cpu, memory, temperature, config, port-state, ont-state, service-port, vlan, traffic, log, health, fan/emu, power" >&2
            exit 1
        fi
        ;;
esac

# 执行命令
echo "执行: ${CMD}"
echo "----------------------------------------"
"${CONNECT_SCRIPT}" "${OLT_IP}" "${OLT_USER}" "${OLT_PASS}" "${CMD}"
