#!/bin/sh
# MA5800 OLT CLI 连接与命令执行脚本 (含特权模式切换)
# 兼容 BusyBox 1.34.1 ash
# 用法: ./olt_connect.sh <olt_ip> <username> <password> <command> [subcommands...]
#
# 环境变量:
#   OLT_IP       - OLT管理IP (默认: 70.32.37.65)
#   OLT_USER     - SSH用户名 (默认: root)
#   OLT_PASS     - SSH密码 (默认: Admin@huawei123)
#   OLT_TIMEOUT  - SSH超时秒数 (默认: 30)
#   OLT_WIDTH    - 终端宽度 (默认: 200)
#   OLT_ENABLE   - 是否执行 enable (默认: true)
#   OLT_CONFIG   - 是否进入 config (默认: true)
#   OLT_MMIMODE  - 是否执行 mmi-mode enable (默认: true)

set -eu

# 读取环境变量或参数
OLT_IP="${OLT_IP:-${1:-70.32.37.65}}"
OLT_USER="${OLT_USER:-${2:-root}}"
OLT_PASS="${OLT_PASS:-${3:-Admin@huawei123}}"
OLT_TIMEOUT="${OLT_TIMEOUT:-30}"
OLT_WIDTH="${OLT_WIDTH:-200}"
OLT_ENABLE="${OLT_ENABLE:-true}"
OLT_CONFIG="${OLT_CONFIG:-true}"
OLT_MMIMODE="${OLT_MMIMODE:-true}"

# 检查必需参数
if [ -z "${OLT_IP}" ] || [ -z "${OLT_USER}" ] || [ -z "${OLT_PASS}" ]; then
    echo "用法: $0 <olt_ip> <username> <password> <command> [args...]" >&2
    echo "或设置环境变量 OLT_IP, OLT_USER, OLT_PASS" >&2
    exit 1
fi

# 构建命令（从第4个参数开始拼接）
shift 3 2>/dev/null || true
CMD="${*:-}"
if [ -z "${CMD}" ]; then
    echo "错误: 未提供要执行的命令" >&2
    exit 1
fi

# 检查 sshpass
if ! type sshpass >/dev/null 2>&1; then
    echo "错误: sshpass 未安装，请先安装" >&2
    exit 1
fi

# 构建 SSH 连接，支持特权模式切换
execute_cmd() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    local cmd="$4"
    local timeout="${5:-30}"
    local width="${6:-200}"
    local do_enable="${7:-true}"
    local do_config="${8:-true}"
    local do_mmi="${9:-true}"

    # 用临时文件构建命令序列（避免双引号内换行问题）
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
    
    # 通过 SSH 伪终端发送命令序列
    sshpass -p "${pass}" ssh -tt \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout="${timeout}" \
        -o ServerAliveInterval=5 \
        -o ServerAliveCountMax=3 \
        "${user}@${ip}" \
        < "${tmpfile}" \
        2>/dev/null | \
    sed 's/--- More ---//g' | \
    sed 's/  *More *( *Press *.Q *to *break *.)//g' | \
    sed 's/--- *more *---//gi' | \
    sed 's/--More--//g'
    
    rm -f "${tmpfile}"
}

# 执行并输出
echo "[OLT连接] ${OLT_USER}@${OLT_IP}"
echo "[前置步骤] enable -> config -> mmi-mode enable"
echo "[执行命令] ${CMD}"
echo "========================================"
execute_cmd "${OLT_IP}" "${OLT_USER}" "${OLT_PASS}" "${CMD}" "${OLT_TIMEOUT}" "${OLT_WIDTH}" "${OLT_ENABLE}" "${OLT_CONFIG}" "${OLT_MMIMODE}"
