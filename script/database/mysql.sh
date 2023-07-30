#!/usr/bin/env bash
    
# =========================================================================================
#    FileName      ：  mysql.sh
#    CreateTime    ：  2023-02-27 19:24:36
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  mysql.sh 被用于 ==> mysql 的启停和状态检查脚本
# =========================================================================================
    
    
SERVICE_DIR=$(cd -P "$(dirname "$(readlink -e "$0")")/../" || exit; pwd -P)    # 程序路径
SERVICE_NAME=mysql                                                             # 程序主进程名称
ALIAS_NAME=Mysql                                                               # 程序别名
MYSQL_SAFE=mysqld_safe                                                         # 用于启动 mysqld 服务，把信息记录到 error
MYSQLD=mysqld                                                                  # 守护进程名称
                        
SERVICE_PORT=3306                                                              # 服务监控端口
MYSQLD_PORT=33060                                                              # MySQL X 协议端口
RUNNING=1                                                                      # 运行状态
STOP=0                                                                         # 停止状态
    
    
# 服务状态检测
function service_status()
{
    # 1. 统计正在运行程序的 pid 的个数
    pid_count=$(ps -aux | grep -i "${MYSQLD}" | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
    
    # 2. 调用 Mysql 默认脚本查看状态
    mysql_status=$("${SERVICE_DIR}/support-files/mysql.server" status | awk '{print $3}')
    
    # 3 根据状态和 pid 判断 Mysql 运行状态
    if [ "${pid_count}" -eq 0 ] && [ "${mysql_status}" = "is" ]; then
        echo "${STOP}"
    elif [ "${pid_count}" -eq 2 ] && [ "${mysql_status}" = "running" ]; then
        echo "${RUNNING}"
    else
        # 3.1 查看个进程的状态
        safe_pid=$(ps -aux | grep -i "${MYSQL_SAFE}" | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
        mysqld_pid=$(ps -aux | grep -i "${MYSQLD}" | grep -vi "${MYSQL_SAFE}" | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
        
        # 3.2 判断程序 Mysqld_Safe 启动是否成功
        if [ ! "${safe_pid}" ]; then
            echo "    程序（mysqld_safe）出现错误 ...... "
        fi
        
        # 3.3 判断程序 Mysqld 启动是否成功
        if [ ! "${mysqld_pid}" ]; then
            echo "    程序（mysqld）出现错误 ...... "
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
        
        "${SERVICE_DIR}/support-files/mysql.server" start > /dev/null 2>&1
        sleep 2
        echo "    程序（${ALIAS_NAME}）启动验证中 ......"
        sleep 3
        
        # 3. 判断程序每个进程启动状态
        status=$(service_status)
        if [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）启动成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）启动失败 ...... "
            echo "${status}"
        fi
    else
        echo "    程序（${ALIAS_NAME}）运行出错 ...... "
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
        # 2.1 停止程序
        echo "    程序（${ALIAS_NAME}）正在停止中 ...... "
        
        "${SERVICE_DIR}/support-files/mysql.server" stop > /dev/null 2>&1
        sleep 2 
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
        echo "${status}"
    fi
}
    
    
# 服务重启
function service_restart()
{
    # 1. 判断程序所处的状态
    status=$(service_status)
    
    # 2. 若处于停止状态，则启动程序；若处于运行状态，则重启程序；若程序出现错误，则打印错误的进程
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）已经停止运行 ...... "
        service_start
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在重启中 ...... "
        
        "${SERVICE_DIR}/support-files/mysql.server" restart > /dev/null 2>&1
        sleep 2
        echo "    程序（${ALIAS_NAME}）重启验证中 ...... "
        sleep 3
        
        # 3. 判断程序每个进程重启状态
        status=$(service_status)
        if [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）重启成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）重启失败 ...... "
            echo "${status}"
        fi
    else
        echo "    程序（${ALIAS_NAME}）运行出错 ...... "
        echo "${status}"
    fi
}
    
    
# 重新加载配置文件
function service_reload()
{
    # 1. 判断程序所处的状态
    status=$(service_status)
    
    # 2. 若处于停止状态，则启动程序；若处于运行状态，则重启程序；若程序出现错误，则打印错误的进程
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）已经停止运行 ...... "
        service_start
    elif [ "${status}" == "${RUNNING}" ]; then
        echo "    程序（${ALIAS_NAME}）正在重新加载配置文件 ...... "
        
        "${SERVICE_DIR}/support-files/mysql.server" reload > /dev/null 2>&1
        sleep 2
        echo "    程序（${ALIAS_NAME}）加载配置文件验证中 ...... "
        sleep 3
        
        # 3. 判断程序每个进程重启状态
        status=$(service_status)
        if [ "${status}" == "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）重新加载配置文件成功 ...... "
        else
            echo "    程序（${ALIAS_NAME}）重新加载配置文件失败 ...... "
            echo "${status}"
        fi
    else
        echo "    程序（${ALIAS_NAME}）运行出错 ...... "
        echo "${status}"
    fi
}
    
    
printf "\n================================================================================\n"
#    匹配输入参数
case "$1" in
    # 1. 运行程序：running
    start)
        service_start
    ;;
    
    # 2. 停止
    stop)
        service_stop
    ;;
    
    # 3. 状态查询
    status)
        # 3.1 查看正在运行程序的 pid
        status=$(service_status)
        
        # 3.2 判断 Mysql 运行状态
        if [ "${status}" = "${STOP}" ]; then
            echo "    程序（${ALIAS_NAME}）已经停止 ...... "
        elif [ "${status}" = "${RUNNING}" ]; then
            echo "    程序（${ALIAS_NAME}）正在运行中 ...... "
        else
            echo "    程序（${ALIAS_NAME}）运行出现问题 ...... "
            echo "${status}"
        fi
    ;;
    
    # 4. 重启程序
    restart)
        service_restart
    ;;
    
    # 5. 重启加载配置文件
    reload)
        service_reload
    ;;
    
    # 6. 其它情况
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
printf "================================================================================\n\n"
exit 0
