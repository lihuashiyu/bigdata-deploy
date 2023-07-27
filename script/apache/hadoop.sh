#!/usr/bin/env bash
# shellcheck disable=SC2120

# =========================================================================================
#    FileName      ：  hadoop.sh
#    CreateTime    ：  2023-02-26 01:46:31
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  hadoop.sh 被用于 ==> Hadoop 集群的启停和状态检查脚本
# =========================================================================================


HADOOP_HOME=$(cd "$(dirname "$0")/../" || exit; pwd)                           # Hadoop 安装目录
ALIAS_NAME=Hadoop                                                              # 服务别名

NAME_NODE_PORT=9870                                                            # NameNode 外部访问端口号
DATA_NODE_PORT=9864                                                            # DataNode 外部访问端口号
SECOND_NAME_NODE_PORT=9860                                                     # 2NN      外部访问端口号
NODE_MANAGER_PORT=8042                                                         # NodeManager      外部访问端口号
RESOURCE_MANAGER_PORT=8088                                                     # ResourceManager  外部访问端口号
JOB_HISTORY_PORT=19888                                                         # JobHistoryServer 外部访问端口号

NAME_NODE=org.apache.hadoop.hdfs.server.namenode.NameNode                      # NameNode 进程名称
DATA_NODE=org.apache.hadoop.hdfs.server.datanode.DataNode                      # DataNode 进程名称
SECOND_NAME_NODE=org.apache.hadoop.hdfs.server.namenode.SecondaryNameNode      # 2NN      进程名称
NODE_MANAGER=org.apache.hadoop.yarn.server.nodemanager.NodeManager             # NodeManager      进程名称
RESOURCE_MANAGER=org.apache.hadoop.yarn.server.resourcemanager.ResourceManager # ResourceManager  进程名称
JOB_HISTORY_SERVER=org.apache.hadoop.mapreduce.v2.hs.JobHistoryServer          # JobHistoryServer 进程名称

LOG_FILE=hadoop-$(date +%F).log                                                # 程序操作日志文件
MASTER_LIST=(master)                                                           # master 主机主机名
SLAVER_LIST=(slaver1 slaver2 slaver3)                                          # slaver 集群主机名
USER=$(whoami)                                                                 # 获取当前登录用户
RUNNING=1                                                                      # 服务运行状态码
STOP=0                                                                         # 服务停止状态码


# 服务状态检测
function service_status()
{
    # 1. 初始返回结果
    result_list=()
    pid_list=()
    
    # 2. 遍历 master 的所有的主机，查看 jvm 进程
    for host_name in "${MASTER_LIST[@]}"
    do
        # 2.1. 程序 NameNode 的 pid
        name_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -i '${NAME_NODE}' | grep -v grep | awk '{print $2}' " | wc -l)
        if [ "${name_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（NameNode）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
        
        # 2.2. 程序 SecondaryNameNode 的 pid
        second_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -i '${SECOND_NAME_NODE}' | grep -v grep | awk '{print $2}' " | wc -l)
        if [ "${second_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（SecondaryNameNode）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
        
        # 2.3. 程序 ResourceManager 的 pid
        resource_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -i '${RESOURCE_MANAGER}' | grep -v grep | awk '{print $2}' " | wc -l)
        if [ "${resource_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（ResourceManager）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
        
        # 2.4. 程序 JobHistoryServer 的 pid
        history_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -i '${JOB_HISTORY_SERVER}' | grep -v grep | awk '{print $2}' " | wc -l)
        if [ "${history_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（JobHistoryServer）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
    done
    
    # 3. 遍历 slaver 的所有的主机，查看 jvm 进程
    for host_name in "${SLAVER_LIST[@]}"
    do
        # 3.1. 程序 DataNode 的 pid
        name_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -i '${DATA_NODE}' | grep -v grep | awk '{print $2}' " | wc -l)
        if [ "${name_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（DataNode）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
        
        # 3.2. 程序 SecondaryNameNode 的 pid
        second_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -i '${NODE_MANAGER}' | grep -v grep | awk '{print $2}' " | wc -l)
        if [ "${second_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（NodeManager）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
    done
    
    # 4. 判断是否所有的进程都正常
    run_pid_count=$(echo "${pid_list[@]}"  | grep -i "${RUNNING}" | wc -l)
    result_pid_count=$(echo "${#result_list[@]}") 
    
    if [ "${result_pid_count}" -eq 0 ]; then
        echo "${RUNNING}"
    elif [ "${run_pid_count}" -eq 0 ]; then
        echo "${STOP}"
    else
        echo "${result_list[@]}"
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
        for host_name in "${MASTER_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${HADOOP_HOME}/sbin/start-all.sh >> ${HADOOP_HOME}/logs/${LOG_FILE} 2>&1 "
        done
        
        echo "    程序（${ALIAS_NAME}）启动验证中 ......"
        sleep 13
        for host_name in "${MASTER_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${HADOOP_HOME}/sbin/mr-jobhistory-daemon.sh start historyserver >> ${HADOOP_HOME}/logs/${LOG_FILE} 2>&1 "
        done
        sleep 2
        
        # 3. 判断程序每个进程启动状态
        status=$(service_status)
        if [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）启动成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）启动失败 ...... "
            for ps in ${status}
            do
                echo "    ${ps} ...... "
            done
        fi
    else
        for ps in ${status}
        do
            echo "    ${ps} ...... "
        done
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
        
        for host_name in "${MASTER_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${HADOOP_HOME}/sbin/mr-jobhistory-daemon.sh stop historyserver >> ${HADOOP_HOME}/logs/${LOG_FILE} 2>&1 "
            sleep 2
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${HADOOP_HOME}/sbin/stop-all.sh >> ${HADOOP_HOME}/logs/${LOG_FILE} 2>&1 "
        done
        
        echo "    程序（${ALIAS_NAME}）停止验证中 ...... "
        sleep 3
        
        # 3. 判断程序每个进程停止状态
        status=$(service_status)
        if [ "${status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）停止成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）停止失败 ...... "
        fi
    else
        echo "    程序（${ALIAS_NAME}）运行出错 ...... "
        for ps in ${status}
        do
            echo "    ${ps} ...... "
        done
    fi
}
    
    
    
printf "\n================================================================================\n"
# 1. 获取脚本执行开始时间
start_time=$(date +"%Y-%m-%d %H:%M:%S")
start_timestamp=$(date -d "${start_time}" +%s)

#  2. 匹配输入参数
case "$1" in
    # 2.1 运行程序
    start)
        service_start
    ;;
    
    # 2.2 停止
    stop)
        service_stop
    ;;
    
    # 2.3 状态查询
    status)
        # 3.1 查看正在运行程序的 pid
        pid_status=$(service_status)
        
        #  3.2 判断 ES 运行状态
        if [ "${pid_status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）已经停止 ...... "
        elif [ "${pid_status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）正在运行中 ...... "
        else
            echo "    程序（${ALIAS_NAME}）运行出现问题 ...... "
            for ps in ${pid_status}
            do
                echo "    ${ps} ...... "
            done
        fi
    ;;
    
    # 2.4 重启程序
    restart)
        service_stop
        sleep 3
        service_start
    ;;
    
    # 2.5 其它情况
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

# 3. 获取脚本执行结束时间
end_time=$(date +"%Y-%m-%d %H:%M:%S")
end_timestamp=$(date -d "${end_time}" +%s)

# 4. 计算并输出脚本执束时间
time_consuming=$(expr "${end_timestamp}" - "${start_timestamp}")
if [ "$#" -eq 1 ]  && ( [ "$1" == "start" ] || [ "$1" == "stop" ] || [ "$1" == "restart" ] ); then
    echo "    脚本（$(basename $0)）执行共消耗：${time_consuming}s ...... "
fi

printf "================================================================================\n\n"
exit 0
