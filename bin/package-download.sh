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
software_list=(mysql.url redis.url java.url python.url scala.url maven.url gradle.url hadoop.url spark.nohadoop.url)


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
            
            # 返回结果，停止循环
            echo "${value}$4"
            
            return
        fi
    done
}


# 下载软件包（$1：配置文件中软件包 url 的 key）
function download()
{
    # 定义局部变量
    local url file_name 
    
    url=$(get_param "$1")
    if [[ -n ${url} ]]; then
        # 创建安装包存放目录
        mkdir -p "${ROOT_DIR}/package"
        
        # 查看安装包是否存在，存在就删除
        file_name=$(echo "${url}" | sed 's/.*\/\([^\/]*\)$/\1/')
        if [[ -f "${ROOT_DIR}/package/${file_name}" ]]; then
            rm -rf "${ROOT_DIR}/package/${file_name}"
        fi
        
        echo "    ********** 开始下载：${file_name} ********** "
        # wget -P "${ROOT_DIR}/package" "${url}"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
        curl --parallel --parallel-immediate -k -L -C - -o "${ROOT_DIR}/package/${file_name}" "${url}" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    else
        echo "    ******************** ${CONFIG_FILE} 中没有 $1 的 url ******************** "
    fi
}


printf "\n================================================================================\n"
mkdir -p "${ROOT_DIR}/logs"                                                    # 创建日志目录

# 判断脚本是否传入参数，未传入会使用自定义参数
if [ "$#" -eq 0 ]; then
    for file in "${software_list[@]}"
    do
        download "${file}"
    done    
else    
    for file in "$@"
    do
        download "${file}.url"
    done
fi
printf "================================================================================\n\n"
exit 0
