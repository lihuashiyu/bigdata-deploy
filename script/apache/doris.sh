#!/usr/bin/env bash
# shellcheck disable=SC2029
    
# =========================================================================================
#    FileName      ：  doris.sh
#    CreateTime    ：  2023-02-16 17:03:45
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  doris 启停脚本
# =========================================================================================

    
DORIS_HOME=$(cd -P "$(dirname "$(readlink -e "$0")")" || exit; pwd -P)         # Doris 安装目录
ALIAS_FE_NAME="Doris FE"                                                       # FE     别名
ALIAS_BE_NAME="Doris BE"                                                       # BE     别名
ALIAS_BROKER_NAME="Doris Broker"                                               # Broker 别名
FE_NAME="org.apache.doris.PaloFe"                                              # FE     进程名称
BE_NAME="${DORIS_HOME}/be/lib/doris_be"                                        # BE     进程名称
BROKER_NAME="org.apache.doris.broker.hdfs.BrokerBootstrap"                     # Broker 进程名称
    
FE_PORT=8030                                                                   # FE 端口
FE_QUERY_PORT=9030                                                             # FE 端口
BE_PORT=9060                                                                   # BE 端口
BE_WEB_PORT=8040                                                               # BE 端口
BE_WEB_PORT=8040                                                               # Broker 端口
BE_WEB_PORT=8040                                                               # Broker 端口
        
FE_LIST=(${fe_list})                                              # FE     部署节点
BE_LIST=(${be_list})                                              # FE     部署节点
BROKER_LIST=(${broker_list})                                      # Broker 部署节点
FE_LOG_FILE=fe-$(date +%F).log                                                 # FE     程序操作日志文件
BE_LOG_FILE=be-$(date +%F).log                                                 # BE     程序操作日志文件
BROKER_LOG_FILE=broker-$(date +%F).log                                         # Broker 程序操作日志文件

USER=$(whoami)                                                                 # 获取当前登录用户
RUNNING=1                                                                      # 服务运行状态码
STOP=0                                                                         # 服务停止状态码


# 各个节点服务状态检测（$1：部署服务的节点列表、$1：服务名称、$1：服务别名）
function node_service_status()
{
    # 1. 定义变量
    local host_name result_list=() pid_list=() pid_count run_pid_count result_pid_count
    
    # 2. 遍历 服务 的所有的主机，查看进程
    for host_name in $1
    do
        # 3. 程序 的 pid
        pid_count=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -i '$2' | grep -viE 'grep|$0' | wc -l")
        
        if [[ "${pid_count}" -ne 1 ]]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（$3）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi
    done
    
    # 4. 判断是否所有的进程都正常
    run_pid_count=$(echo "${pid_list[@]}"  | grep -ci "${RUNNING}")
    
    if [[ "${#result_list[@]}" -eq 0 ]]; then
        echo "${RUNNING}"
    elif [[ "${result_pid_count}" -eq 0 ]]; then
        echo "${STOP}"
    else
        echo "${result_list[@]}"
    fi
}

    
# FE 服务启动
function fe_start()
{
    # 1. 定义局部变量
    local fe_status host_name ps
    
    # 2. 遍历 FE 的所有的主机，查看进程
    fe_status=$(node_service_status "${FE_LIST[*]}" "${FE_NAME}" "${ALIAS_FE_NAME}")
    
    # 3. 若处于运行状态，则打印结果；若处于停止状态，则启动程序；若程序启动时，出现错误，则打印错误的进程
    if [ "${fe_status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_FE_NAME}）正在运行 ...... "
    elif [ "${fe_status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_FE_NAME}）正在加载中 ......"
        for host_name in "${FE_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${DORIS_HOME}/fe/bin/start_fe.sh --daemon >> ${DORIS_HOME}/fe/log/${FE_LOG_FILE} 2>&1 "
        done
        
        sleep 2
        echo "    程序（${ALIAS_FE_NAME}）启动验证中 ......" 
        sleep 1        
        
        # 4. 判断程序每个进程启动状态
        fe_status=$(node_service_status "${FE_LIST[*]}" "${FE_NAME}" "${ALIAS_FE_NAME}")
        if [ "${fe_status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_FE_NAME}）启动成功 ...... "
        else
            echo "    程序（${ALIAS_FE_NAME}）启动失败 ...... "
            for ps in ${fe_status}
            do
                echo "    ${ps} ...... "
            done
        fi
    else
        echo "    程序（${ALIAS_FE_NAME}）运行出错 ...... "
        for ps in ${fe_status}
        do
            echo "    ${ps} ...... "
        done
    fi                
}

   
# BE 服务启动
function be_start()
{
    # 1. 定义局部变量
    local be_status host_name ps
    
    # 2. 遍历 BE 的所有的主机，查看进程
    be_status=$(node_service_status "${BE_LIST[*]}" "${BE_NAME}" "${ALIAS_BE_NAME}")
        
    # 3. 若处于运行状态，则打印结果；若处于停止状态，则启动程序；若程序启动时，出现错误，则打印错误的进程
    if [ "${be_status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_BE_NAME}）正在运行 ...... "
    elif [ "${be_status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_BE_NAME}）正在加载中 ......"
        for host_name in "${BE_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${DORIS_HOME}/be/bin/start_be.sh --daemon >> ${DORIS_HOME}/be/log/${BE_LOG_FILE} 2>&1 "
        done
        
        sleep 2
        echo "    程序（${ALIAS_BE_NAME}）启动验证中 ......" 
        sleep 1        
        
        # 4. 判断程序每个进程启动状态
        be_status=$(node_service_status "${BE_LIST[*]}" "${BE_NAME}" "${ALIAS_BE_NAME}")
        if [ "${be_status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_BE_NAME}）启动成功 ...... "
        else
            echo "    程序（${ALIAS_BE_NAME}）启动失败 ...... "
            for ps in ${be_status}
            do
                echo "    ${ps} ...... "
            done
        fi
    else
        echo "    程序（${ALIAS_BE_NAME}）运行出错 ...... "
        for ps in ${be_status}
        do
            echo "    ${ps} ...... "
        done
    fi
}

    
# Broker 服务启动
function broker_start()
{
    # 1. 定义局部变量
    local broker_status host_name ps
    
    # 2. 遍历 FE 的所有的主机，查看进程
    broker_status=$(node_service_status "${BROKER_LIST[*]}" "${BROKER_NAME}" "${ALIAS_BROKER_NAME}")
    
    # 3. 若处于运行状态，则打印结果；若处于停止状态，则启动程序；若程序启动时，出现错误，则打印错误的进程
    if [ "${broker_status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_BROKER_NAME}）正在运行 ...... "
    elif [ "${broker_status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_BROKER_NAME}）正在加载中 ......"
        for host_name in "${BROKER_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${DORIS_HOME}/broker/bin/start_broker.sh --daemon >> ${DORIS_HOME}/broker/log/${BROKER_LOG_FILE} 2>&1 "
        done
        
        sleep 2
        echo "    程序（${ALIAS_BROKER_NAME}）启动验证中 ......" 
        sleep 1        
        
        # 4. 判断程序每个进程启动状态
        broker_status=$(node_service_status "${BROKER_LIST[*]}" "${BROKER_NAME}" "${ALIAS_BROKER_NAME}")
        if [ "${broker_status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_BROKER_NAME}）启动成功 ...... "
        else
            echo "    程序（${ALIAS_BROKER_NAME}）启动失败 ...... "
            for ps in ${broker_status}
            do
                echo "    ${ps} ...... "
            done
        fi
    else
        echo "    程序（${ALIAS_BROKER_NAME}）运行出错 ...... "
        for ps in ${broker_status}
        do
            echo "    ${ps} ...... "
        done
    fi                
}


# FE 服务停止
function fe_stop()
{
    # 1. 定义局部变量
    local fe_status host_name ps
    
    # 2. 遍历 FE 的所有的主机，查看进程
    fe_status=$(node_service_status "${FE_LIST[*]}" "${FE_NAME}" "${ALIAS_FE_NAME}")
    
    # 3. 若处于停止状态，则打印结果；若处于运行状态，则停止程序；若停止时，程序出现错误，则打印错误的进程
    if [ "${fe_status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_FE_NAME}）已经停止运行 ...... "
    elif [ "${fe_status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_FE_NAME}）正在停止中 ......"
        for host_name in "${FE_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${DORIS_HOME}/fe/bin/stop_fe.sh >> ${DORIS_HOME}/fe/log/${FE_LOG_FILE} 2>&1 "
        done
        
        sleep 2
        echo "    程序（${ALIAS_FE_NAME}）停止验证中 ......" 
        sleep 1        
        
        # 4. 判断程序每个进程启动状态
        fe_status=$(node_service_status "${FE_LIST[*]}" "${FE_NAME}" "${ALIAS_FE_NAME}")
        if [ "${fe_status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_FE_NAME}）停止成功 ...... "
        else
            echo "    程序（${ALIAS_FE_NAME}）停止失败 ...... "
            for ps in ${fe_status}
            do  
                echo "    ${ps} ...... "
            done
        fi        
    else
        echo "    程序（${ALIAS_FE_NAME}）运行出错 ...... "
        for ps in ${fe_status}
        do
            echo "    ${ps} ...... "
        done
    fi
}


# FE 服务停止
function be_stop()
{
    # 1. 定义局部变量
    local be_status host_name ps
    
    # 2. 遍历 FE 的所有的主机，查看进程
    be_status=$(node_service_status "${BE_LIST[*]}" "${BE_NAME}" "${ALIAS_BE_NAME}")
    
    # 3. 若处于停止状态，则打印结果；若处于运行状态，则停止程序；若停止时，程序出现错误，则打印错误的进程
    if [ "${be_status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_BE_NAME}）已经停止运行 ...... "
    elif [ "${be_status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_BE_NAME}）正在停止中 ......"
        for host_name in "${BE_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${DORIS_HOME}/be/bin/stop_be.sh >> ${DORIS_HOME}/be/log/${BE_LOG_FILE} 2>&1 "
        done
        
        sleep 2
        echo "    程序（${ALIAS_BE_NAME}）停止验证中 ......" 
        sleep 1        
        
        # 4. 判断程序每个进程启动状态
        be_status=$(node_service_status "${BE_LIST[*]}" "${BE_NAME}" "${ALIAS_BE_NAME}")
        if [ "${be_status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_BE_NAME}）停止成功 ...... "
        else
            echo "    程序（${ALIAS_BE_NAME}）停止失败 ...... "
            for ps in ${be_status}
            do  
                echo "    ${ps} ...... "
            done
        fi        
    else
        echo "    程序（${ALIAS_BE_NAME}）运行出错 ...... "
        for ps in ${be_status}
        do
            echo "    ${ps} ...... "
        done
    fi
}


# Broker 服务停止
function broker_stop()
{
    # 1. 定义局部变量
    local broker_status host_name ps
    
    # 2. 遍历 FE 的所有的主机，查看进程
    broker_status=$(node_service_status "${BROKER_LIST[*]}" "${BROKER_NAME}" "${ALIAS_BROKER_NAME}")
    
    # 3. 若处于停止状态，则打印结果；若处于运行状态，则停止程序；若停止时，程序出现错误，则打印错误的进程
    if [ "${broker_status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_BROKER_NAME}）已经停止运行 ...... "
    elif [ "${broker_status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_BROKER_NAME}）正在停止中 ......"
        for host_name in "${BROKER_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${DORIS_HOME}/broker/bin/stop_broker.sh >> ${DORIS_HOME}/broker/log/${BROKER_LOG_FILE} 2>&1 "
        done
        
        sleep 2
        echo "    程序（${ALIAS_BROKER_NAME}）停止验证中 ......" 
        sleep 1        
        
        # 4. 判断程序每个进程启动状态
        broker_status=$(node_service_status "${BROKER_LIST[*]}" "${BROKER_NAME}" "${ALIAS_BROKER_NAME}")
        if [ "${broker_status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_BROKER_NAME}）停止成功 ...... "
        else
            echo "    程序（${ALIAS_BROKER_NAME}）停止失败 ...... "
            for ps in ${broker_status}
            do  
                echo "    ${ps} ...... "
            done
        fi        
    else
        echo "    程序（${ALIAS_BROKER_NAME}）运行出错 ...... "
        for ps in ${broker_status}
        do
            echo "    ${ps} ...... "
        done
    fi
}
   
    
function service_status()
{
    # 1. 定义局部变量
    local fe_status be_status broker_status ps
    
    # 2.1 遍历 FE 的所有的主机，查看进程
    fe_status=$(node_service_status "${FE_LIST[*]}" "${FE_NAME}" "${ALIAS_FE_NAME}")
    
    # 2.2 判断 FE 运行状态
    if [ "${fe_status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_FE_NAME}）已经停止 ...... "
    elif [ "${fe_status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_FE_NAME}）正在运行中 ...... "
    else
        echo "    程序（${ALIAS_FE_NAME}）运行出现问题 ...... "
        for ps in ${fe_status}
        do
            echo "    ${ps} ...... "
        done
    fi
    
    # 3.1 遍历 BE 的所有的主机，查看进程
    be_status=$(node_service_status "${BE_LIST[*]}" "${BE_NAME}" "${ALIAS_BE_NAME}")
    
    # 3.2 判断 BE 运行状态
    if [ "${be_status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_BE_NAME}）已经停止 ...... "
    elif [ "${be_status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_BE_NAME}）正在运行中 ...... "
    else
        echo "    程序（${ALIAS_BE_NAME}）运行出现问题 ...... "
        for ps in ${be_status}
        do
            echo "    ${ps} ...... "
        done
    fi
    
    # 4.1 遍历 Broker 的所有的主机，查看进程
    broker_status=$(node_service_status "${BROKER_LIST[*]}" "${BROKER_NAME}" "${ALIAS_BROKER_NAME}")
    
    # 4.2 判断 Broker 运行状态
    if [ "${broker_status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_BROKER_NAME}）已经停止 ...... "
    elif [ "${broker_status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_BROKER_NAME}）正在运行中 ...... "
    else
        echo "    程序（${ALIAS_BROKER_NAME}）运行出现问题 ...... "
        for ps in ${broker_status}
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
        fe_start
        be_start
        broker_start
    ;;
    
    # 2.2 停止
    stop)
        broker_stop
        be_stop
        fe_stop
    ;;
    
    # 2.3 状态查询
    status)
        service_status
    ;;
    
    # 2.4 重启程序
    restart)
        broker_stop
        be_stop
        fe_stop
        fe_start
        be_start
        broker_start
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
