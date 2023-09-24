#!/usr/bin/env bash

# ==================================================================================================
#    FileName      ：  other-install.sh
#    CreateTime    ：  2023-08-25 21:21
#    Author        ：  lihua shiyu
#    Email         ：  issacal@qq.com
#    IDE           ：  lihuashiyu@github.com
#    Description   ：  安装软件：Nginx
# ==================================================================================================


SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="other-install-$(date +%F).log"                                       # 程序操作日志文件
USER=$(whoami)                                                                 # 当前登录使用的用户  


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


# 安装并初始化 Nginx
function nginx_install()
{
    echo "    ************************* 开始安装 Nginx *************************    "
    local nginx_home folder nginx_host nginx_port nginx_version result_count
     
    nginx_home=$(get_param "nginx.home")                                       # Nginx 安装路径
    file_decompress "nginx.url"                                                # 解压 Nginx 源码包
    
    echo "    **************************** 编译源码 ****************************    "
    folder=$(find "${ROOT_DIR}/package"/*  -maxdepth 0 -type d -print)         # 获取解压目录
    cd "${folder}" || exit                                                     # 进入 Nginx 源码目录
    rm -rf  "${nginx_home}"                                                    # 删除可能存在的安装目录
    
    {
        ./configure --prefix="${nginx_home}"                                   # 指定安装路径
        make                                                                   # 编译源码
        make install                                                           # 安装到指定路径
    } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    echo "    ************************** 修改配置文件 **************************    "
    mv "${nginx_home}/sbin" "${nginx_home}/bin"                                # 修改目录名称
    mkdir -p "${nginx_home}/conf" "${nginx_home}/data" "${nginx_home}/logs"    # 创建必要的目录
    cp -fpr  "${ROOT_DIR}/script/other/nginx.sh"  "${nginx_home}/bin/"         # 复制 启停脚本
    cp -fpr  "${ROOT_DIR}/conf/nginx.conf"        "${nginx_home}/conf/"        # 复制 配置文件
    
    nginx_version=$(get_version "redis.url")                                   # 获取 Nginx 版本
    append_env "nginx.home" "${nginx_version}"                                 # 添加环境变量
    
    echo "    **************************** 启动程序 ****************************    "
    "${nginx_home}/bin/nginx" -c "${nginx_home}/conf/nginx.conf"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    sleep 3
    
    nginx_host=$(hostname)
    nginx_port=$(grep -niE "^[ ]+ listen.*;" "${nginx_home}/conf/nginx.conf" | awk '{print $NF}' | awk -F ';' '{print $1}')
    curl -o "${nginx_home}/logs/test.log" "http://${nginx_host}:${nginx_port}/index.html" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    result_count=$(grep -nic "thank you" "${nginx_home}/logs/test.log")
    if [ "${result_count}" -ne 1 ]; then
        echo "    **************************** 验证失败 ****************************    "
    else
        echo "    **************************** 验证成功 ****************************    "
    fi
}


printf "\n================================================================================\n"
# 1. 获取脚本执行开始时间
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 2. 刷新变量
if [ "$#" -gt 0 ]; then
    export NGINX_HOME 
    flush_env                                                                  # 刷新环境变量    
fi

# 3. 匹配输入参数
case "$1" in
    # 3.1 安装 nginx
    nginx | -n)
        nginx_install
    ;;
    
    # 3.2 安装以上所有
    all | -a)
        nginx_install
    ;;
    
    # 3.3 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：             "
        echo "        +----------+-------------------------+ "
        echo "        |  参  数  |         描   述         | "
        echo "        +----------+-------------------------+ "
        echo "        |    -n    |  安装 nginx             | "
        echo "        |    -a    |  安装以上所有           | "
        echo "        +----------+-------------------------+ "
    ;;
esac

# 4. 获取脚本执行结束时间，并计算脚本执行时间
end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)
if [ "$#" -ge 1 ]; then
    echo "    脚本（$(basename "$0")）执行共消耗：$(( end - start ))s ...... "
fi

printf "================================================================================\n\n"
exit 0
