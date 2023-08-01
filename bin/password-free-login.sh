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


if [ "$#" -gt 0 ]; then
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    # shellcheck source=./common.sh
    source "${SERVICE_DIR}/common.sh" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   # 获取公共函数    
fi

printf "\n================================================================================\n"
# 判断脚本是否传入参数，未传入会使用自定义参数
if [ "$#" -eq 0 ]; then
    HOST_LIST=$(get_host_list)
else
    HOST_LIST="$*"
fi

sync_keygen
printf "================================================================================\n\n"
exit 0
