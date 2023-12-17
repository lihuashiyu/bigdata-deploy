#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  package-download.sh
#    CreateTime    ：  2023-07-06 23:03:45
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  下载软件包
# =========================================================================================


SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="package-download-$(date +%F).log"                                    # 程序操作日志文件
# 定义所需要的下载的软件包地址
software_list=(java python scala maven gradle mysql redis nginx hadoop spark flink kafka zookeeper hive hbase phoenix doris)


# 刷新环境变量
function flush_env()
{    
    mkdir -p "${ROOT_DIR}/logs"  "${ROOT_DIR}/package"                         # 创建日志目录和包下载目录
    
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


printf "\n================================================================================\n" 
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)                            # 获取脚本执行开始时间
flush_env                                                                      # 刷新环境变量

# 判断脚本是否传入参数，未传入会使用自定义参数
if [ "$#" -eq 0 ]; then
    for file in "${software_list[@]}"
    do
        download "${file}.url"
    done    
else    
    for file in "$@"
    do
        download "${file}.url"
    done
fi

end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)                              # 获取脚本执行的结束时间
echo "    脚本（$(basename "$0")）执行共消耗：$(( end - start ))s ...... "

printf "================================================================================\n\n"
exit 0
