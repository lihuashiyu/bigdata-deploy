#!/usr/bin/env bash
# shellcheck disable=SC2029,SC1090

# ==================================================================================================
#    FileName      ：  password-free-login.sh
#    CreateTime    ：  2023-07-20 19:05
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  实现节点间免密登录：dnf install openssh-server openssh-clients expect
# ==================================================================================================

SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="password-free-login-$(date +%F).log"                                 # 程序操作日志文件
SSH_PORT="22"                                                                  # SSH 端口号
SCP_PORT="${SSH_PORT}"                                                         # SCP 端口号
USER=$(whoami)                                                                 # 当前使用的用户


# 刷新环境变量
function flush_env()
{
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    
    echo "    ************************** 刷新环境变量 **************************    "
    # 判断用户环境变量文件是否存在
    if [ -e "${HOME}/.bash_profile" ]; then
        source "${HOME}/.bash_profile"                                         # RedHat 用户环境变量文件
    elif [ -e "${HOME}/.bashrc" ]; then
        source "${HOME}/.bashrc"                                               # Debian、RedHat 用户环境变量文件
    fi
        
    source "/etc/profile"                                                      # 系统环境变量文件路径
    
    echo "    ************************** 获取公共函数 **************************    "
    # shellcheck source=./common.sh
    source "${ROOT_DIR}/bin/common.sh"                                         # 当前程序使用的公共函数
    
    export -A PARAM_LIST=()                                                    # 初始化 配置文件 参数
    read_param "${ROOT_DIR}/conf/${CONFIG_FILE}"                               # 读取配置文件，获取参数
}


# 删除秘钥生成文件夹（$1：用户名，$2：用户密码，$3：远程主机名）
function remove_key()
{
    expect -c \
    " 
        set timeout 30;
        spawn ssh -p ${SSH_PORT} $1@$3 rm -rf ${HOME}/.ssh;
        expect {
            *yes/no*     { send  --  yes\r;  exp_continue; }
            *password*   { send  --  $2\r;   exp_continue; }
            eof          { exit 0 }
        };
    "  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
}


# 创建秘钥（$1：用户名，$2：用户密码，$3：远程主机名）
function create_keygen()
{
    expect -c \
    " 
        set timeout 30;
        spawn ssh -p ${SSH_PORT} $1@$3 ssh-keygen -t rsa -P '' -f ${HOME}/.ssh/id_rsa;
        expect {
            *Overwrite*  { send  --  y\r;    exp_continue; }
            *yes/no*     { send  --  yes\r;  exp_continue; }
            *password*   { send  --  $2\r;   exp_continue; }
            eof          { exit 0 }
        };
    "  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
}


# 复制秘钥 ID（$1：用户名，$2：用户密码，$3：本主机名，$4：远程主机名）
function ssh_copy_id()
{
    expect -c \
    "
        set timeout 30;
        spawn ssh -p ${SSH_PORT} $1@$4 ssh-copy-id -f $1@$3;              
        expect {
            *yes/no*    { send  --  yes\r; exp_continue; }
            *password*  { send  --  $2\r;  exp_continue; }  
            eof         { exit 0; }
        };
    "  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
}


# 复制公钥（$1：用户名，$2：用户密码，$3：远程主机名）
function scp_copy_pub()
{
    expect -c \
    "
        set timeout 30;
        spawn scp -P -p ${SCP_PORT} $1@$3:${HOME}/.ssh/id_rsa.pub ${HOME}/.ssh/id_rsa.pub.$3; 
        expect {
            *yes/no*    { send  --  yes\r; exp_continue; }
            *password*  { send  --  $2\r;  exp_continue; }    
            eof         { exit 0; }
        };
    "  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  
}


# 发送合成公钥（$1：用户名，$2：用户密码，$3：远程主机名）
function scp_copy_keys()
{
    expect -c \
    "
        set timeout -1;
        spawn scp -P ${SCP_PORT} ${HOME}/.ssh/authorized_keys $1@$3:${HOME}/.ssh/;                              
        expect {
            *yes/no*    { send  --  yes\r; exp_continue; }
            *password* { send -- $2\r;  exp_continue; }  
            eof         { exit 0; }
        };
    "  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
}


# 合成秘钥
function sync_keygen()
{
    local password host master h test_result count=0                           # 定义局域变量
    
    password=$(get_param "server.password")                                    # 获取主机密码
    master=$(echo "${HOST_LIST[@]}" | awk '{print $1}')                        # 获取 Master 节点 
    
    echo "    ************************ 生成 SSH 秘钥对 *************************    "
    for host in ${HOST_LIST}
    do
        remove_key    "${USER}" "${password}" "${host}"                        # 删除 SSH 秘钥对
        create_keygen "${USER}" "${password}" "${host}"                        # 生成 SSH 秘钥对
    done
    
    echo "    *********************** 发送公钥到 Master ************************    "
    for host in ${HOST_LIST}
    do
        if [[ "${master}" != "${host}" ]]; then
            ssh_copy_id   "${USER}" "${password}" "${master}" "${host}"        # 将秘钥 ID 复制到 Master
            scp_copy_pub  "${USER}" "${password}" "${host}"                    # 将公钥发送到 Master
        fi
    done
     
    echo "    **************************** 合成公钥 ****************************    "
    cat "${HOME}"/.ssh/id_rsa.pub*  >>  "${HOME}/.ssh/authorized_keys"         # 合成 公钥
    
    echo "    ************************** 分发合成公钥 **************************    "
    for host in ${HOST_LIST}
    do
        if [[ "${master}" != "${host}" ]]; then
            scp_copy_keys  "${USER}" "${password}" "${host}"                   # 分发合成公钥
        fi
    done
     
    echo "    ************************** 测试免密登录 **************************    "
    for host in ${HOST_LIST}
    do
        for h in ${HOST_LIST}
        do
            ssh -p "${SSH_PORT}" "${USER}@${host}" "echo '  <== ${host} 登录 ${h} ==>  '; exit"  >> "${HOME}/.ssh/test.log"
            (( count = count + 1 ))
        done
    done
    
    test_result=$(grep -ci "登录" "${HOME}/.ssh/test.log")                       # 统计文件行数
    if [ "${test_result}" -eq "${count}" ]; then
        echo "    **************************** 配置成功 ****************************    "
    else
        echo "    **************************** 配置失败 ****************************    "
    fi
}


printf "\n================================================================================\n"
# 1. 刷新环境变量
flush_env

# 2. 判断脚本是否传入参数，未传入会使用自定义参数
if [ "$#" -eq 0 ]; then
    HOST_LIST=$(get_param "server.hosts" | awk -F ',' '{ for(i=1; i<=NF; i++) {print $i} }' | awk -F ':' '{print $2}' | sed ':label;N;s|\n| |g;t label')
else
    HOST_LIST="$*"
fi

# 3. 进行 ssh 免密配置
sync_keygen
printf "================================================================================\n\n"
exit 0
