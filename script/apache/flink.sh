#!/usr/bin/env bash
# shellcheck disable=SC2120,SC2029

# =========================================================================================
#    FileName      ：  flink.sh
#    CreateTime    ：  2023-02-27 17:09:54
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  flink.sh 被用于 ==> Flink 集群的启停和状态检查脚本
# =========================================================================================
    
    
FLINK_HOME=$(cd -P "$(dirname "$(readlink -e "$0")")/../" || exit; pwd -P)     # Flink 安装目录
ALIAS_NAME=Flink                                                               # 服务别名

CLUSTER_ENTRY_PORT=8082                                                        # Master 占用端口号
RPC_PORT=6123                                                                  # Master RPC  通信端口号
REST_PORT=8083                                                                 # Master REST 通信端口号
WEB_PORT=9082                                                                  # 外部访问 Master  WebUI 端口号

CLUSTER_ENTRY=org.apache.flink.runtime.entrypoint.StandaloneSessionClusterEntrypoint     # Flink Master 进程名称
TASK_MANAGER=org.apache.flink.runtime.taskexecutor.TaskManagerRunner           # Flink TaskManager 端口号
HISTORY_SERVER=org.apache.flink.runtime.webmonitor.history.HistoryServer       # Flink 历史服务器进程名称

MASTER_LIST=(${master_list})                                                           # JobManager    主机主机名
WORKER_LIST=(${worker_list})                                          # TaskManager   主机主机名
HISTORY_LIST=(${history_list})                                                          # HistoryServer 主机主机名
FLINK_LOG_FILE="flink-$(date +%F).log"                                         # Flink   程序操作日志文件
HISTORY_LOG_FILE="history-$(date +%F).log"                                     # History 程序操作日志文件
USER=$(whoami)                                                                 # 获取当前登录用户
RUNNING=1                                                                      # 服务运行状态码
STOP=0                                                                         # 服务停止状态码


# 服务状态检测
function service_status()
{
    # 1. 定义变量
    local host_name result_list=() pid_list=() master_pid slaver_pid history_pid run_pid_count
        
    # 2. 遍历 Master 的所有的主机，查看 jvm 进程
    for host_name in "${MASTER_LIST[@]}"
    do
        # 2.1 获取程序 Master 的 pid 数量
        master_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -viE 'grep|$0' | grep -ci '${CLUSTER_ENTRY}'")
        
        # 2.2 判断该主机的 pid 是否存在
        if [ "${master_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（JobManager）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
    done
    
    # 3. 遍历 Slaver 的所有的主机，查看 jvm 进程
    for host_name in "${WORKER_LIST[@]}"
    do
        # 3.1 程序 Slaver 的 pid 数量
        slaver_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -viE 'grep|$0' | grep -ci '${TASK_MANAGER}'")
        
        # 3.2 判断该主机的 pid 是否存在
        if [ "${slaver_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（TaskManager）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
    done
    
    # 4. 遍历 History 的所有的主机，查看 jvm 进程
    for host_name in "${HISTORY_LIST[@]}"
    do
        # 4.1 程序 HistoryServer 的 pid 数量
        history_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -viE 'grep|$0' | grep -ci '${HISTORY_SERVER}'")
        
        # 4.2 判断该主机的 pid 是否存在
        if [ "${history_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（HistoryServer）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
    done
      
    # 5. 判断是否所有的进程都正常
    run_pid_count=$(echo "${pid_list[@]}"  | grep -ci "${RUNNING}")
    
    if [ "${#result_list[@]}" -eq 0 ]; then
        echo "${RUNNING}"
    elif [ "${run_pid_count}" -eq 0 ]; then
        echo "${STOP}"
    else
        echo "${result_list[@]}"
    fi
}


# 启动服务
function service_start()    
{
    # 1. 定义局部变量
    local status ps
    
    # 2. 判断程序所处的状态
    status=$(service_status)
    
    # 3.1 若程序没有运行，则运行程序，否则打印程序运行状态
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）正在加载 ......"
        
        # 3.2 启动 Flink 集群
        "${FLINK_HOME}/bin/start-cluster.sh"  >> "${FLINK_HOME}/logs/${FLINK_LOG_FILE}" 2>&1
        
        echo "    程序（${ALIAS_NAME}）启动验证中 ......"
        
        # 3.3 启动 Flink 的历史服务器
        "${FLINK_HOME}/bin/historyserver.sh" start  >> "${FLINK_HOME}/logs/${HISTORY_LOG_FILE}" 2>&1
        sleep 2
        
        # 3.4 判断所有程序启动是否成功
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
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在运行 ...... "
    else
        echo "    程序（${ALIAS_NAME}）运行出错 ...... "
        for ps in ${status}
        do
            echo "    ${ps} ...... "
        done
    fi
}


# 停止服务
function service_stop()
{
    # 1. 定义局部变量
    local status ps

    # 2. 判断程序所处的状态
    status=$(service_status)
    
    # 3.1 若程序正在运行，则停止程序，否则打印程序运行状态
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）已经停止 ...... "
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在停止 ......"
        
        # 3.2 关闭 Flink 的历史服务器
        "${FLINK_HOME}/bin/historyserver.sh" stop  >> "${FLINK_HOME}/logs/${HISTORY_LOG_FILE}" 2>&1
        
        echo "    程序（${ALIAS_NAME}）停止验证中 ......"
        
        # 3.3 关闭 Flink 集群
        "${FLINK_HOME}/bin/stop-cluster.sh"  >> "${FLINK_HOME}/logs/${FLINK_LOG_FILE}" 2>&1
        sleep 3
        
        # 3.4 判断所有程序是否关闭成功
        status=$(service_status)
        if [ "${status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）关闭成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）关闭失败 ...... "
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


printf "\n================================================================================\n"
# 1. 获取脚本执行开始时间
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 2. 匹配输入参数
case "$1" in
    # 2.1 运行程序
    start)
        service_start
    ;;
    
    # 2.2 停止程序
    stop)
        service_stop
    ;;
    
    # 2.3 状态查询
    status)
        # 2.3.1 判断程序所处的状态
        status=$(service_status)
        
        # 2.3.2 判断程序运行状态
        if [ "${status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）已经停止 ...... "
        elif [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）正在运行 ...... "
        else
            echo "    程序（${ALIAS_NAME}）运行出错 ...... "
            for ps in ${status}
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
