#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  2-components-install
#    CreateTime    ：  2023-07-06 23:03:45
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  安装数据库相关软件：Mysql、Redis
# =========================================================================================


SERVICE_DIR=$(cd "$(dirname "$0")" || exit; pwd)                               # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 组件安装根目录
CONFIG_FILE="database.conf"                                                    # 配置文件名称
LOG_FILE="components-install-$(date +%F).log"                                  # 程序操作日志文件
export param_list=()                                                           # 初始化参数列表


# 读取配置文件，获取配置参数
function read_param()
{
    # 1. 定义局部变量
    local line string
    
    # 2. 读取配置文件
    while read -r line
    do
        # 3. 去除 行首 和 行尾 的 空格 和 制表符
        string=$(echo "${line}" | sed -e 's/^[ \t]*//g' | sed -e 's/[ \t]*$//g')
        
        # 4. 判断是否为注释文字，是否为空行
        if [[ ! ${string} =~ ^# ]] && [ "" != "${string}" ]; then
            # 5. 去除末尾的注释，获取键值对参数
            param=$(echo "${string}" | awk -F '#' '{print $1}' | awk '{gsub(/^\s+|\s+$/, ""); print}')
            
            # 6. 将参数添加到参数列表
            param_list[${#param_list[@]}]="${param}"
        fi
    done < "${ROOT_DIR}/conf/${CONFIG_FILE}"
}


# 获取参数（$1：参数键值，$2：待替换的字符，$3：需要替换的字符，$4：后缀字符）
function get_param()
{
    # 定义局部变量
    local value=""
    for param in "${param_list[@]}"
    do
        if [[ ${param} =~ ^$1 ]]; then
            value=$(echo "${param}" | awk -F '=' '{print $2}' | tr "\'$2\'" "\'$3\'")
        fi
    done
    
    echo "${value}$4"
}


printf "\n================================================================================\n"
read_param                                                                     # 读取配置文件，获取参数
mkdir -p "${ROOT_DIR}/logs"                                                    # 创建日志目录

# 匹配输入参数
case "$1" in
    # 1. 配置网卡
    mysql)
        network_init
    ;;

    # 2. 设置主机名与 hosts 映射
    redis)
        host_init
    ;;
    
    # 3. 关闭防火墙 和 SELinux
    stop)
        stop_protect
    ;;
    
    # 4. 安装必要的软件包
    all)
        network_init
        host_init
        stop_protect
        unlock_limit
        kernel_optimize
        add_user
        dnf_mirror
        install_rpm
    ;;
    
    # 10. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：                       "
        echo "        +-------------------+--------------+ "
        echo "        |       参 数       |    描  述    | "
        echo "        +-------------------+--------------+ "
        echo "        |  network_init     |   配置网卡   | "
        echo "        |  host_init        |   主机映射   | "
        echo "        |  stop_protectt    |   关闭保护   | "
        echo "        |  unlock_limit     |   解除限制   | "
        echo "        |  kernel_optimize  |   优化内核   | "
        echo "        |  add_user         |   添加用户   | "
        echo "        |  dnf_mirror       |   替换镜像   | "
        echo "        |  install_rpm      |   安装软件   | "
        echo "        |  all              |   执行全部   | "
        echo "        +-------------------+--------------+ "
    ;;
esac
printf "================================================================================\n\n"
exit 0
