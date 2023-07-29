#!/usr/bin/env bash

# ==================================================================================================
#    FileName      ：  gcc.sh
#    CreateTime    ：  2023-07-29 21:34
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  编译安装 gcc、git、htop、
# ==================================================================================================

SERVICE_DIR=$(cd "$(dirname "$0")" || exit; pwd)                               # Shell 脚本目录
RESOURCE_DIR="${HOME}/compile"                                                 # 
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="compile-install-$(date +%F).log"                                     # 程序操作日志文件
USER=$(whoami)                                                                 # 当前登录使用的用户


# 读取配置文件，获取配置参数
function read_param()
{
    # 1. 定义局部变量
    local line string param_list=()
    
    # 2. 读取配置文件
    while read -r line
    do
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
    for param in ${param_list}
    do
        # 判断参数是否符合以 键 开始，并对键值对进行 切割 和 替换 
        if [[ ${param} =~ ^$1 ]]; then
            value=$(echo "${param//#/ }" | awk -F '=' '{print $2}' | awk '{gsub(/^\s+|\s+$/, ""); print}' | tr "\'$2\'" "\'$3\'")
        fi
    done
    
    # 返回结果
    echo "${value}$4"
}


# 安装并配置 gcc
function gcc_install()
{
    echo "    ************************ 开始安装 gcc ************************    "
    
}


# 安装并配置 git
function gcc_install()
{
    echo "    ************************ 开始安装 git ************************    "
    
}

# 安装并配置 htop
function gcc_install()
{
    echo "    *********************** 开始安装 htop ************************    "
    
}


printf "\n================================================================================\n"
mkdir -p "${ROOT_DIR}/logs"                                                    # 创建日志目录

# 匹配输入参数
case "$1" in
    # 1. 安装 gcc 
    gcc | -c)
        gcc_install
    ;;
    
    # 2. 安装 git
    git | -g)
        git_install
    ;;
    
    # 3. 安装 htop 
    htop | -h)
        htop_install
    ;;
    
    # 11. 安装必要的软件包
    all | -a)
        gcc_install
        git_install
        htop_install
    ;;
    
    # 10. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：             "
        echo "        +----------+------------------+ "
        echo "        |  参  数  |      描  述      | "
        echo "        +----------+------------------+ "
        echo "        |    -c    |   安装 gcc       | "
        echo "        |    -g    |   安装 git       | "
        echo "        |    -h    |   安装 htop      | "
        echo "        |    -a    |   安装以上所有   | "
        echo "        +----------+------------------+ "
    ;;
esac
printf "================================================================================\n\n"
exit 0
