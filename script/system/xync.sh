#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  xync.sh
#    CreateTime    ：  2023-02-24 02:27
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  xync.sh 被用于 ==> 集群之间进行文件同步
# =========================================================================================


HOST_LIST=(${server_hosts})               # 集群主机
TARGET_PATH=$(pwd -P)/                                     # 目标路径
USER=$(whoami)                                             # 获取当前登录用户
ENABLE_LOGGING=true                                        # 是否开启日志记录

# 1. 判断输入的参数个数，以及是文件夹还是文件
if [ "$#" -gt 1 ]; then
    echo "    脚本只可以收传入一个参数，为文件或文件夹路径 ......"
    exit
elif [ "$#" -lt 1 ]; then
    echo "    没有输入参数，将同步当前文件夹中所有的文件夹和文件 ......   "
elif [ -d "$1" ]; then 
    TARGET_PATH=$(cd -P "$1" || exit; pwd -P)/
    echo "    文件夹：${TARGET_PATH} "
elif [ -f "$1" ]; then
    TARGET_PATH=$(cd -P "$(dirname "$1")" || exit; pwd -P)/$(basename "$1")
    echo "    文件：${TARGET_PATH} "
else
    echo "    输入的路径（$1）不存在 ......   "
    exit
fi
    
# 2. 遍历循环读取主机 ${HOST_LIST[@]}
for host_name in "${HOST_LIST[@]}"
do
    start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)
    printf "\n================================== 向主机（%s）同步数据 ==================================\n" "${host_name}"
    
    # 3. 执行同步
    # rsync -rvl --delete  "${TARGET_PATH}"  "${USER}@${host_name}:${TARGET_PATH}"
    if ${ENABLE_LOGGING}; then
        rsync -zav --delete  "${TARGET_PATH}"  "${USER}@${host_name}:${TARGET_PATH}"
    else
        rsync -zav --delete  "${TARGET_PATH}"  "${USER}@${host_name}:${TARGET_PATH}" > /dev/null 2>&1
    fi
    
    end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)
    echo ""
    echo "    向主机（%s）同步数据共消耗：$(( end - start ))s ...... "
done
    
printf "\n======================================== 数据同步结束 ========================================\n\n"
exit 0
