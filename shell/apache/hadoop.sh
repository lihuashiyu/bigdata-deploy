#!/usr/bin/env bash


SERVICE_DIR=$(cd "$(dirname "$0")/../" || exit; pwd)
SERVICE_NAME=Hadoop
JUDGE_NAME=org.apache.hadoop

NAME_NODE_PORT=9870
DATA_NODE_PORT=9864
SECOND_NAME_NODE_PORT=50090
NODE_MANAGER_PORT=8042
RESOURCE_MANAGER_PORT=8088
JOB_HISTORY_PORT=19888

NAME_NODE=org.apache.hadoop.hdfs.server.namenode.NameNode
DATA_NODE=org.apache.hadoop.hdfs.server.datanode.DataNode
SECOND_NAME_NODE=org.apache.hadoop.hdfs.server.namenode.SecondaryNameNode
NODE_MANAGER=org.apache.hadoop.yarn.server.nodemanager.NodeManager
RESOURCE_MANAGER=org.apache.hadoop.yarn.server.resourcemanager.ResourceManager
JOB_HISTORY_SERVER=org.apache.hadoop.mapreduce.v2.hs.JobHistoryServer

RUNNING=1
STOP=0


# 服务状态检测
function service_status()
{
    # 1. 统计正在运行程序的 pid 的个数
    pid_list=$(ps -aux | grep -i "${JUDGE_NAME}" | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}')
    
    # 2. 程序 NameNode 的 pid
    name_pid=$(ps -aux | grep -i ${NAME_NODE} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
    
    # 3. 程序 DataNode 的 pid
    data_pid=$(ps -aux | grep -i ${DATA_NODE} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
    
    # 4. 程序 SecondaryNameNode 的 pid
    second_pid=$(ps -aux | grep -i ${SECOND_NAME_NODE} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
    
    # 5. 程序 NodeManager 的 pid
    node_pid=$(ps -aux | grep -i ${NODE_MANAGER} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
    
    # 6. 程序 ResourceManager 的 pid
    resource_pid=$(ps -aux | grep -i ${RESOURCE_MANAGER} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
    
    # 7. 程序 JobHistoryServer 的 pid
    history_pid=$(ps -aux | grep -i ${JOB_HISTORY_SERVER} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
    
    # 8. pid 不存在，则程序停止运行，否则判断程序每个进程是否在运行
    if [ ! "${pid_list}" ]; then
        echo "${STOP}"
    else
        # 5. 判断程序每个进程是否存在，若都存在则断定程序正在运行中
        if [ "${name_pid}" -ne 1 ]; then
            echo "    程序（NameNode）出现错误 ...... "
        elif [ "${data_pid}" -ne 1 ]; then
            echo "    程序（DataNode）出现错误 ...... "
        elif [ "${second_pid}" -ne 1 ]; then
            echo "    程序（SecondaryNameNode）出现错误 ...... "
        elif [ "${resource_pid}" -ne 1 ]; then
            echo "    程序（ResourceManager）出现错误 ...... "
        elif [ "${node_pid}" -ne 1 ]; then
            echo "    程序（NodeManager）出现错误 ...... "
        elif [ "${history_pid}" -ne 1 ]; then
            echo "    程序（JobHistoryServer）出现错误 ...... "
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
            "${SERVICE_DIR}/sbin/start-all.sh" > /dev/null 2>&1
            sleep 11
            
            # 1.3 判断程序 NameNode 启动是否成功
            name_pid=$(ps -aux | grep -i ${NAME_NODE} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${name_pid}" -ne 1 ]; then
                echo "    程序 NameNode 启动失败 ...... "
            fi
            
            # 1.4 判断程序 DataNode 启动是否成功
            data_pid=$(ps -aux | grep -i ${DATA_NODE} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${data_pid}" -ne 1 ]; then
                echo "    程序 DataNode 启动失败 ...... "
            fi
            
            # 1.5 判断程序 SecondaryNameNode 启动是否成功
            second_pid=$(ps -aux | grep -i ${SECOND_NAME_NODE} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${second_pid}" -ne 1 ]; then
                echo "    程序 DataNode 启动失败 ...... "
            fi
            
            # 1.6 判断程序 NodeManager 启动是否成功
            node_pid=$(ps -aux | grep -i ${NODE_MANAGER} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${node_pid}" -ne 1 ]; then
                echo "    程序 NodeManager 启动失败 ...... "
            fi
            
            # 1.7 判断程序 ResourceManager 启动是否成功
            resource_pid=$(ps -aux | grep -i ${RESOURCE_MANAGER} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${resource_pid}" -ne 1 ]; then
                echo "    程序 ResourceManager 启动失败 ...... "
            fi
            
            "${SERVICE_DIR}/sbin/mr-jobhistory-daemon.sh" start historyserver > /dev/null 2>&1
            sleep 3
            
            # 1.8 判断程序 JobHistoryServer 启动是否成功
            history_pid=$(ps -aux | grep -i ${JOB_HISTORY_SERVER} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${history_pid}" -ne 1 ]; then
                echo "    程序 JobHistoryServer 启动失败 ...... "
            fi
            
            # 1.9 判断所有程序启动是否成功
            pid_count=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
            if [ "${pid_count}" -ge 6 ]; then
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
        elif [ "${pid_count}" -eq 6 ]; then
            # 2.2 杀死进程，关闭程序
            "${SERVICE_DIR}/sbin/mr-jobhistory-daemon.sh" stop historyserver > /dev/null 2>&1
            sleep 1
            echo "    程序 ${SERVICE_NAME} 正在停止中 ...... "
            "${SERVICE_DIR}/sbin/stop-all.sh" > /dev/null 2>&1
            sleep 5
            
            # 2.3 若还未关闭，则强制杀死进程，关闭程序
            pid_count=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | wc -l)
            if [ "${pid_count}" -ge 1 ]; then
                # temp=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | xargs kill -9)
                echo "    "
            fi
            
            echo "    程序 ${SERVICE_NAME} 已经停止成功 ......"            
        else
            echo "    程序 ${SERVICE_NAME} 运行出现问题 ......"
        fi
    ;;
    
    #  3. 状态查询
    status)
        # 3.1 查看正在运行程序的 pid
        pid_count=$(ps -aux | grep -i ${JUDGE_NAME} | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}' | wc -l)
        #  3.2 判断 ES 运行状态
        if [ "${pid_count}" -eq 0 ]; then
            echo "    程序 ${SERVICE_NAME} 已经停止 ...... "
        elif [ "${pid_count}" -eq 6 ]; then
            echo "    程序 ${SERVICE_NAME} 正在运行中 ...... "
        else
            echo "    程序 ${SERVICE_NAME} 运行出现问题 ...... "
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

