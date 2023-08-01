#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  package-download
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
software_list=(mysql redis java python scala maven gradle hadoop spark.nohadoop)


# 下载软件包（$1：配置文件中软件包 url 的 key）
function download()
{
    # 定义局部变量
    local url file_name 
    
    url=$(get_param "$1")
    if [[ -n ${url} ]]; then
        # 查看安装包是否存在，存在就删除
        file_name=$(echo "${url}" | sed 's/.*\/\([^\/]*\)$/\1/')
        if [[ -f "${ROOT_DIR}/package/${file_name}" ]]; then
            rm -rf "${ROOT_DIR}/package/${file_name}"
        fi
        
        echo "    ********** 开始下载：${file_name} ********** "
        # wget -P "${ROOT_DIR}/package" "${url}"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
        curl --parallel --parallel-immediate -k -L -C - -o "${ROOT_DIR}/package/${file_name}" "${url}" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    else
        echo "    ********** ${CONFIG_FILE} 中没有 $1 ********** "
    fi
}


printf "\n================================================================================\n" 
mkdir -p  "${ROOT_DIR}/logs" "${ROOT_DIR}/package"                             # 创建 日志目录 和 安装包存放目录
# shellcheck source=./common.sh
source "${ROOT_DIR}/bin/common.sh" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1      # 获取公共函数    

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

printf "================================================================================\n\n"
exit 0
