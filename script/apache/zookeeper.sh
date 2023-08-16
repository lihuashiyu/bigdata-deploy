#!/usr/bin/env bash
# shellcheck disable=SC2120,SC2029

# =========================================================================================
#    FileName      ：  zookeeper.sh
#    CreateTime    ：  2023-02-27 17:09:54
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  zookeeper.sh 被用于 ==> zookeeper 集群的启停和状态检查脚本
# =========================================================================================
    
    
ZOOKEEPER_HOME=$(cd -P "$(dirname "$(readlink -e "$0")")/../" || exit; pwd -P) # Zookeeper 安装目录
ALIAS_NAME=Zookeeper                                                           # 服务别名
SERVICE_NAME=org.apache.zookeeper.server.quorum.QuorumPeerMain                 # Zookeeper 进程名称
          
ZOOKEEPER_PORT=2181                                                            # Zookeeper 端口号
ZOOKEEPER_UI_PORT=8180                                                         # Zookeeper Web 端口号
          
ZOOKEEPER_LIST=(${zookeeper_list})                                       # zookeeper 集群的主机名
USER=$(whoami)                                                                 # 获取当前登录用户
LOG_FILE="zookeeper-$(date +%F).log"                                           # 程序操作日志文件
RUNNING=1                                                                      # 服务运行状态码
STOP=0                                                                         # 服务停止状态码
LEADER_STATUS=leader                                                           # 节点的 leader 状态 
FLOWER_STATUS=flower                                                           # 节点的 flower 状态 
LOCAL_STATUS=standalone                                                        # 节点的 standalone 状态 


# 服务状态检测
function service_status()
{
    # 1. 初始化局域参数
    local result_list=() pid_list=() host_name zk_pid run_pid_count
    
    # 2. 遍历 Zookeeper 的所有的主机，查看 jvm 进程
    for host_name in "${ZOOKEEPER_LIST[@]}"
    do
        # 2.1 程序 Master 的 pid
        zk_pid=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ps -aux | grep -i '${USER}' | grep -viE 'grep|$0' | grep -ci '${SERVICE_NAME}'")
        
        # 2.2 判断进程是否存在
        if [ "${zk_pid}" -ne 1 ]; then
            result_list[${#result_list[@]}]="主机（${host_name}）的程序（Zookeeper）出现错误"
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
        # 3.1 遍历 Zookeeper 的所有的主机，启动各个节点的服务
        for host_name in "${ZOOKEEPER_LIST[@]}"
        do
            echo "    主机（${host_name}）的程序（${ALIAS_NAME}）正在加载中 ......"
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${ZOOKEEPER_HOME}/bin/zkServer.sh start >> ${ZOOKEEPER_HOME}/logs/${LOG_FILE} 2>&1"
        done
        
        # 3.2 验证每个节点进程状态
        echo "    程序（${ALIAS_NAME}）启动验证中 ......"
        sleep 2
        
        # 3.4 判断程序每个进程启动状态
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
        echo "    程序（${ALIAS_NAME}）已经停止运行 ...... "
    elif [ "${status}" == "${RUNNING}" ]; then
        # 3.1 遍历 Zookeeper 的所有的主机，停止各个节点的服务
        for host_name in "${ZOOKEEPER_LIST[@]}"
        do
            echo "    主机（${host_name}）的程序（${ALIAS_NAME}）正在停止中 ......"
            ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${ZOOKEEPER_HOME}/bin/zkServer.sh stop >> ${ZOOKEEPER_HOME}/logs/${LOG_FILE} 2>&1 "
        done
        
        echo "    程序（${ALIAS_NAME}）停止验证中 ...... "
        sleep 2
        
        # 3. 判断程序每个进程停止状态
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
    
    
# 节点角色
function service_role()
{
    # 1. 定义局部变量
    local status ps node_role mode
        
    # 2. 判断程序所处的状态
    status=$(service_status)
    
    # 3. 若处于停止状态，则打印结果；若处于运行状态，则判断节点的角色
    if [ "${status}" == "${STOP}" ]; then
        echo "    程序（${ALIAS_NAME}）已经停止运行 ...... "
    elif [ "${status}" == "${RUNNING}" ]; then
        # 3. 遍历 Zookeeper 的所有的主机，停止各个节点的服务
        for host_name in "${ZOOKEEPER_LIST[@]}"
        do
            # 3.1 程序 节点 的 角色
            node_role=$(ssh "${USER}@${host_name}" "source ~/.bashrc; source /etc/profile; ${ZOOKEEPER_HOME}/bin/zkServer.sh status 2> /dev/null | grep -i 'mode'")
            mode=$(echo "${node_role}" | awk -F ':' '{print $NF}' | awk '{gsub(/^\s+|\s+$/, ""); print}')
            echo "    主机（${host_name}）的（${ALIAS_NAME}）处于 ${mode} 状态 ......"
        done
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
    
    # 2.5 重启程序
    role)
        service_role
    ;;
    
    # 2.6 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：                   "
        echo "        +------------------------------------------+ "
        echo "        |  start | stop | restart | status | role  | "
        echo "        +------------------------------------------+ "
        echo "        |          start    ：  启动服务           | "
        echo "        |          stop     ：  关闭服务           | "
        echo "        |          restart  ：  重启服务           | "
        echo "        |          status   ：  查看状态           | "
        echo "        |          role     ：  节点角色           | "
        echo "        +------------------------------------------+ "
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
