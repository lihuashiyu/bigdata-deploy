#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  hbase.sh
#    CreateTime    ：  2023-03-19 23:58:19
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  hbase.sh 被用于 ==> HBase 集群的启停和状态检查脚本
# =========================================================================================
    
HBASE_HOME=$(cd -P "$(dirname "$(readlink -e "$0")")/../" || exit; pwd -P)     # HBase 安装目录
ALIAS_NAME=HBase                                                               # 服务别名

HBASE_MASTER_PORT=60010                                                        # HMaster 端口号
REGION_SERVER_PORT=16030                                                       # HRegion 端口号

HBASE_MASTER=org.apache.hadoop.hbase.master.HMaster                            # HMaster 进程名称
REGION_SERVER=org.apache.hadoop.hbase.regionserver.HRegionServer               # HRegion 进程名称
          
LOG_FILE=hbase-$(date +%F).log                                                 # 程序操作日志文件
MASTER_LIST=(${master_list})                                                           # master 主机主机名
REGION_LIST=(${region_list})                                          # region 集群主机名
USER=$(whoami)                                                                 # 获取当前登录用户
RUNNING=1                                                                      # 服务运行状态码
STOP=0                                                                         # 服务停止状态码


# 登录其它节点执行命令（$1：节点主机名，$2：执行命令）
# shellcheck disable=SC2029
function xssh()
{
    local result
    result=$(ssh "${USER}@$1" "source ~/.bashrc; source /etc/profile; $2")
    
    echo "${result}"
}
    
    
# 服务状态检测
function service_status()
{
    # 1. 初始化局域参数
    local result_list=() pid_list=() host_name master_pid region_pid run_pid_count
    
    # 2. 遍历 HMaster 的所有的主机，查看 jvm 进程
    for host_name in "${MASTER_LIST[@]}"
    do
        # 2.1 程序 HMaster pid 的数量
        master_pid=$(xssh "${host_name}" "ps -aux | grep -i '${USER}' | grep -viE 'grep|$0' | grep -ci '${HBASE_MASTER}'")
        
        # 2.2 判断进程是否存在
        if [ "${master_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（Master）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
    done
    
    # 3. 遍历 Region 的所有的主机，查看 jvm 进程
    for host_name in "${REGION_LIST[@]}"
    do
        # 3.1 程序 Region 的 pid 的数量
        region_pid=$(xssh "${host_name}" "ps -aux | grep -i '${USER}' | grep -viE 'grep|$0' | grep -ci '${REGION_SERVER}'")
        
        # 3.2 判断进程是否存在
        if [ "${region_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（Worker）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
    done
    
    # 4. 判断是否所有的进程都正常
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
        
        # 3.1 启动 HBase 集群
        "${HBASE_HOME}/bin/start-hbase.sh"  >> "${HBASE_HOME}/logs/${LOG_FILE}" 2>&1
        
        echo "    程序（${ALIAS_NAME}）启动验证中 ......"
        sleep 3
        
        # 3.2 判断程序每个进程启动状态
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
        
        # 3.2 关闭 HBase 集群
        "${HBASE_HOME}/bin/stop-hbase.sh"  >> "${HBASE_HOME}/logs/${LOG_FILE}" 2>&1
        
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
        echo "    脚本可传入一个参数，如下所示：            "
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
