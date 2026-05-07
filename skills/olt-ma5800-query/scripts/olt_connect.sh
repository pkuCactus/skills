#!/bin/sh
# ============================================================================
# MA5800 OLT CLI 连接与命令执行脚本 (olt_connect.sh)
# ============================================================================
# 功能: 通过 sshpass SSH 登录 MA5800 OLT CLI，自动切换特权模式后执行 display 命令
# 兼容: BusyBox 1.34.1 ash / POSIX sh
#
# 用法: ./olt_connect.sh <olt_ip> <username> <password> <command> [subcommands...]
#       或: 设置环境变量 OLT_IP, OLT_USER, OLT_PASS 后不带参数执行
#
# 特权模式切换流程 (自动执行):
#   SSH 登录(用户视图) → enable(特权视图) → config(配置视图)
#   → mmi-mode enable(MMI视图, 可执行 display) → [执行命令] → return → quit
#
# 分页处理: 通过 sed 过滤移除 --- More --- 等多余提示行
# ============================================================================

set -eu

# 连接参数优先级: 环境变量 > 命令行参数 > 默认值
# 环境变量方式 (推荐): export OLT_IP=70.32.37.65; export OLT_USER=root; export OLT_PASS=xxx
OLT_IP="${OLT_IP:-${1:-70.32.37.65}}"
OLT_USER="${OLT_USER:-${2:-root}}"
OLT_PASS="${OLT_PASS:-${3:-Admin@huawei123}}"
OLT_TIMEOUT="${OLT_TIMEOUT:-30}"

# 特权模式切换开关 (环境变量可覆盖，用于调试)
OLT_ENABLE="${OLT_ENABLE:-true}"
OLT_CONFIG="${OLT_CONFIG:-true}"
OLT_MMIMODE="${OLT_MMIMODE:-true}"

# 检查必需参数 (IP/用户名/密码必须存在)
if [ -z "${OLT_IP}" ] || [ -z "${OLT_USER}" ] || [ -z "${OLT_PASS}" ]; then
    echo "用法: $0 <olt_ip> <username> <password> <command> [args...]" >&2
    echo "或设置环境变量 OLT_IP, OLT_USER, OLT_PASS" >&2
    exit 1
fi

# 从命令行参数中提取要执行的 CLI 命令
# shift 3: 跳过前3个参数 (IP, username, password)
# 剩余所有参数拼接为完整命令
shift 3 2>/dev/null || true
CMD="${*:-}"
if [ -z "${CMD}" ]; then
    echo "错误: 未提供要执行的命令" >&2
    exit 1
fi

# 检查 sshpass 是否已安装 (SSH 免密登录的必需工具)
if ! type sshpass >/dev/null 2>&1; then
    echo "错误: sshpass 未安装" >&2
    exit 1
fi

# ============================================================================
# 核心执行函数: execute_cmd
# ============================================================================
# 参数:
#   $1 - OLT IP 地址
#   $2 - SSH 用户名
#   $3 - SSH 密码
#   $4 - 要执行的 CLI 命令 (display xxx)
#   $5 - SSH 超时时间(秒), 默认30
#   $6 - 是否执行 enable, 默认true
#   $7 - 是否执行 config, 默认true
#   $8 - 是否执行 mmi-mode enable, 默认true
#
# 工作流程:
#   1. 创建临时文件写入命令序列
#   2. 按顺序写入: enable → config → mmi-mode enable → 用户命令 → return → quit
#   3. 通过 sshpass SSH 登录并输入命令序列
#   4. 输出过滤: 移除分页提示 --- More ---
#   5. 清理临时文件
# ============================================================================
execute_cmd() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    local cmd="$4"
    local timeout="${5:-30}"
    local do_enable="${6:-true}"
    local do_config="${7:-true}"
    local do_mmi="${8:-true}"

    # 用临时文件构建命令序列
    local tmpfile="/tmp/olt_cmd_$$"
    : > "${tmpfile}"
    
    if [ "${do_enable}" = "true" ]; then
        printf 'enable\n' >> "${tmpfile}"
    fi
    
    if [ "${do_config}" = "true" ]; then
        printf 'config\n' >> "${tmpfile}"
    fi
    
    if [ "${do_mmi}" = "true" ]; then
        printf 'mmi-mode enable\n' >> "${tmpfile}"
    fi
    
    printf '%s\n' "${cmd}" >> "${tmpfile}"
    
    # 退出序列: 从 mmi-mode 逐级返回 → 退出 SSH
    printf 'return\n' >> "${tmpfile}"
    printf 'quit\n' >> "${tmpfile}"
    
    # ============================================================================
    # SSH 连接与执行
    # 参数说明:
    #   -tt          : 强制分配伪终端 (必须, 用于处理 CLI 交互和分页)
    #   -o StrictHostKeyChecking=no : 首次连接不验证 host key
    #   -o UserKnownHostsFile=/dev/null : 不保存 known_hosts
    #   -o ConnectTimeout=30   : 连接超时 30 秒
    #   -o ServerAliveInterval=5 : 每 5 秒发送 keepalive
    #   -o ServerAliveCountMax=3 : 最多 3 次 keepalive 无响应则断开
    #   < tmpfile     : 通过 stdin 重定向输入命令序列
    # ============================================================================
    sshpass -p "${pass}" ssh -tt \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout="${timeout}" \
        -o ServerAliveInterval=5 \
        -o ServerAliveCountMax=3 \
        "${user}@${ip}" \
        < "${tmpfile}" \
        2>/dev/null | \
    # ============================================================================
    # 分页提示过滤 (sed 管道链)
    # MA5800 display 命令输出超过一屏时会出现 "--- More ---" 提示,
    # 这些提示行需要过滤掉, 否则会被当作正常输出
    # ============================================================================
    sed 's/--- More ---//g' | \
    sed 's/  *More *( *Press *.Q *to *break *.)//g' | \
    sed 's/--- *more *---//gi' | \
    sed 's/--More--//g'
    
    # 清理临时文件 (确保即使命令失败也会删除)
    rm -f "${tmpfile}"
}

# ============================================================================
# 主入口: 输出执行信息并调用 execute_cmd
# ============================================================================
echo "[OLT连接] ${OLT_USER}@${OLT_IP}"
echo "[前置步骤] enable → config → mmi-mode enable"
echo "[执行命令] ${CMD}"
echo "========================================"
execute_cmd "${OLT_IP}" "${OLT_USER}" "${OLT_PASS}" "${CMD}" "${OLT_TIMEOUT}" "${OLT_ENABLE}" "${OLT_CONFIG}" "${OLT_MMIMODE}"
