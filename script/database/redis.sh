#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  redis.sh
#    CreateTime    ：  2023-08-14 22:56:44
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  redis.sh 被用于 ==> Redis 的启停和状态检查脚本
# =========================================================================================
    

SERVICE_DIR=$(cd -P "$(dirname "$(readlink -e "$0")")/../" || exit; pwd -P)    # Redis 安装目录
ALIAS_NAME="Redis"                                                             # 服务别名
SERVICE_NAME="redis-server"                                                    # 服务名称
CONFIG_FILE="redis.conf"                                                       # 配置文件名称
LOG_FILE=redis-$(date +%F).log                                                 # 操作日志文件

HOST="127.0.0.1"                                                               # 安装的主机 IP
SERVICE_PORT="6379"                                                            # 服务占用的端口号
CLIENT="redis-cli"                                                             # 客户端名称

USER=$(whoami)                                                                 # 获取当前登录用户
RUNNING=1                                                                      # 服务运行状态码
STOP=0                                                                         # 服务停止状态码


# 判断服务运行状态
function service_status()
{
    # 1. 定义局域变量
    local status 
    
    # 2. 匹配服务的 pid
    status=$(ps -aux | grep -i "${USER}" | grep -i "${SERVICE_NAME}" | grep -viE "$0|grep")
    
    # 3. 判断是否在运行
    if [ -n "${status}" ]; then
        echo "${RUNNING}"
    else
        echo "${STOP}"
    fi    
}


# 启动服务
function service_start()
{
    # 1. 定义局域变量
    local status 

    # 2. 获取服务的运行状态
    status=$(service_status)
            
    # 3. 若服务处于停止状态，则运行程序，否则打印程序正在运行
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）正在加载中 ......"
        "${SERVICE_DIR}/bin/${SERVICE_NAME}" "${SERVICE_DIR}/conf/${CONFIG_FILE}" >> "${SERVICE_DIR}/logs/${LOG_FILE}" 2>&1
        
        sleep 2
        echo "    程序（${ALIAS_NAME}）启动验证中 ......"
        sleep 1
        
        # 4. 判断程序启动是否成功
        status=$(service_status)
        if [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）启动成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）启动失败 ...... "
        fi
    else
        echo "    程序（${ALIAS_NAME}）正在运行中 ...... "
    fi
}


# 停止服务
service_stop() 
{
    # 1. 定义局域变量
    local status 

    # 2. 获取服务的运行状态
    status=$(service_status)
            
    # 3. 若服务处于运行状态，则停止程序，否则打印程序已经停止
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）已经停止运行 ...... "         
    else
        echo "    程序（${ALIAS_NAME}）正在停止中 ...... "
        "${SERVICE_DIR}/bin/${CLIENT}" -h ${HOST} -p ${SERVICE_PORT} shutdown >> "${SERVICE_DIR}/logs/${LOG_FILE}" 2>&1
        
        sleep 2
        echo "    程序（${ALIAS_NAME}）停止验证中 ......" 
        sleep 1        
        
        # 4. 判断程序启动是否成功
        status=$(service_status)
        if [ "${status}" == "${RUNNING}" ]; then
            ps -aux | grep -i "${USER}" | grep -i "${SERVICE_NAME}" | grep -viE "$0|grep" | awk '{print $2}' | xargs kill -15
        fi
        
        echo "    程序（${ALIAS_NAME}）停止成功 ...... "
    fi    
    
}


printf "\n================================================================================\n"
#  匹配输入参数
case "$1" in
    #  1. 运行程序
    start)
        service_start
    ;;

    #  2. 停止：redis-cli -h 127.0.0.1 -p 6379 shutdown
    stop)
        service_stop
    ;;

    #  3. 状态查询
    status)
        # 2.1 统计正在运行程序的 pid 的个数
        status=$(service_status)
        if [ "${status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）已经停止运行 ...... "
        else
            echo "    程序（${ALIAS_NAME}）正在运行中 ...... "
        fi
    ;;

    #  4. 重启程序
    restart)
        service_stop
        sleep 1
        service_start
    ;;
    
    #  5. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：              "
        echo "        +---------+--------+-----------+----------+ "
        echo "        |  start  |  stop  |  restart  |  status  | "
        echo "        +---------+--------+-----------+----------+ "
        echo "        |        start     ：     启动服务        | "
        echo "        |        stop      ：     关闭服务        | "
        echo "        |        restart   ：     重启服务        | "
        echo "        |        status    ：     查看状态        | "
        echo "        +------------------+----------------------+ "
    ;;
esac
printf "================================================================================\n\n"
exit 0

