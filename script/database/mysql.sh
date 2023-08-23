#!/usr/bin/env bash
# shellcheck disable=SC2029
    
# =========================================================================================
#    FileName      ：  mysql.sh
#    CreateTime    ：  2023-02-27 19:24:36
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  mysql.sh 被用于 ==> mysql 的启停和状态检查脚本
# =========================================================================================
    
    
MYSQL_HOME=$(cd -P "$(dirname "$(readlink -e "$0")")/../" || exit; pwd -P)     # 程序路径
ALIAS_NAME=Mysql                                                               # 程序别名
MYSQL_SAFE=mysqld_safe                                                         # 用于启动 mysqld 服务，把信息记录到 error
                        
SERVICE_PORT=3306                                                              # 服务监控端口
MYSQLD_PORT=33060                                                              # MySQL 协议端口

MYSQL_LIST=(${mysql_list})                                           # Mysql 的安装主机
LOG_FILE="mysql-$(date +%F).log"                                               # 启停操作日志文件
USER=$(whoami)                                                                 # 获取当前登录用户
RUNNING=1                                                                      # 运行状态
STOP=0                                                                         # 停止状态
    
    
# 服务状态检测
function service_status()
{
    # 1. 初始化局域参数
    local result_list=() pid_list=() host_name mysqld_pid mysql_safe_pid run_pid_count
    
    # 2. 获取各个节点的 mysqld_pid 的进程状态
    for host_name in "${MYSQL_LIST[@]}"
    do
        # 2.1 调用 Mysql 脚本获取 Mysql 守护进程的 pid 
        mysqld_pid=$("${MYSQL_HOME}/support-files/mysql.server" status | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
        
        # 2.2 判断进程 mysqld_pid 是否存在
        if [ -z "${mysqld_pid}" ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（mysqld_pid）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi        
    done
    
    # 3. 获取各个节点的 mysql_safe 的进程状态
    for host_name in "${MYSQL_LIST[@]}"
    do
        # 3.1 mysql_safe 进程的 pid
        mysql_safe_pid=$(ps -aux | grep -i "${USER}" | grep -viE "$0|grep" | grep -ci "${MYSQL_SAFE}")
        
        # 3.2 判断进程 mysql_safe 是否存在
        if [ -z "${mysqld_pid}" ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（mysqld_pid）出现错误"
            pid_list[${#pid_list[@]}]="${STOP}"
        else
            pid_list[${#pid_list[@]}]="${RUNNING}"
        fi        
    done
        
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
    # 1. 定义局部变量
    local status host_name ps
    
    # 2. 判断程序所处的状态
    status=$(service_status)
    
    # 3. 若处于运行状态，则打印结果；若处于停止状态，则启动程序，并判断启动结果；若程序出现错误，则打印错误
    if [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在运行 ...... "
    elif [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）正在加载中 ......"
        
        # 3.1 启动 Mysql 的相关进程
        for host_name in "${MYSQL_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${MYSQL_HOME}/support-files/mysql.server start >> ${MYSQL_HOME}/logs/${LOG_FILE} 2>&1"
        done
        
        sleep 2
        echo "    程序（${ALIAS_NAME}）启动验证中 ......"
        sleep 3
        
        # 3.2 判断每个进程启动状态
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
    # 1. 定义局部变量
    local status host_name ps
    
    # 2. 判断程序所处的状态
    status=$(service_status)
    
    # 3. 若处于停止状态，则打印结果；若处于运行状态，则停止程序；若停止时，程序出现错误，则打印错误的进程
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）已经停止 ...... "
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在停止中 ...... "
        
        # 3.1 停止 Mysql 程序
        for host_name in "${MYSQL_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${MYSQL_HOME}/support-files/mysql.server stop >> ${MYSQL_HOME}/logs/${LOG_FILE} 2>&1"
        done
        
        sleep 2 
        echo "    程序（${ALIAS_NAME}）停止验证中 ...... "
        sleep 3
        
        # 3.2 判断程序每个进程停止状态
        status=$(service_status)
        if [ "${status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）停止成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）停止失败 ...... "
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
    
    
# 服务重启
function service_restart()
{
    # 1. 定义局部变量
    local status host_name ps
    
    # 2. 判断程序所处的状态
    status=$(service_status)
        
    # 3. 若处于停止状态，则启动程序；若处于运行状态，则重启程序；若程序出现错误，则打印错误的进程
    if [ "${status}" == "${STOP}" ]; then
        # 3.1 若处于停止状态，直接启动
        echo "    程序（${ALIAS_NAME}）已经停止 ...... "
        service_start
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在重启中 ...... "
        
        # 3.2 重启 Mysql 程序
        for host_name in "${MYSQL_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${MYSQL_HOME}/support-files/mysql.server restart >> ${MYSQL_HOME}/logs/${LOG_FILE} 2>&1"
        done
        
        sleep 2
        echo "    程序（${ALIAS_NAME}）重启验证中 ...... "
        sleep 3
        
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
    
    
# 重新加载配置文件
function service_reload()
{
    # 1. 定义局部变量
    local status host_name ps
    
    # 2. 判断程序所处的状态
    status=$(service_status)
        
    # 3. 若处于停止状态，则启动程序；若处于运行状态，则重启程序；若程序出现错误，则打印错误的进程
    if [ "${status}" == "${STOP}" ]; then
        # 3.1 若处于停止状态，直接启动
        echo "    程序（${ALIAS_NAME}）已经停止 ...... "
        service_start
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）重新加载配置 ...... "
        
        # 3.2 重启 Mysql 程序
        for host_name in "${MYSQL_LIST[@]}"
        do
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${MYSQL_HOME}/support-files/mysql.server reload >> ${MYSQL_HOME}/logs/${LOG_FILE} 2>&1"
        done
        
        sleep 2
        echo "    程序（${ALIAS_NAME}）加载配置验证中 ...... "
        sleep 3
        
        # 3. 判断程序每个进程重启状态
        status=$(service_status)
        if [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）加载配置成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）加载配置失败 ...... "
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
    
    # 3. 状态查询
    status)
        # 2.3.1 查看正在运行程序的 pid
        pid_status=$(service_status)
        
        # 2.3.2 判断 ES 运行状态
        if [ "${pid_status}" == "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）已经停止 ...... "
        elif [ "${pid_status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）正在运行 ...... "
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
        service_restart
    ;;
    
    # 2.5 重启加载配置文件
    reload)
        service_reload
    ;;
    
    # 2.6 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：                       "
        echo "        +--------------------------------------------+ "
        echo "        |  start | stop | restart | status | reload  | "
        echo "        +--------------------------------------------+ "
        echo "        |          start      ：    启动服务         | "
        echo "        |          stop       ：    关闭服务         | "
        echo "        |          restart    ：    重启服务         | "
        echo "        |          status     ：    查看状态         | "
        echo "        |          reload     ：    重新加载         | "
        echo "        +--------------------------------------------+ "
    ;;
esac

# 3. 获取脚本执行结束时间
end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 4. 计算并输出脚本执束时间
if [ "$#" -eq 1 ]  && { [ "$1" == "start" ] || [ "$1" == "stop" ] || [ "$1" == "restart" ] || [ "$1" == "reload" ]; }; then
    echo "    脚本（$(basename "$0")）执行共消耗：$(( end - start ))s ...... "
fi

printf "================================================================================\n\n"
exit 0
