#!/usr/bin/env bash
# shellcheck disable=SC2120

# =========================================================================================
#    FileName      ：  flink.sh
#    CreateTime    ：  2023-02-27 17:09:54
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  flink.sh 被用于 ==> Flink 集群的启停和状态检查脚本
# =========================================================================================
    
    
FLINK_HOME=$(cd "$(dirname "$0")/../" || exit; pwd)                            # Spark 安装目录
SERVICE_NAME=org.apache.flink
ALIAS_NAME=Flink                                                               # 服务别名

CLUSTER_ENTRY_PORT=8082
RPC_PORT=6123
REST_PORT=8083
WEB_PORT=9082

CLUSTER_ENTRY=org.apache.flink.runtime.entrypoint.StandaloneSessionClusterEntrypoint
TASK_MANAGER=org.apache.flink.runtime.taskexecutor.TaskManagerRunner


printf "\n================================================================================\n"
#  匹配输入参数
case "$1" in
    #  1. 运行程序
    start)
        # 1.1 查找程序的 pid
        pid_list=$(ps -aux | grep -i ${SERVICE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}')
        
        #  1.2 若 pid 不存在，则运行程序，否则打印程序运行状态
        if [ ! "${pid_list}" ]; then
            echo "    程序 ${ALIAS_NAME} 正在加载中 ......"
            "${FLINK_HOME}/bin/start-cluster.sh" > /dev/null 2>&1
            sleep 2
            
            # 1.3 判断程序 StandaloneSessionClusterEntrypoint 启动是否成功
            cluster_pid=$(ps -aux | grep -i ${CLUSTER_ENTRY} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}')
            if [ ! "${cluster_pid}" ]; then
                echo "    程序 StandaloneSessionClusterEntrypoint 启动失败 ...... "
            fi
            
            # 1.4 判断程序 TaskManagerRunner 启动是否成功
            task_pid=$(ps -aux | grep -i ${TASK_MANAGER} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}')
            if [ ! "${task_pid}" ]; then
                echo "    程序 TaskManagerRunner 启动失败 ...... "
            fi
            
            # 1.5 判断所有程序启动是否成功
            pid_count=$(ps -aux | grep -i ${SERVICE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${pid_count}" -ge 2 ]; then
                echo "    程序 ${ALIAS_NAME} 启动成功 ...... "
            else
                echo "    程序 ${ALIAS_NAME} 启动失败 ...... "
            fi
            
        else
            echo "    程序 ${ALIAS_NAME} 正在运行当中 ...... "
        fi
    ;;
    
    
    #  2. 停止
    stop)
        # 2.1 根据程序的 pid 查询程序运行状态
        pid_count=$(ps -aux | grep -i ${SERVICE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
        if [ "${pid_count}" -eq 0 ]; then
            echo "    ${ALIAS_NAME} 的进程不存在，程序没有运行 ...... "
        elif [ "${pid_count}" -eq 2 ]; then
            # 2.2 杀死进程，关闭程序
            "${FLINK_HOME}/bin/stop-cluster.sh" > /dev/null 2>&1
            sleep 1

            # 2.3 若还未关闭，则强制杀死进程，关闭程序
            pid_count=$(ps -aux | grep -i ${SERVICE_NAME} | grep -v grep | awk '{print $2}' | wc -l)
            if [ "${pid_count}" -ge 1 ]; then
                temp=$(ps -aux | grep -i ${SERVICE_NAME} | grep -v grep | awk '{print $2}' | xargs kill -9)
            fi
            
            echo "    程序 ${ALIAS_NAME} 已经停止成功 ......"            
        else
            echo "    程序 ${ALIAS_NAME} 运行出现问题 ......"
        fi
    ;;
    
    
    #  3. 状态查询
    status)
        # 3.1 查看正在运行程序的 pid
        pid_count=$(ps -aux | grep -i ${SERVICE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
        #  3.2 判断 ES 运行状态
        if [ "${pid_count}" -eq 0 ]; then
            echo "    程序 ${ALIAS_NAME} 已经停止 ...... "
        elif [ "${pid_count}" -eq 2 ]; then
            echo "    程序 ${ALIAS_NAME} 正在运行中 ...... "
        else
            echo "    程序 ${ALIAS_NAME} 运行出现问题 ...... "
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
        echo "        |        start    ：  启动服务      | "
        echo "        |        stop     ：  关闭服务      | "
        echo "        |        restart  ：  重启服务      | "
        echo "        |        status   ：  查看状态      | "
        echo "        +-----------------------------------+ "
    ;;
esac
printf "================================================================================\n\n"

