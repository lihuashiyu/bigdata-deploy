#!/usr/bin/env bash


SERVICE_DIR=$(cd -P "$(dirname "$0")/../" || exit; pwd -P)
SERVICE_NAME=Redis
JUDGE_NAME=redis-server

CONFIG_FILE=conf/redis.conf
HOST=127.0.0.1
SERVICE_PORT=6379
CLIENT=redis-cli


printf "\n=========================================================================\n"
#  匹配输入参数
case "$1" in
    #  1. 运行程序
    start)
        # 1.1 统计正在运行程序的 pid 的个数
        redis_pid=$(ps -aux | grep ${JUDGE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}')
                
        #  1.2 若 pid 个数为 0，则运行程序，否则打印程序正在运行
        if [ ! "${redis_pid}" ]; then
            echo "    程序（${SERVICE_NAME}）正在加载 ......"
            nohup "${SERVICE_DIR}/bin/${JUDGE_NAME}" "${SERVICE_DIR}/${CONFIG_FILE}" > /dev/null 2>&1 &
            sleep 2
            
            # 1.3 判断程序启动是否成功
            count=$(ps -aux | grep ${JUDGE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
            if [ "${count}" -ge 1 ]; then
                echo "    程序（${SERVICE_NAME}）启动成功 ...... "
            else
                echo "    程序（${SERVICE_NAME}）启动失败 ...... "
            fi
        else
            echo "    程序（${SERVICE_NAME}）正在运行 ...... "
        fi
    ;;

    #  2. 停止：redis-cli -h 127.0.0.1 -p 6379 shutdown
    stop)
        # 2.1 统计正在运行程序的 pid 的个数
        pid_count=$(ps -aux | grep ${JUDGE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
        
        #  2.2 若 pid 个数大有等于 2，则停止程序，否则打印程序正在运行
        if [ "${pid_count}" -eq 0 ]; then
            echo "    程序（${SERVICE_NAME}）已经停止运行 ...... "         
        else
            echo "    程序（${SERVICE_NAME}）停止中 ...... "
            "${SERVICE_DIR}/bin/${CLIENT}" -h ${HOST} -p ${SERVICE_PORT} shutdown > /dev/null
            sleep 2
            
            # 2.3 判断程序启动是否成功
            count=$(ps -aux | grep ${JUDGE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
            if [ "${count}" -gt 0 ]; then
                temp=$(ps -aux | grep ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | xargs kill -9)
            fi
            
            echo "    程序（${SERVICE_NAME}）停止成功 ...... "
        fi
    ;;

    #  3. 状态查询
    status)
        # 2.1 统计正在运行程序的 pid 的个数
        pid_count=$(ps -aux | grep ${JUDGE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
        if [ "${pid_count}" -eq 0 ]; then
            echo "    程序（${SERVICE_NAME}）已经停止运行 ...... "
        else
            echo "    程序（${SERVICE_NAME}）正在运行 ...... "
        fi
    ;;

    #  4. 重启程序
    restart)
        "$0" stop
        sleep 1
        "$0" start
    ;;
    
    #  5. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：              "
        echo "        +-----------------------------------+ "
        echo "        |  start | stop | restart | status  | "
        echo "        +-----------------------------------+ "
        echo "        |        start    ：  启动服务       | "
        echo "        |        stop     ：  关闭服务       | "
        echo "        |        restart  ：  重启服务       | "
        echo "        |        status   ：  查看状态       | "
        echo "        +-----------------------------------+ "
    ;;
esac
printf "=========================================================================\n\n"

