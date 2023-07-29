#!/usr/bin/env bash
    
    
SERVICE_DIR=$(cd -P "$(dirname "$0")" || exit; pwd -P)     # 服务位置
SCHEDULER_NAME=scheduler                                   # 服务名称
WEB_NAME=webserver                                         # 服务名称
SERVICE_NAME=Air-Flow                                      # 服务别名
SERVICE_PORT=19950                                         # 服务端口号

LOG_FILE=mock-db-$(date +%F).log                           # 程序运行日志文件
RUN_STATUS=1                                               # 服务运行状态
STOP_STATUS=0                                              # 服务停止状态
FAIL_STATUS="-1"                                           # 服务运行错误


# 服务状态检测
function service_status()
{
    pid_count=$(ps -aux | grep -vi "$0" | egrep -i "${SCHEDULER_NAME}|${WEB_NAME}" | grep -vi grep | wc -l)
    port_count=$(netstat -tunlp | grep "${SERVICE_PORT}")
    if [ "${port_count}" -ge 2 ] && [ "${pid_count}" -ge 1 ]; then
        echo "${RUN_STATUS}"
    elif [ "${pid_count}" -eq 0 ] && [ "${port_count}" -eq 0 ]; then
        echo "${STOP_STATUS}"
    else
        echo "${FAIL_STATUS}"
    fi
}

# 服务启动
function service_start()
{
    # 1. 统计正在运行程序的 pid 的个数
    status=$(service_status)

    # 2. 若程序运行状态为停止，则运行程序，否则打印程序正在运行
    if [ "${status}" == "${STOP_STATUS}" ]; then
        echo "    程序（${ALIAS_NAME}）正在加载中 ......"
        
        # 3. 加载程序，启动程序
        airflow webserver -p  "${SERVICE_PORT}" -D  >> "${SERVICE_DIR}/${LOG_FILE}" 2>&1
        airflow scheduler -D                        >> "${SERVICE_DIR}/${LOG_FILE}" 2>&1
        
        sleep 1
        echo "    程序（${ALIAS_NAME}）程序启动验证中 ...... "
        sleep 2
        
        # 检查服务状态
        stat=$(service_status)
        if [ "${stat}" == "${RUN_STATUS}" ]; then
            echo "    程序（${ALIAS_NAME}）启动成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）启动失败 ...... "
        fi
    elif [ "${status}" == "${RUN_STATUS}" ]; then
        echo "    程序（${ALIAS_NAME}）正在运行中 ...... "
    else
        echo "    程序（${ALIAS_NAME}）运行错误 ...... "
    fi
}


# 服务停止
function service_stop()
{
    # 1. 统计正在运行程序的 pid 的个数
    status=$(service_status)

    # 2 判断程序状态
    if [ "${status}" == "${STOP_STATUS}" ]; then
        echo "    程序（${ALIAS_NAME}）的进程不存在，程序没有运行 ...... "
    
    # 3. 杀死进程，关闭程序
    elif [ "${status}" == "${RUN_STATUS}" ]; then
        echo "    程序（${ALIAS_NAME}）正在停止 ......"
        temp=$(ps -aux | grep -i "$0" | egrep -i "${SCHEDULER_NAME}|${WEB_NAME}" | grep -v grep | awk '{print $2}' | xargs kill -15)
        
        sleep 2
        echo "    程序（${ALIAS_NAME}）停止验证中 ......"
        sleep 3

        # 4. 若还未关闭，则强制杀死进程，关闭程序
        stat=$(service_status)
        
        if [ "${pid_count}" == "${RUN_STATUS}" ]; then
            temp=$(ps -aux | grep -i "$0" | egrep -i "${SCHEDULER_NAME}|${WEB_NAME}" | grep -v grep | awk '{print $2}' | xargs kill -9)
        fi

        echo "    程序（${ALIAS_NAME}）已经停止成功 ......"
    else
        echo "    程序（${ALIAS_NAME}）的进程数量错误，程序运行错误 ...... "
    fi
}

    
#  匹配输入参数
case "$1" in
    # 1. 运行程序：running
    start)
        service_start
    ;;

    # 2. 停止
    stop)
        service_stop
    ;;

    # 3. 状态查询
    status)
        # 3.1 查看正在运行程序的 pid
        status=$(service_status)

        # 3.2 判断运行状态
        if [ "${status}" == "${STOP_STATUS}" ]; then
            echo "    程序（${ALIAS_NAME}）已经停止 ...... "
        elif [ "${status}" == "${RUN_STATUS}" ]; then
            echo "    程序（${ALIAS_NAME}）正在运行中 ...... "
        fi
    ;;

    # 4. 重启程序
    restart)
        service_stop
        sleep 1
        service_start
    ;;

    # 5. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：            "
        echo "        +---------------------------------+ "
        echo "        | start | stop | restart | status | "
        echo "        +---------------------------------+ "
        echo "        |      start    ：  启动服务      |  "
        echo "        |      stop     ：  关闭服务      |  "
        echo "        |      restart  ：  重启服务      |  "
        echo "        |      status   ：  查看状态      |  "
        echo "        +---------------------------------+ "
    ;;
esac
printf "=========================================================================\n\n"
