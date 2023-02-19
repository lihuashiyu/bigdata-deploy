#!/usr/bin/env bash
    
    
SERVICE_DIR=$(cd "$(dirname "$0")/../" || exit; pwd)       # 程序路径
SERVICE_NAME=nginx                                         # 程序名称
ALIAS_NAME=Nginx                                           # 程序别名
CONFIG_FILE=conf/nginx.conf                                # 配置文件
LOG_FILE=mock-db-$(date +%F).log                           # 程序运行日志文件
    
NGINX_PORT=47722                                           # Nginx 前端静态资源监控端口
SERVICE_PORT2=10800                                        # 后台服务
MASTER="nginx: master process"
WORKER="nginx: worker process"
RUNNING=1
STOP=0
    
    
# 服务状态检测
function service_status()
{
    # 1. 统计正在运行程序的 pid 的个数
    nginx_pid=$(ps -aux | grep ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}')
    
    # 2. 程序 Master 的 pid
    master_pid=$(ps -aux | grep -i "${MASTER}" | grep -vi "$0" | grep -v grep | awk '{print $2}')
    
    # 3. 程序 Worker 的 pid
    worker_pid=$(ps -aux | grep -i "${WORKER}" | grep -vi "$0" | grep -v grep | awk '{print $2}')
    
    # 4. pid 不存在，则程序停止运行，否则判断程序每个进程是否在运行
    if [ ! "${nginx_pid}" ]; then
        echo "${STOP}"
    else
        # 5. 判断程序每个进程是否存在，若都存在则断定程序正在运行中
        if [ ! "${master_pid}" ]; then
            echo "    程序（Master）出现错误 ...... "
        elif [ ! "${worker_pid}" ]; then
            echo "    程序（Worker）出现错误 ...... "
        else
            echo "${RUNNING}"
        fi
    fi
}
    
    
# 服务启动
function service_start()
{
    # 1. 判断程序所处的状态
    status=$(service_status)
    
    # 2. 若处于运行状态，则打印结果；若处于停止状态，则启动程序；若程序启动时，出现错误，则打印错误的进程
    if [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在运行 ...... "
    elif [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）正在加载中 ......"
        
        "${SERVICE_DIR}/bin/${SERVICE_NAME}" -c "${SERVICE_DIR}/${CONFIG_FILE}" > /dev/null 2>&1
        sleep 2
        echo "    程序（${ALIAS_NAME}）启动验证中 ......"
        sleep 1
        
        # 3. 判断程序每个进程启动状态
        status=$(service_status)
        if [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）启动成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）启动失败 ...... "
            echo "    ${status}"
        fi
    else
        echo "${status}"
    fi
}
    
    
# 服务停止
function service_stop()
{
    # 1. 判断程序所处的状态
    status=$(service_status)
    
    # 2. 若处于停止状态，则打印结果；若处于运行状态，则停止程序；若停止时，程序出现错误，则打印错误的进程
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）已经停止运行 ...... "
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在停止中 ...... "
        
        "${SERVICE_DIR}/bin/${SERVICE_NAME}" -s quit > /dev/null 2>&1
        sleep 1 
        echo "    程序（${ALIAS_NAME}）停止验证中 ...... "
        sleep 1
        
        # 3. 判断程序每个进程停止状态
        status=$(service_status)
        if [ "${status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）停止成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）停止失败 ...... "
        fi
    else
        echo "    程序（${ALIAS_NAME}）运行出错 ...... "
        echo "${status}"
    fi
}
    
    
# 服务重启
function service_restart()
{
    # 1. 判断程序所处的状态
    status=$(service_status)
    
    # 2. 若处于停止状态，则启动程序；若处于运行状态，则重启程序；若程序出现错误，则打印错误的进程
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）已经停止运行 ...... "
        service_start        
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在重启中 ...... "
        
        "${SERVICE_DIR}/bin/${SERVICE_NAME}" -s reload > /dev/null 2>&1
        sleep 2 
        echo "    程序（${ALIAS_NAME}）重启验证中 ...... "
        sleep 1
        
        # 3. 判断程序每个进程重启状态
        status=$(service_status)
        if [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）重启成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）重启失败 ...... "
            echo "${status}"
        fi
    else
        echo "    程序（${ALIAS_NAME}）运行出错 ...... "
        echo "${status}"
    fi
}
    
    
printf "\n================================================================================\n"
#  匹配输入参数
case "$1" in
    #  1. 运行程序
    start)
        service_start
    ;;
    
    # 2. 停止
    stop)
        service_stop
    ;;
    
    #  3. 状态查询
    status)
        # 3.1 判断程序所处的状态
        status=$(service_status)
        
        # 2. 根据查询结果，判断程序运行状态
        if [ "${status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）已经停止运行 ...... "        
        elif [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）正在运行中 ...... "
        else
            echo "    程序（${ALIAS_NAME}）运行出错 ...... "
            echo "${status}"
        fi
    ;;
    
    #  4. 重启程序
    restart)
        service_restart
    ;;
    
    #  5. 测试配置文件
    test)
        "${SERVICE_DIR}/bin/${SERVICE_NAME}" -t
    ;;
    
    #  6. 其它情况
    *)  
        echo "    脚本仅可传入一个参数，若传入多个参数，则仅第一个有效，参数如下所示："
        echo "        +----------------------------------------+ "
        echo "        | start | stop | restart | status | test | "
        echo "        +----------------------------------------+ "
        echo "        |        start    ：  启动服务           | "
        echo "        |        stop     ：  关闭服务           | "
        echo "        |        restart  ：  重启服务           | "
        echo "        |        status   ：  查看状态           | "
        echo "        |        test     ：  测试配置文件       | "
        echo "        +----------------------------------------+ "
    ;;
esac
printf "================================================================================\n\n"
    
