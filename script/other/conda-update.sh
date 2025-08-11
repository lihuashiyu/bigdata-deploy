#!/usr/bin/env bash
    
# =========================================================================================
#    FileName      ：  conda-update.sh
#    CreateTime    ：  2025-08-11 16:19:57
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  conda 更新
# =========================================================================================

CONDA_HOME=$(dirname "$(readlink -e "$0")")                          # conda 安装目录
LOG_FILE="${CONDA_HOME}/logs/update-$(date +%F).log"                 # 程序操作日志文件


# 刷新环境变量
function flush_env()
{
    echo "    ************************** 刷新环境变量 **************************    "
    mkdir -p "${CONDA_HOME}/logs"                                    # 创建日志目录
    
    if [ -f "${HOME}/.bashrc" ]; then
        source "${HOME}/.bashrc"                                     # 用户环境变量文件
    elif [ -f "${HOME}/.bash_profile" ]; then
        source "${HOME}/.bash_profile"                               # 用户环境变量文件
    else
        echo "    没有找到用户环境变量文件！"
        exit 1                                                       # 没有找到用户环境变量文件        
    fi
    
    if [ -f "/etc/profile" ]; then
        source "/etc/profile"                                        # 系统环境变量文件
    else
        echo "    没有找到系统环境变量文件！"
        exit 1                                                       # 没有找到系统环境变量文件
    fi
}


# 更新 conda
function conda_update()
{
    echo "    ************************ 更新 conda 版本 *************************    "
    "${CONDA_HOME}/bin/conda" update conda --yes  >> "${LOG_FILE}"  2>&1
     
    if [ $? -ne 0 ]; then
        echo "    ************************* conda 更新成功 *************************    "
    else
        echo "    ************************* conda 更新失败 *************************    "
        exit 1
    fi  
}


# 更新 python
function python_update()
{
    echo "    ************************ 更新 python 版本 ************************    "
    "${CONDA_HOME}/bin/conda"  update python  --yes  >> "${LOG_FILE}"  2>&1
    
    if [ $? -ne 0 ]; then
        echo "    ************************ python  更新成功 ************************    "
    else
        echo "    ************************ python  更新失败 ************************    "
        exit 1
    fi  
}


# 更新第三方包
function package_update()
{
    echo "    ************************** 更新第三方包 **************************    "
    "${CONDA_HOME}/bin/conda" update --all --yes  >> "${LOG_FILE}"  2>&1
    
    if [ $? -ne 0 ]; then
        echo "    ************************ 第三方包更新成功 ************************    "
    else
        echo "    ************************ 第三方包更新失败 ************************    "
        exit 1
    fi  
}


# 匹配输入参数
function case_argument()
{
    local argument                                                # 定义局部变量
    
    if [ "$#" -eq 0 ]; then
        usage
        exit 0
    else
        for argument in "$@"
        do
            case "${argument}" in
                # 1 配置网卡
                p | python | -p | --python)
                    python_update
                ;;
                
                # 2 设置主机名与 hosts 映射
                k | package | -k | --package)
                    package_update
                ;;
                
                # 3 关闭防火墙 和 SELinux
                c | conda | -c | --conda)
                    conda_update
                ;;
                
                # 4 更新所有
                a | all | -a | --all)
                  python_update
                  package_update
                  conda_update
                ;;
                
                # 15 其它情况
                *)
                    usage
                    return
                ;;
            esac
        done
    fi
}


# 脚本使用说明
function usage()
{
    echo "    脚本可传入的参数如下所示：     "
    echo "        +--------------------+------------------+ "
    echo "        |       参  数       |    描  述        | "
    echo "        +--------------------+------------------+ "
    echo "        |   -c | --conda     |   更新 conda     | "
    echo "        |   -p | --python    |   更新 python    | "
    echo "        |   -k | --package   |   更新第三方包   | "
    echo "        |   -a | --all       |   更新全部       | "
    echo "        |   -h | --help      |   使用帮助       | "
    echo "        +--------------------+------------------+ "
}


printf "\n================================================================================\n"
flush_env
case_argument "$@"
printf "================================================================================\n\n"

exit 0
