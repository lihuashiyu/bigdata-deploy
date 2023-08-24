#!/usr/bin/env bash
# shellcheck disable=SC2029,SC2120

# =========================================================================================
#    FileName      ：  redis.sh
#    CreateTime    ：  2023-08-14 22:56:44
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  redis.sh 被用于 ==> Redis 集群的启停和状态检查脚本
# =========================================================================================
    

REDIS_HOME=$(cd -P "$(dirname "$(readlink -e "$0")")/../" || exit; pwd -P)     # Redis 安装目录
ALIAS_NAME="Redis"                                                             # 服务别名
SERVICE_NAME="redis-server"                                                    # 服务名称
CONFIG_FILE="redis.conf"                                                       # 配置文件名称

REDIS_LIST=(${redis_list})                                              # 安装的主机 IP
SERVICE_PORT="6379"                                                            # 服务占用的端口号
LOG_FILE=redis-$(date +%F).log                                                 # 操作日志文件
USER=$(whoami)                                                                 # 获取当前登录用户
RUNNING=1                                                                      # 服务运行状态码
STOP=0                                                                         # 服务停止状态码


# 判断服务运行状态
function service_status()
{
    # 1. 初始化局域参数
    local result_list=() pid_list=() host_name redis_pid run_pid_count
    
    # 2. 获取各个节点的 redis_pid 的进程状态
    for host_name in "${REDIS_LIST[@]}"
    do
        # 2.1 获取 Redis 进程的 pid 数量
        redis_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -viE '$0|grep' | grep -ci '${SERVICE_NAME}'")
        
        # 2.2 判断进程 redis_pid 是否存在
        if [ "${redis_pid}" -lt 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（Redis）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi        
    done
        
    # 3. 判断是否所有的进程都正常
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
    # 1. 定义局域变量
    local status host_name ps
    
    # 2. 获取服务的运行状态
    status=$(service_status)
            
    # 3. 若处于运行状态，则打印结果；若处于停止状态，则启动程序，并判断启动结果；若程序出现错误，则打印错误
    if [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在运行 ...... "
    elif [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）正在加载中 ......"
        
        # 3.1 启动 Redis 的相关进程
        for host_name in "${REDIS_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${REDIS_HOME}/bin/${SERVICE_NAME} ${REDIS_HOME}/conf/${CONFIG_FILE} >> ${REDIS_HOME}/logs/${LOG_FILE} 2>&1"     
        done
        
        sleep 2
        echo "    程序（${ALIAS_NAME}）启动验证中 ......"
        sleep 1
        
        # 3.2 判断程序启动是否成功
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
        echo "    程序 ${ALIAS_NAME} 运行出错 ...... "
        for ps in ${status}
        do
            echo "    ${ps} ...... "
        done        
    fi
}


# 停止服务
service_stop() 
{
    # 1. 定义局域变量
    local status host_name ps
    
    # 2. 获取服务的运行状态
    status=$(service_status)
                
    # 3. 若处于停止状态，则打印结果；若处于运行状态，则停止程序；若停止时，程序出现错误，则打印错误的进程
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）已经停止 ...... "
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在停止中 ...... "
        
        # 3.1 停止 Redis 的相关进程
        for host_name in "${REDIS_LIST[@]}"
        do
            "${REDIS_HOME}/bin/redis-cli" -h "${host_name}" -p "${SERVICE_PORT}" shutdown >> "${REDIS_HOME}/logs/${LOG_FILE}" 2>&1     
        done
        
        sleep 2
        echo "    程序（${ALIAS_NAME}）停止验证中 ......" 
        sleep 1        
        
        # 3.2 判断程序停止是否成功
        for host_name in "${REDIS_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -i '${SERVICE_NAME}' | grep -viE '$0|grep' | awk '{print $2}' | xargs kill -9 >> ${REDIS_HOME}/logs/${LOG_FILE} 2>&1"     
        done
        
        echo "    程序（${ALIAS_NAME}）停止成功 ...... "
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

    # 2.2 停止：redis-cli -h 127.0.0.1 -p 6379 shutdown
    stop)
        service_stop
    ;;

    # 2.3 状态查询
    status)
        # 2.3.1 查看正在运行程序的 pid
        status=$(service_status)
        
        # 2.3.2 判断 ES 运行状态
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
        sleep 1
        service_start
    ;;
    
    # 2.5 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：              "
        echo "        +---------+--------+-----------+----------+ "
        echo "        |  start  |  stop  |  restart  |  status  | "
        echo "        +---------+--------+-----------+----------+ "
        echo "        |        start     ：     启动服务        | "
        echo "        |        stop      ：     关闭服务        | "
        echo "        |        restart   ：     重启服务        | "
        echo "        |        status    ：     查看状态        | "
        echo "        +------------------+----------------------+ "
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
