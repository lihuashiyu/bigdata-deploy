#!/usr/bin/env bash

# ==================================================================================================
#    FileName      ：  ping-tool.sh
#    CreateTime    ：  2025-07-15 13:00
#    Author        ：  Issac_Al
#    Email         ：  issacal@qq.com
#    IDE           ：  IntelliJ IDEA 2020.3.4
#    Description   ：  Bash
# ==================================================================================================

    
SERVICE_DIR=$(dirname "$(readlink -e "$0")")               # Shell 脚本目录
COUNT=100                                                  # ping 测试次数
FILE_PATH="${SERVICE_DIR}/host.txt"                        # 待测试的文件路径
HOST_LIST=()                                               # 主机列表


# 读取文件中所有的主机
function read_hosts()
{
    local host                                             # 定义局部变量
    
    if [ ! -f "${FILE_PATH}" ]; then
        return
    fi
    
    # 读取主机文件
    while read -r line
    do
        host=$(echo "${line}" | sed -e 's|\r||g' | sed -e 's|\n||g' | sed -e 's|^[ \t]*||g' | sed -e 's|[ \t]*$||g')
        
        if [ -n "${host}" ]; then
            HOST_LIST+=("${host}")
        fi
    done < "${FILE_PATH}"
}


# 判断系统的类型（$1：主机地址）
# bashsupport disable=BP2002
function execute_ping()
{
    # 定义局部变量
    local os_type LINUX="linux" BSD="bsd" DARWIN="darwin" SUN="sun" WIN="msys" OTHER="other"
    
    os_type=$(uname -s | tr "[:upper:]" "[:lower:]")       # 获取操作系统类型    
    case ${os_type} in
        *${LINUX}*)
            ping_linux "$1"
        ;;
        
        *${BSD}*)
            echo "${BSD}"
        ;;
        
        *${DARWIN}*)
            echo "${DARWIN}"
        ;;
        
        *${SUN}*)
            echo "${SUN}"
        ;;
        
        *${WIN}* | *mingw64*)
            ping_windows "$1"
        ;;
        
        *)
            echo "${OTHER}"
    esac
}


# linux 系统屏测试（$1：主机地址）
function ping_linux()
{   
    # 定义局部变量
    local ping_temp ping_trip max min avg success_count loss_count loss_radio       
    
    ping_temp=$(ping -c "${COUNT}" "$1")                   # 测试 ping 结果
    
    success_count=$(echo "${ping_temp}" | grep -i "ttl" | grep -ic "icmp_seq")
    loss_count=$(( COUNT - success_count ))                # 计算丢包率 
    loss_radio=$( echo "scale=0;   $loss_count / ${COUNT} * 100"  | bc )
    
    ping_trip=$(echo "${ping_temp}" | grep -i "min/avg/max/mdev" | awk -F " = " ' { print $2 } ' | awk '{ print $1 }')
    min=$(echo "${ping_trip}" | awk -F "/" '{ print $1 }' | awk -F "." '{ print $1 }')
    max=$(echo "${ping_trip}" | awk -F "/" '{ print $2 }' | awk -F "." '{ print $1 }')
    avg=$(echo "${ping_trip}" | awk -F "/" '{ print $3 }' | awk -F "." '{ print $1 }')
        
    echo -e "\t ${min} \t ${max} \t ${avg} \t ${loss_radio}% \t ${1} \t"
}


# windows 系统屏测试（$1：主机地址）
function ping_windows()
{   
    local ping_temp ping_trip max min avg loss_radio       # 定义局部变量
        
    ping_temp=$(ping -n "${COUNT}" "$1")                   # 测试 ping 结果
    
    loss_radio=$(echo "${ping_temp}" | grep -i 'packets' | awk -F "%" '{ print $1 }' | awk -F "(" '{ print $2 } ')
    
    ping_trip=$(echo "${ping_temp}" | grep -iE '平均|average')    
    min=$(echo  "${ping_trip}" | awk  -F  ", " '{ print $1 }' | awk -F " = " '{ print $2 }' | awk -F "ms" '{ print $1 }')
    max=$(echo  "${ping_trip}" | awk  -F  ", " '{ print $2 }' | awk -F " = " '{ print $2 }' | awk -F "ms" '{ print $1 }')
    avg=$(echo  "${ping_trip}" | awk  -F  ", " '{ print $3 }' | awk -F " = " '{ print $2 }' | awk -F "ms" '{ print $1 }')
    
    echo -e "\t ${min} \t ${max} \t ${avg} \t ${loss_radio}% \t ${1} \t"
}


printf "\n================================================================================\n"                
read_hosts                                                 # 读取文件

echo -e "\t min \t max \t avg \t lost \t host \t"         # 输出表头
for host in "${HOST_LIST[@]}"                              # 循环测试所有主机
do
    execute_ping "${host}"           
done

printf "================================================================================\n\n"
exit 0
