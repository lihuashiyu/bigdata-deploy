#!/usr/bin/env bash


SERVICE_DIR=$(cd "$(dirname "$0")/../" || exit; pwd)
SERVICE_NAME=Spark
JUDGE_NAME=org.apache.spark.deploy

MASTER_PORT=7077
MASTER_UI_PORT=8080
WORKER_PORT=8081
WORKER_RPC_PORT=34003
HISTORY_SERVER_PORT=HistoryServer

MASTER_NODE=org.apache.spark.deploy.master.Master
WORKER_NODE=org.apache.spark.deploy.worker.Worker
HISTORY_SERVER=org.apache.spark.deploy.history.HistoryServer


printf "\n=========================================================================\n"
#  匹配输入参数
case "$1" in
    #  1. 运行程序
    start)
        # 1.1 查找程序的 pid
        pid_list=$(ps -aux | grep -i "${JUDGE_NAME}" | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}')
        
        #  1.2 若 pid 不存在，则运行程序，否则打印程序运行状态
        if [ ! "${pid_list}" ]; then
            echo "    程序（${SERVICE_NAME}）正在加载中 ......"
            "${SERVICE_DIR}/sbin/start-all.sh" > /dev/null 2>&1
            sleep 1
            "${SERVICE_DIR}/sbin/start-history-server.sh" > /dev/null 2>&1
            sleep 1
            
            # 1.3 判断程序 Master 启动是否成功
            master_pid=$(ps -aux | grep -i ${MASTER_NODE} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${master_pid}" -ne 1 ]; then
                echo "    程序 SparkMaster 启动失败 ...... "
            fi
            
            # 1.4 判断程序 Worker 启动是否成功
            worker_pid=$(ps -aux | grep -i ${WORKER_NODE} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${worker_pid}" -ne 1 ]; then
                echo "    程序 SparkWorker 启动失败 ...... "
            fi
            
            # 1.5 判断程序 HistoryServer 启动是否成功
            history_pid=$(ps -aux | grep -i ${HISTORY_SERVER} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${history_pid}" -ne 1 ]; then
                echo "    程序 HistoryServer 启动失败 ...... "
            fi
            
            # 1.6 判断所有程序启动是否成功
            pid_count=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${pid_count}" -ge 3 ]; then
                echo "    程序（${SERVICE_NAME}）启动成功 ...... "
            else
                echo "    程序（${SERVICE_NAME}）启动失败 ...... "
            fi
            
        else
            echo "    程序（${SERVICE_NAME}）正在运行当中 ...... "
        fi
    ;;
    
    #  2. 停止
    stop)
        # 2.1 根据程序的 pid 查询程序运行状态
        pid_count=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
        if [ "${pid_count}" -eq 0 ]; then
            echo "    程序（${SERVICE_NAME}）的进程不存在，程序没有运行 ...... "
        elif [ "${pid_count}" -eq 3 ]; then
            # 2.2 杀死进程，关闭程序
            "${SERVICE_DIR}/sbin/stop-history-server.sh" > /dev/null 2>&1
            sleep 1
            echo "    程序（${SERVICE_NAME}）正在停止中 ...... "
            "${SERVICE_DIR}/sbin/stop-all.sh" > /dev/null 2>&1
            sleep 4

            # 2.3 若还未关闭，则强制杀死进程，关闭程序
            pid_count=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | wc -l)
            if [ "${pid_count}" -ge 1 ]; then
                temp=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | xargs kill -9)
            fi
            
            echo "    程序（${SERVICE_NAME}）已经停止成功 ......"            
        else
            echo "    程序（${SERVICE_NAME}）运行出现问题 ......"
        fi
    ;;
    
    #  3. 状态查询
    status)
        # 3.1 查看正在运行程序的 pid
        pid_count=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
        #  3.2 判断 ES 运行状态
        if [ "${pid_count}" -eq 0 ]; then
            echo "    程序（${SERVICE_NAME}） 已经停止 ...... "
        elif [ "${pid_count}" -eq 3 ]; then
            echo "    程序（${SERVICE_NAME}）正在运行中 ...... "
        else
            echo "    程序（${SERVICE_NAME}）运行出现问题 ...... "
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

