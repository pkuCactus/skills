

# ============================================================================
# 核心函数: 在命令文档目录中搜索关键词
# ============================================================================
# 参数: $1 - 搜索关键词
# 功能:
#   1. 按文件名匹配搜索
#   2. 按文件内容匹配搜索
#   3. 合并结果去重
#   4. 提取命令名并打印 (含命令格式)
#
# 输出格式:
#   === 找到的相关命令 ===
#     - display <命令名>
#       命令格式: display <命令> <参数>
#
# 返回: 找到命令返回 0，未找到返回 1
# ============================================================================
search_in_docs() {
    local keyword="$1"
    echo "[搜索文档] 关键词: ${keyword}" >&2
    
    # 检查文档目录是否存在
    if [ ! -d "${DOC_DIR}" ]; then
        echo "[警告] 文档目录不存在: ${DOC_DIR}" >&2
        return 1
    fi
    
    # 搜索文件名匹配 (如 display_ont_optical-info.md)
    local file_matches=""
    file_matches="$(ls "${DOC_DIR}" 2>/dev/null | grep -i "${keyword}" | head -5)"
    
    # 搜索文件内容匹配 (在 .md 文件内容中 grep)
    local content_matches=""
    content_matches="$(grep -l "${keyword}" "${DOC_DIR}"/*.md 2>/dev/null | head -5)"
    
    echo "=== 找到的相关命令 ===" >&2
    local found=0
    
    # 合并结果并去重
    local all_matches="${file_matches}"
    for f in ${content_matches}; do
        local base="$(basename "$f")"
        if ! echo "${all_matches}" | grep -q "${base}"; then
            all_matches="${all_matches} ${base}"
        fi
    done
    
    # 打印每个匹配命令的格式
    for f in ${all_matches}; do
        if [ -f "${DOC_DIR}/${f}" ]; then
            # 将文件名 display_xxx_yyy.md 转换为命令 display xxx yyy
            local cmd
            cmd="$(echo "$f" | sed 's/^display_//' | sed 's/_/ /g' | sed 's/\.md$//')"
            echo "  - display ${cmd}" >&2
            # 尝试提取命令格式行
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

# ============================================================================
# 核心函数: 智能匹配查询类型
# ============================================================================
# 参数: $1 - 用户输入文本 (已转小写)
# 返回: 查询类型:参数的字符串 (如 "board:0" 或 "raw:display emu")
#
# 匹配优先级 (从高到低):
#   1. 单板/板卡 → display board
#   2. 风扇/EMU → display emu
#   3. 电源/功率 → display power
#   4. 版本 → display version
#   5. ONT 光功率 → display ont optical-info
#   6. ONT 信息 → display ont info
#   7. 告警 → display alarm
#   8. 接口/端口 → display interface
#   9. MAC/ARP → display mac-address / arp
#   10. CPU/内存/温度 → display health / memory / temperature
#   11. 配置 → display current-configuration
#   12. 端口状态/ONT状态 → display port state / ont state
#   13. 业务端口/VLAN/流量/日志 → display service-port / vlan / port traffic / log
#   14. DHCP → display dhcp server lease
#   15. 无法匹配 → 返回空 (触发文档搜索)
#
# 参数提取策略:
#   - 提取端口格式 (frameid/slotid/portid)
#   - 提取槽位格式 (frameid/slotid)
#   - 提取首个数字 (ONT ID、VLAN ID 等)
# ============================================================================
determine_query() {
    local input="$1"
    local nums_str=""
    nums_str="$(extract_nums "${input}")"
    local first_num=""
    first_num="$(echo "${nums_str}" | awk '{print $1}')"
    local port=""
    port="$(parse_port_args "${input}")"
    
    # ============================================================================
    # 1. 单板/板卡/槽位查询
    # ============================================================================
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
    
    # ============================================================================
    # 2. 风扇/EMU/散热查询
    # ============================================================================
    if contains "(fan|风扇|emu|散热|cooling|风机|转速|rpm)" "${input}"; then
        echo "raw:display emu"
        return
    fi
    
    # ============================================================================
    # 3. 电源/功率/功耗查询
    # ============================================================================
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
    
    # ============================================================================
    # 4. 版本/软件查询
    # ============================================================================
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
    
    # ============================================================================
    # 5. ONT 光功率/光模块查询
    # ============================================================================
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
    
    # ============================================================================
    # 6. ONT/ONU/光猫 信息查询
    # ============================================================================
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
    
    # ============================================================================
    # 7. 告警/警告/故障查询
    # ============================================================================
    if contains "(alarm|告警|警告|alert|fault|故障)" "${input}"; then
        if contains "(history|历史|以往|曾经)" "${input}"; then
            echo "alarm:history"
        else
            echo "alarm:active"
        fi
        return
    fi
    
    # ============================================================================
    # 8. 接口/端口/链路状态查询
    # ============================================================================
    if contains "(interface|接口|port|端口|if|状态|up|down|链路)" "${input}"; then
        if [ -n "${port}" ]; then
            echo "raw:display interface ${port}"
        else
            echo "interface"
        fi
        return
    fi
    
    # ============================================================================
    # 9. MAC 地址表查询
    # ============================================================================
    if contains "(mac-address|mac|mac地址|mac表|二层地址)" "${input}"; then
        echo "mac-address"
        return
    fi
    
    # ============================================================================
    # 10. ARP 表查询
    # ============================================================================
    if contains "(arp|arp表|三层地址|ip地址表)" "${input}"; then
        echo "arp"
        return
    fi
    
    # ============================================================================
    # 11. CPU 负载查询
    # ============================================================================
    if contains "(cpu|处理器|负载|load)" "${input}"; then
        echo "cpu"
        return
    fi
    
    # ============================================================================
    # 12. 内存查询
    # ============================================================================
    if contains "(memory|mem|内存|ram|存储)" "${input}"; then
        echo "memory"
        return
    fi
    
    # ============================================================================
    # 13. 温度查询
    # ============================================================================
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
    
    # ============================================================================
    # 14. 当前配置查询
    # ============================================================================
    if contains "(config|配置|current-config|当前配置|running-config)" "${input}"; then
        echo "config"
        return
    fi
    
    # ============================================================================
    # 15. PON 端口状态查询
    # ============================================================================
    if contains "(port-state|portstate|端口状态|链路状态)" "${input}"; then
        if [ -n "${port}" ]; then
            echo "port-state:${port}"
        else
            echo "port-state:${DEFAULT_PORT}"
        fi
        return
    fi
    
    # ============================================================================
    # 16. ONT 状态查询
    # ============================================================================
    if contains "(ont-state|ontstate|ont状态|终端状态|光猫状态)" "${input}"; then
        if [ -n "${port}" ]; then
            echo "ont-state:${port} ${DEFAULT_ONTID}"
        else
            echo "ont-state:${DEFAULT_PORT} ${DEFAULT_ONTID}"
        fi
        return
    fi
    
    # ============================================================================
    # 17. 业务端口查询
    # ============================================================================
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
    
    # ============================================================================
    # 18. VLAN 查询
    # ============================================================================
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
    
    # ============================================================================
    # 19. 流量统计查询
    # ============================================================================
    if contains "(traffic|流量|统计|字节|包|packet|byte|counter|perf)" "${input}"; then
        if [ -n "${port}" ]; then
            echo "traffic:${port}"
        else
            echo "traffic:${DEFAULT_PORT}"
        fi
        return
    fi
    
    # ============================================================================
    # 20. 日志查询
    # ============================================================================
    if contains "(log|日志|记录|audit|操作记录|security|安全日志)" "${input}"; then
        if contains "(security|安全|登录|认证|鉴权)" "${input}"; then
            echo "log:security"
        else
            echo "log:operation"
        fi
        return
    fi
    
    # ============================================================================
    # 21. 设备健康/综合状态查询
    # ============================================================================
    if contains "(health|健康|状态|summary|overview|概览|综合|总览|整体)" "${input}"; then
        echo "health"
        return
    fi
    
    # ============================================================================
    # 22. DHCP 租约查询
    # ============================================================================
    if contains "(dhcp|ip分配|地址分配|租约|lease)" "${input}"; then
        echo "raw:display dhcp server lease"
        return
    fi
    
    # ============================================================================
    # 无法匹配 - 返回空，触发文档搜索
    # ============================================================================
    echo ""
}

# ============================================================================
# 主逻辑执行
# ============================================================================

# 处理 search 特殊模式: 直接调用文档搜索并退出
if [ "${mode}" = "search" ]; then
    search_in_docs "${USER_INPUT}"
    exit 0
fi

# 调用智能匹配函数，获取查询类型和参数
RESULT="$(determine_query "${INPUT_LOWER}")"

# ============================================================================
# 如果无法匹配: 尝试文档搜索 + 模糊推断
# ============================================================================
# 策略:
#   1. 打印 "无法直接匹配" 提示
#   2. 调用 search_in_docs 搜索相关命令
#   3. 根据关键词进行模糊推断，给出建议命令
#   4. 如果仍无法推断，提示用户使用 search 模式
# ============================================================================
if [ -z "${RESULT}" ]; then
    echo "[智能匹配] 无法直接匹配，尝试文档搜索..." >&2
    search_in_docs "${INPUT_LOWER}"
    
    # 模糊推断常见场景
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

# 解析 RESULT 为查询类型和参数
QUERY_TYPE="${RESULT%%:*}"
QUERY_ARGS="${RESULT#*:}"

# ============================================================================
# 执行查询
# ============================================================================
# 根据 mode 选择执行方式:
#   - random: 调用 olt_query.sh random <查询类型> → 使用随机参数
#   - default: 调用 olt_query.sh default <查询类型> → 使用默认参数
#   - normal:
#     * QUERY_TYPE=raw → 直接执行原始命令 (跳过 olt_query.sh 的类型分发)
#     * 其他 → 调用 olt_query.sh <查询类型> <参数>
# ============================================================================
echo "[智能匹配] 查询类型: ${QUERY_TYPE}, 参数: ${QUERY_ARGS}" >&2

if [ "${mode}" = "random" ]; then
    echo "[模式] 使用随机参数" >&2
    "${QUERY_SCRIPT}" "random" "${QUERY_TYPE}"
elif [ "${mode}" = "default" ]; then
    echo "[模式] 使用默认参数" >&2
    "${QUERY_SCRIPT}" "default" "${QUERY_TYPE}"
else
    if [ "${QUERY_TYPE}" = "raw" ]; then
        # raw 模式: 直接通过 olt_connect.sh 执行完整命令
        CMD="${QUERY_ARGS}"
        echo "[执行] ${CMD}" >&2
        "${CONNECT_SCRIPT}" "${OLT_IP}" "${OLT_USER}" "${OLT_PASS}" "${CMD}"
    else
        # 标准模式: 通过 olt_query.sh 执行类型 + 参数
        "${QUERY_SCRIPT}" "${QUERY_TYPE}" ${QUERY_ARGS}
    fi
fi
