#!/usr/bin/env bash


SERVICE_DIR=$(cd "$(dirname "$0")"/../ || exit; pwd)
SERVICE_NAME=kibana
SERVICE_PORT=5601
JUDGE_NAME=/node/bin/node


printf "\n=========================================================================\n"
#  匹配输入参数
case "$1" in
    #  1. 运行程序
    start)
        # 1.1 查找程序的 pid
        pid=$(ps -aux | grep ${JUDGE_NAME} | grep -iv "$0" | grep -v grep | awk '{print $2}' | wc -l)
        
        #  1.2 若 pid 不存在，则运行程序，否则打印程序运行状态
        if [ "${pid}" -le 0 ]; then
            echo "    程序（${SERVICE_NAME}）正在加载中 ......"
            nohup "${SERVICE_DIR}/bin/${SERVICE_NAME}" > /dev/null 2>&1 &
            sleep 15
            
            # 1.3 判断程序启动是否成功
            pid_new=$(ps -aux | grep ${JUDGE_NAME} | grep -iv "$0" | grep -v grep | awk '{print $2}' | wc -l)
            if [ "${pid_new}" -ge 1 ]; then
                echo "    程序（${SERVICE_NAME}）已经成功启动 ...... "
            else
                echo "    程序（${SERVICE_NAME}）启动失败 ...... "
            fi
        else
            echo "    程序（${SERVICE_NAME}）已经在运行中 ...... "
        fi
    ;;
    
    #  2. 停止
    stop)
        # 2.1 根据程序的 pid 查询程序运行状态
        pid=$(ps -aux | grep ${JUDGE_NAME} | grep -iv "$0" | grep -v grep | awk '{print $2}' | wc -l)
        if [ "${pid}" -le 0 ]; then
            echo "    程序（${SERVICE_NAME}）的进程不存在，程序已经停止 ...... "
        else
            echo "    程序（${SERVICE_NAME}）正在停止中 ...... "
            # 2.2 杀死进程，关闭程序
            temp=$(ps -aux | grep ${JUDGE_NAME} | grep -iv "$0" | grep -v grep | awk '{print $2}' | xargs kill -term)
            sleep 5
            pid_count=$(ps -aux | grep ${JUDGE_NAME} | grep -iv "$0" | grep -v grep | wc -l)
            if [ "${pid_count}" -ge 1 ]; then
                temp=$(ps -aux | grep ${JUDGE_NAME} | grep -iv "$0" | grep -v grep | awk '{print $2}' | xargs kill -9)
            fi
            echo "    程序（${SERVICE_NAME}）已经停止成功 ......"
        fi
    ;;
    
    #  3. 状态查询
    status)
        # 3.1 查看正在运行程序的 pid
        pid=$(ps -aux | grep ${JUDGE_NAME} | grep -iv "$0" | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
        #  3.2 判断 ES 运行状态
        if [ "${pid}" -ge 2 ]; then
            echo "    程序（${SERVICE_NAME}）正在运行中 ...... "
        else
            echo "    程序（${SERVICE_NAME}）已经停止 ...... "
        fi
    ;;
    
    #  4. 重启程序
    restart)
        "$0" stop
        "$0" start
    ;;
    
    #  5. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：              "
        echo "        +-----------------------------------+ "
        echo "        |  start | stop | restart | status  | "
        echo "        +-----------------------------------+ "
        echo "        |       start    ：  启动服务       | "
        echo "        |       stop     ：  关闭服务       | "
        echo "        |       restart  ：  重启服务       | "
        echo "        |       status   ：  服务状态       | "
        echo "        +-----------------------------------+ "
    ;;
esac
printf "=========================================================================\n\n"

