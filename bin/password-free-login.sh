#!/usr/bin/env bash

# ==================================================================================================
#    FileName      ：  password-free-login.sh
#    CreateTime    ：  2023-07-20 19:05
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  实现节点间免密登录
# ==================================================================================================

SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="password-free-login-$(date +%F).log"                                 # 程序操作日志文件
USER=$(whoami)                                                                 # 当前使用的用户


# 读取配置文件，获取配置参数
function read_param()
{
    # 1. 定义局部变量
    local line string param_list=()

    # 2. 读取配置文件
    while read -r line; do
        # 3. 去除 行首 和 行尾 的 空格 和 制表符
        string=$(echo "${line}" | sed -e 's/^[ \t]*//g' | sed -e 's/[ \t]*$//g')

        # 4. 判断是否为注释文字，是否为空行
        if [[ ! ${string} =~ ^# ]] && [ "" != "${string}" ]; then
            # 5. 去除末尾的注释，获取键值对参数，再去除首尾空格，为防止列表中空格影响将空格转为 #
            param=$(echo "${string}" | awk -F '#' '{print $1}' | awk '{gsub(/^\s+|\s+$/, ""); print}' | tr ' |\t' '#')

            # 6. 将参数添加到参数列表
            param_list[${#param_list[@]}]="${param}"
        fi
    done < "$1"

    # 将参数列表进行返回
    echo "${param_list[@]}"
}

# 获取参数（$1：参数键值，$2：待替换的字符，$3：需要替换的字符，$4：后缀字符）
function get_param()
{
    # 定义局部变量
    local param_list value

    # 获取参数，并进行遍历
    param_list=$(read_param "${ROOT_DIR}/conf/${CONFIG_FILE}")
    for param in ${param_list}; do
        # 判断参数是否符合以 键 开始，并对键值对进行 切割 和 替换
        if [[ ${param} =~ ^$1 ]]; then
            value=$(echo "${param//#/ }" | awk -F '=' '{print $2}' | awk '{gsub(/^\s+|\s+$/, ""); print}')
        fi
    done

    # 返回结果
    echo "${value}"
}

# 读取配置文件，获取配置参数
function get_host_list()
{
    # 1. 定义局部变量
    local line params host host_list=()

    # 2. 读取配置文件，获取 server.hosts
    params=$(get_param "server.hosts" | tr ',' ' ')

    # 3. 切分 ip 和 host，只取 ip，并将 ip 封装保存
    for param in ${params}; do
        host=$(echo "${param}" | awk -F ':' '{print $1}' | awk '{gsub(/^\s+|\s+$/, ""); print}')
        host_list[${#host_list[@]}]="${host}"
    done

    # 4. 将参数列表进行返回
    echo "${host_list[@]}"
}


# 创建秘钥（$1：远程主机名，$2：远程主机用户名，$3：远程主机用户密码）
function create_keygen()
{
    expect -c \
    " 
        spawn ssh $2@$1 \"ssh-keygen -t rsa -P '' -f ${HOME}/.ssh/id_rsa\"
        set timeout 30
        expect
        {
            *(yes/no)*       { send -- yes\r;  exp_continue; }
            *password:*      { send -- $3\r;   exp_continue; }
            \"*Overwrite*\"  { send -- y\r;    exp_continue; } 
            eof              { exit 0; }
        }
    "
}


# 复制秘钥 ID（$1：远程主机名，$2：远程主机用户名，$3：远程主机用户密码，$4：本主机名，$5：本机用户名，$6：本机用户密码）
function ssh_copy_id()
{
    expect -c \
    "
        set timeout -1;
        spawn ssh $2@$1 \"ssh-copy-id $5@$4\"              
        expect 
        {
            *(yes/no)*  { send -- yes\r; exp_continue; }
            *password:* { send -- $3\r;  exp_continue; }  
            eof         { exit 0; }
        }
    "
}


# 复制公钥（$1：远程主机名，$2：远程主机用户名，$3：远程主机用户密码）
function scp_copy_pub()
{
    expect -c \
    "
        set timeout -1;
        spawn scp $2@$1:${HOME}/.ssh/id_rsa.pub ${HOME}/.ssh/id_rsa.pub.$1                               
        expect 
        {
            *password:* { send -- $3\r;  exp_continue; }  
            eof         { exit 0; }
        }
    "  
}


# 复制公钥（$1：远程主机名，$2：远程主机用户名，$3：远程主机用户密码）
function scp_copy_keys()
{
    expect -c \
    "
        set timeout -1;
        spawn scp ${HOME}/.ssh/authorized_keys $2@$1:${HOME}/.ssh/                              
        expect 
        {
            *password:* { send -- $3\r;  exp_continue; }  
            eof         { exit 0; }
        }
    "  
}


# 分发合成后的公钥（$1：用户名，$2：主机名，$3：用户密码，$4：使用的主机）
function sync_keygen()
{
    local password host
    
    password=$(get_param "server.password")
    
    for host in ${HOST_LIST}
    do
        create_keygen "${host}" "${USER}" "${password}"
        ssh_copy_id   "${host}" "${USER}" "${password}" "${host}" "${USER}"
        scp_copy_pub  "${host}" "${USER}" "${password}"
        cat "${HOME}"/.ssh/id_rsa.pub*  >>  "${HOME}"/.ssh/authorized_keys
        scp_copy_keys  "${host}" "${USER}" "${password}"
    done
}


printf "\n================================================================================\n"
mkdir -p "${ROOT_DIR}/logs" # 创建日志目录

# 判断脚本是否传入参数，未传入会使用自定义参数
if [ "$#" -eq 0 ]; then
    HOST_LIST=$(get_host_list)
else
    HOST_LIST="$*"
fi

sync_keygen
printf "================================================================================\n\n"
exit 0
