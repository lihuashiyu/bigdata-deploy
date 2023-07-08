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
LOG_FILE="database-install-$(date +%F).log"                                    # 程序操作日志文件


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


# 解压缩文件到临时路径（$1：，$2：）
function file_decompress()
{
    # 定义参数
    local file_name software_home prefix
    
    file_name=$(get_param "$1" | sed 's/.*\/\([^\/]*\)$/\1/')
    
    if [ -e "${ROOT_DIR}/package/${file_name}" ]; then
        mkdir -p "${ROOT_DIR}/tmp"
        
        # software_home=$(get_param "$2")
        # 判断临时文件夹是否存在，存在就删除
        if [ -d "${ROOT_DIR}/tmp/$1" ]; then
            rm -rf "${ROOT_DIR}/tmp/$1"
        fi
        
        # 对压缩包进行解压
        if [[ "${file_name}" =~ tar.xz$ ]]; then
            tar -Jxvf "${ROOT_DIR}/package/${file_name}" -C "${ROOT_DIR}/tmp" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar.gz$ ]] || [[ "${file_name}" =~ tgz$ ]]; then
            tar -zxvf "${ROOT_DIR}/package/${file_name}" -C "${ROOT_DIR}/tmp" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar.bz2$ ]]; then
            tar -jxvf "${ROOT_DIR}/package/${file_name}" -C "${ROOT_DIR}/tmp" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar.Z$ ]]; then
            tar -Zxvf "${ROOT_DIR}/package/${file_name}" -C "${ROOT_DIR}/tmp" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar$ ]]; then
            tar -xvf "${ROOT_DIR}/package/${file_name}"  -C "${ROOT_DIR}/tmp" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ zip$ ]]; then
            unzip -d "${ROOT_DIR}/package/${file_name}"     "${ROOT_DIR}/tmp"
        elif [[ "${file_name}" =~ xz$ ]]; then
            xz -dk "${ROOT_DIR}/package/${file_name}"     > "${ROOT_DIR}/tmp/${file_name}" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ gz$ ]]; then
            gzip -dk "${ROOT_DIR}/package/${file_name}"   > "${ROOT_DIR}/tmp/"   
        elif [[ "${file_name}" =~ bz2$ ]]; then
            bzip2 -vcdk "${ROOT_DIR}/package/${file_name}" > "${ROOT_DIR}/tmp/"
        elif [[ "${file_name}" =~ Z$ ]]; then
            uncompress -rc "${ROOT_DIR}/package/${file_name}" > "${ROOT_DIR}/tmp/"
        elif [[ "${file_name}" =~ rar$ ]]; then
            unrar vx  "${ROOT_DIR}/package/${file_name}" "${ROOT_DIR}/tmp/" 
        fi
    else
        echo "    文件 ${ROOT_DIR}/package/${file_name} 不存在 "
    fi
    
    echo "    ********** 开始解压：${file_name} ********** "
}


printf "\n================================================================================\n"
read_param                                                                     # 读取配置文件，获取参数
mkdir -p "${ROOT_DIR}/logs"                                                    # 创建日志目录

# 匹配输入参数
case "$1" in
    # 1. 配置网卡
    mysql | -m)
        network_init
    ;;

    # 2. 设置主机名与 hosts 映射
    redis | -r)
        host_init
    ;;
    
    # 3. 关闭防火墙 和 SELinux
    pgsql | -p)
        stop_protect
    ;;
    
    # 4. 安装必要的软件包
    mongodb | -g)
        network_init
    ;;
    
    # 4. 安装必要的软件包
    oracle | -o)
        network_init
    ;;
    
    # 4. 安装必要的软件包
    all | -a)
        install_rpm
    ;;
    
    # 10. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：   "
        echo "        +----------+-------------+ "
        echo "        |  参  数  |    描 述    |  "
        echo "        +----------+-------------+ "
        echo "        |    -m    |   mysql     | "
        echo "        |    -r    |   redis     | "
        echo "        |    -p    |   pgsql     | "
        echo "        |    -g    |   mongodb   | "
        echo "        |    -o    |   oracle    | "
        echo "        |    -a    |   all       | "
        echo "        +----------+-------------+ "
    ;;
esac
printf "================================================================================\n\n"
exit 0
