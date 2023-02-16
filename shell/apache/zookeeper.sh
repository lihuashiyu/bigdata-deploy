#!/usr/bin/env bash


SERVICE_DIR=$(cd "$(dirname "$0")/../" || exit; pwd)
SERVICE_NAME=Zookeeper
JUDGE_NAME=org.apache.zookeeper
SERVICE_PORT=2181
SERVER_PORT=8180


printf "\n=========================================================================\n"
#  匹配输入参数
case "$1" in
    #  1. 运行程序
    start)
        # 1.1 查找程序的 pid
        pid_list=$(ps -aux | grep -i "${JUDGE_NAME}" | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}')
        
        #  1.2 若 pid 不存在，则运行程序，否则打印程序运行状态
        if [ ! "${pid_list}" ]; then
            echo "    程序 ${SERVICE_NAME} 正在加载中 ......"
            "${SERVICE_DIR}/bin/zkServer.sh" start > /dev/null 2>&1
            sleep 5
            
            # 1.9 判断所有程序启动是否成功
            pid_count=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${pid_count}" -ge 1 ]; then
                echo "    程序 ${SERVICE_NAME} 启动成功 ...... "
            else
                echo "    程序 ${SERVICE_NAME} 启动失败 ...... "
            fi
            
        else
            echo "    程序 ${SERVICE_NAME} 正在运行当中 ...... "
        fi
    ;;
    
    #  2. 停止
    stop)
        # 2.1 根据程序的 pid 查询程序运行状态
        pid_count=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
        if [ "${pid_count}" -eq 0 ]; then
            echo "    ${SERVICE_NAME} 的进程不存在，程序没有运行 ...... "
        else
            # 2.2 关闭进程，关闭程序
            echo "    程序 ${SERVICE_NAME} 正在停止中 ...... "
            "${SERVICE_DIR}/bin/zkServer.sh" stop > /dev/null 2>&1
            sleep 3

            # 2.3 若还未关闭，则强制杀死进程，关闭程序
            pid_count=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | wc -l)
            if [ "${pid_count}" -ge 1 ]; then
                temp=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | xargs kill -9)
            fi
            
            echo "    程序 ${SERVICE_NAME} 已经停止成功 ......"
        fi
    ;;
    
    #  3. 状态查询
    status)
        # 3.1 查看正在运行程序的 pid
        pid_count=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
        #  3.2 判断 ES 运行状态
        if [ "${pid_count}" -eq 0 ]; then
            echo "    程序 ${SERVICE_NAME} 已经停止 ...... "
        else
            echo "    程序 ${SERVICE_NAME} 正在运行中 ...... "
        fi
    ;;
    
    #  4. 重启程序
    restart)
        "$0" stop
        sleep 3
        "$0" start
    ;;
    
    #  5. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：              "
        echo "        +-----------------------------------+ "
        echo "        |  start | stop | restart | status  | "
        echo "        +-----------------------------------+ "
        echo "        |        start    ：  启动服务      | "
        echo "        |        stop     ：  关闭服务      | "
        echo "        |        restart  ：  重启服务      | "
        echo "        |        status   ：  查看状态      | "
        echo "        +-----------------------------------+ "
    ;;
esac
printf "=========================================================================\n\n"

