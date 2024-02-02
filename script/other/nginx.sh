#!/usr/bin/env bash
    
# =========================================================================================
#    FileName      ：  nginx.sh
#    CreateTime    ：  2023-02-27 19:24:36
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  nginx.sh 被用于 ==> nginx 的启停和状态检查脚本
# =========================================================================================
    
        
NGINX_HOME=$(cd -P "$(dirname "$(readlink -e "$0")")/../" || exit; pwd -P)     # 程序路径
ALIAS_NAME=Nginx                                                               # 程序别名
CONFIG_FILE=nginx.conf                                                         # 配置文件名
LOG_FILE=nginx-operation.log                                                   # 程序启停日志文件
                        
NGINX_PORT=47722                                                               # Nginx 前端静态资源监控端口
SERVICE_PORT2=10800                                                            # 后台服务
MASTER="nginx: master process"                                                 # Nginx Master 进程名称
WORKER="nginx: worker process"                                                 # Nginx Worker 进程名称
USER=$(whoami)                                                                 # 获取当前登录用户
RUNNING=1                                                                      # 运行状态
STOP=0                                                                         # 停止状态
    
    
# 服务状态检测
function service_status()
{
    # 1. 初始化局域参数
    local result_list=() pid_list=() host_name master_pid worker_pid worker_count run_pid_count
    
    # 2.1 获取程序 Master 的 pid 的数量
    master_pid=$(ps -aux | grep -i "${USER}" | grep -viE "$0|grep" | grep -ci "${MASTER}")
    
    # 2.2 判断进程 master_pid 数量是否正确
    if [ "${master_pid}" -ne 1 ]; then
        result_list[${#result_list[@]}]="主机（${host_name}）的程序（Nginx Master）出现错误 "
        pid_list[${#pid_list[@]}]="${STOP}"
    else
        pid_list[${#pid_list[@]}]="${RUNNING}"
    fi  
    
    # 3.1 获取程序 Worker 的 pid 数量是否正确
    worker_pid=$(ps -aux | grep -i "${USER}" | grep -viE "$0|grep" | grep -ci "${WORKER}")
    worker_count=$(grep -ni "worker_processes" "${NGINX_HOME}/conf/nginx.conf" | awk -F ';' '{print $1}' | awk '{print $NF}')
    
    # 3.2 判断进程 worker_pid 数量是否正确
    if [ "${worker_pid}" -ne "${worker_count}" ]; then
        result_list[${#result_list[@]}]="主机（${host_name}）的程序（Nginx Worker）出现错误 "
        pid_list[${#pid_list[@]}]="${STOP}"
    else
        pid_list[${#pid_list[@]}]="${RUNNING}"
    fi  
    
    # 4. 判断是否所有的进程都正常
    run_pid_count=$(echo "${pid_list[@]}"  | grep -ci "${RUNNING}") 
    
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
    # 1. 定义局域变量
    local status host_name ps
    
    # 2. 获取服务的运行状态
    status=$(service_status)
    
    # 3. 若处于运行状态，则打印结果；若处于停止状态，则启动程序；若程序启动时，出现错误，则打印错误的进程
    if [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在运行 ...... "
    elif [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）正在加载中 ......"
        
        # 3.1 启动 Nginx 的相关进程
        "${NGINX_HOME}/bin/nginx" -c "${NGINX_HOME}/conf/${CONFIG_FILE}" >> "${NGINX_HOME}/logs/${LOG_FILE}" 2>&1
        
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
    
    
# 服务停止
function service_stop()
{
    # 1. 定义局域变量
    local status ps
    
    # 2. 获取服务的运行状态
    status=$(service_status)
    
    # 3. 若处于停止状态，则打印结果；若处于运行状态，则停止程序；若停止时，程序出现错误，则打印错误的进程
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）已经停止 ...... "
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在停止中 ...... "
        
        # 3.1 停止 Nginx 的相关进程
        "${NGINX_HOME}/bin/nginx" -s quit >> "${NGINX_HOME}/logs/${LOG_FILE}" 2>&1
        
        sleep 1 
        echo "    程序（${ALIAS_NAME}）停止验证中 ...... "
        sleep 1
        
        # 3.2 判断程序每个进程停止状态
        status=$(service_status)
        if [ "${status}" == "${RUNNING}" ]; then
            # 3.3 强制停止 Nginx 相关进程
            "${NGINX_HOME}/bin/${SERVICE_NAME}" -s stop >> "${NGINX_HOME}/logs/${LOG_FILE}" 2>&1
        fi
        
        echo "    程序（${ALIAS_NAME}）停止成功 ...... "
    else
        echo "    程序（${ALIAS_NAME}）运行出错 ...... "
        for ps in ${status}
        do
            echo "    ${ps} ...... "
        done  
    fi
}
    
    
# 服务重启
function service_restart()
{
    # 1. 定义局域变量
    local status ps
    
    # 2. 判断程序所处的状态
    status=$(service_status)
    
    # 3. 若处于停止状态，则启动程序；若处于运行状态，则重启程序；若程序出现错误，则打印错误的进程
    if [ "${status}" == "${STOP}" ]; then
        # 3.1 若处于停止状态，直接启动
        echo "    程序（${ALIAS_NAME}）已经停止 ...... "
        service_start        
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在重启中 ...... "
        
        # 3.2 重启 Nginx 程序
        "${NGINX_HOME}/bin/nginx" -s reload >> "${NGINX_HOME}/logs/${LOG_FILE}" 2>&1
        
        sleep 1 
        echo "    程序（${ALIAS_NAME}）重启验证中 ...... "
        sleep 1
        
        # 3. 判断程序每个进程重启状态
        status=$(service_status)
        if [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）重启成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）重启失败 ...... "
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
        
        # 2.3.2 根据查询结果，判断程序运行状态
        if [ "${status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）已经停止 ...... "        
        elif [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）正在运行中 ...... "
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
        service_restart
    ;;
    
    # 2.5 测试配置文件
    test)
        "${NGINX_HOME}/bin/nginx" -t
    ;;
    
    # 2.6 其它情况
    *)  
        echo "    脚本仅可传入一个参数，若传入多个参数，则仅第一个有效，参数如下所示："
        echo "        +----------------------------------------+ "
        echo "        | start | stop | restart | status | test | "
        echo "        +----------------------------------------+ "
        echo "        |        start    ：  启动服务           | "
        echo "        |        stop     ：  关闭服务           | "
        echo "        |        restart  ：  重启服务           | "
        echo "        |        status   ：  查看状态           | "
        echo "        |        test     ：  测试配置           | "
        echo "        +----------------------------------------+ "
    ;;
esac

# 3. 获取脚本执行结束时间
end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 4. 计算并输出脚本执行时间
if [ "$#" -eq 1 ]  && { [ "$1" == "start" ] || [ "$1" == "stop" ] || [ "$1" == "restart" ]; }; then
    echo "    脚本（$(basename "$0")）执行共消耗：$(( end - start ))s ...... "
fi

printf "================================================================================\n\n"
exit 0
