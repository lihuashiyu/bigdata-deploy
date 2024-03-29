#!/usr/bin/env bash
# shellcheck disable=SC2120

# =========================================================================================
#    FileName      ：  spark.sh
#    CreateTime    ：  2023-02-27 11:49:01
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  spark.sh 被用于 ==> Spark 集群的启停和状态检查脚本
# =========================================================================================
    
    
SPARK_HOME=$(cd -P "$(dirname "$(readlink -e "$0")")/../" || exit; pwd -P)     # Spark 安装目录
ALIAS_NAME=Spark                                                               # 服务别名
          
MASTER_PORT=7077                                                               # Master 端口号
MASTER_UI_PORT=8080                                                            # Master 外部访问端口号
WORKER_PORT=8081                                                               # Worker 端口号
WORKER_RPC_PORT=34003                                                          # Worker 与 Master 的 RPC 通信端口号
HISTORY_SERVER_PORT=18080                                                      # 历史服务器端口号
          
MASTER_NODE=org.apache.spark.deploy.master.Master                              # Master 进程名称
WORKER_NODE=org.apache.spark.deploy.worker.Worker                              # Worker 进程名称
HISTORY_SERVER=org.apache.spark.deploy.history.HistoryServer                   # 历史服务器 进程名称
          
LOG_FILE=spark-$(date +%F).log                                                 # 程序操作日志文件
MASTER_LIST=(${master_list})                                                           # master 主机主机名
WORKER_LIST=(${worker_list})                                          # slaver 集群主机名
USER=$(whoami)                                                                 # 获取当前登录用户
RUNNING=1                                                                      # 服务运行状态码
STOP=0                                                                         # 服务停止状态码


# 服务状态检测
# shellcheck disable=SC2029
function service_status()
{
    # 1. 初始化局域参数
    local result_list=() pid_list=() host_name master_pid worker_pid history_pid run_pid_count
    
    # 2. 遍历 master 的所有的主机，查看 jvm 进程
    for host_name in "${MASTER_LIST[@]}"; do
        # 2.1 程序 Master pid 的数量
        master_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -viE 'grep|$0' | grep -ci '${MASTER_NODE}'")
        
        # 2.2 判断进程是否存在
        if [ "${master_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（Master）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
    done
    
    # 3. 遍历 Worker 的所有的主机，查看 jvm 进程
    for host_name in "${WORKER_LIST[@]}"
    do
        # 3.1 程序 Work 的 pid 的数量
        worker_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -viE 'grep|$0' | grep -ci '${WORKER_NODE}'")
        
        # 3.2 判断进程是否存在
        if [ "${worker_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（Worker）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
    done
    
    # 4. 遍历 历史服务器 的所有的主机，查看 jvm 进程
    for host_name in "${MASTER_LIST[@]}"; do
        # 3.1 程序 JobHistoryServer 的 pid 的数量
        history_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -viE 'grep|$0' | grep -ci '${HISTORY_SERVER}'")
        
        # 4.2 判断进程是否存在
        if [ "${history_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（HistoryServer）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
    done
    
    # 5. 判断是否所有的进程都正常
    run_pid_count=$(echo "${pid_list[@]}" | grep -ci "${RUNNING}")
    
    if [ "${#result_list[@]}" -eq 0 ]; then
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
    # 1. 定义局部变量
    local status ps
        
    # 2. 判断程序所处的状态
    status=$(service_status)
    
    # 3. 若处于运行状态，则打印结果；若处于停止状态，则启动程序；若程序启动时，出现错误，则打印错误的进程
    if [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在运行 ...... "
    elif [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）正在加载中 ......"
        
        # 3.1 启动 Spark 集群
        "${SPARK_HOME}/sbin/start-all.sh"  >> "${SPARK_HOME}/logs/${LOG_FILE}" 2>&1
        
        echo "    程序（${ALIAS_NAME}）启动验证中 ......"
        
        # 3.2 启动 历史服务器 集群
        "${SPARK_HOME}/sbin/start-history-server.sh"  >> "${SPARK_HOME}/logs/${LOG_FILE}" 2>&1
        
        sleep 3
        
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
        echo "    程序（${ALIAS_NAME}）运行出错 ...... "
        for ps in ${status}
        do
            echo "    ${ps} ...... "
        done
    fi
}
    
    
# 服务停止
function service_stop()
{
    # 1. 定义局部变量
    local status ps
    
    # 2. 判断程序所处的状态
    status=$(service_status)
    
    # 3. 若处于停止状态，则打印结果；若处于运行状态，则停止程序；若停止时，程序出现错误，则打印错误的进程
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）已经停止 ...... "
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在停止中 ...... "
        
        # 3.1 关闭 历史服务器 集群
        "${SPARK_HOME}/sbin/stop-history-server.sh" >> "${SPARK_HOME}/logs/${LOG_FILE}" 2>&1
                
        # 3.2 关闭 Spark 集群
        "${SPARK_HOME}/sbin/stop-all.sh"  >> "${SPARK_HOME}/logs/${LOG_FILE}" 2>&1
        
        echo "    程序（${ALIAS_NAME}）停止验证中 ...... "
        sleep 3
        
        # 3.3 判断程序每个进程停止状态
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
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

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
        # 2.3.1 查看正在运行程序的 pid
        pid_status=$(service_status)
        
        # 2.3.2 判断 ES 运行状态
        if [ "${pid_status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）已经停止 ...... "
        elif [ "${pid_status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）正在运行中 ...... "
        else
            echo "    程序（${ALIAS_NAME}）运行出错 ...... "
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
end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 4. 计算并输出脚本执束时间
if [ "$#" -eq 1 ]  && { [ "$1" == "start" ] || [ "$1" == "stop" ] || [ "$1" == "restart" ]; }; then
    echo "    脚本（$(basename "$0")）执行共消耗：$(( end - start ))s ...... "
fi

printf "================================================================================\n\n"
exit 0

