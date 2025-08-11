#!/usr/bin/env bash
    
# =========================================================================================
#    FileName      ：  conda-update.sh
#    CreateTime    ：  2025-08-11 16:19:57
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  conda 更新
# =========================================================================================

CONDA_HOME=$(dirname "$(readlink -e "$0")")                          # conda 安装目录
LOG_DIRECTORY="${CONDA_HOME}/logs"                                   # 程序操作日目录名


# 刷新环境变量
function flush_env()
{
    echo "    ************************** 刷新环境变量 **************************    "
    mkdir -p "${LOG_DIRECTORY}"                                      # 创建日志目录
    
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


# 清除所有缓存
function cache_clean()
{
    local log_file                                                   # 定义局部变量
    log_file="${LOG_DIRECTORY}/cache-clean-$(date +%F).log"          # 日志文件
    
    echo "    *************************** 清除缓存 ****************************    "
    cd "${CONDA_HOME}" || exit 1                                     # 进入 conda 目录
    
    {
        "${CONDA_HOME}/bin/conda" clean --all -y                     # 清除 conda 缓存
        "${CONDA_HOME}/bin/pip"   cache purge                        # 清除 pip 缓存
    }  >> "${log_file}" 2>&1
    
    if [ $? -ne 0 ]; then
        echo "    ************************** 缓存清除成功 **************************    "
    else
        echo "    ************************** 缓存清除失败 **************************    "
        exit 1
    fi
}


# 更新 conda
function conda_update()
{
    local log_file                                                   # 定义局部变量
    log_file="${LOG_DIRECTORY}/conda-update-$(date +%F).log"         # 日志文件
    
    echo "    ************************ 更新 conda 版本 *************************    "
    cd "${CONDA_HOME}" || exit 1                                     # 进入 conda 目录
    
    {
        "${CONDA_HOME}/bin/conda" update -n base -c defaults conda -y     # 更新 conda 本身
        "${CONDA_HOME}/bin/conda" update -y conda                         # 更新 conda 工具
    } >> "${log_file}" 2>&1
        
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
    local log_file                                                   # 定义局部变量
    log_file="${LOG_DIRECTORY}/python-update-$(date +%F).log"        # 日志文件
    
    echo "    ************************ 更新 python 版本 ************************    "
    cd "${CONDA_HOME}" || exit 1                                     # 进入 conda 目录
    "${CONDA_HOME}/bin/conda"  update python  --yes  >> "${log_file}"  2>&1
    
    if [ $? -ne 0 ]; then
        echo "    ************************ python  更新成功 ************************    "
    else
        echo "    ************************ python  更新失败 ************************    "
        exit 1
    fi  
}


# 更新所有库
function module_update()
{
    local log_file                                                   # 定义局部变量
    log_file="${LOG_DIRECTORY}/module-update-$(date +%F).log"        # 日志文件
    
    echo "    ************************** 更新所有库 ****************************    "    
    cd "${CONDA_HOME}" || exit 1                                     # 进入 conda 目录    
    "${CONDA_HOME}/bin/conda" update --all --yes  >> "${log_file}"  2>&1
    
    if [ $? -ne 0 ]; then
        echo "    ************************* 更新所有库成功 **************************    "
    else
        echo "    ************************* 更新所有库失败 **************************    "
        exit 1
    fi  
}


# 匹配输入参数
function case_argument()
{
    local argument                                                   # 定义局部变量
    for argument in "$@"
    do
        case "${argument}" in
            c | clean | -c | --clean)                                # 1 清除所有缓存
                cache_clean
            ;;
            
            o | conda | -o | --conda)                                # 2 更新 conda 自身
                conda_update
            ;;
            
            p | python | -p | --python)                              # 3 更新 Python 版本
                python_update
            ;;
            
            m | module | -m | --module)                              # 4 更新所有模块
                module_update
            ;;
            
            a | all | -a | --all)                                    # 5 更新所有
                cache_clean
                conda_update
                python_update
                module_update                  
            ;;
            
            *)                                                       # 6 其它情况
                usage
                exit 0
            ;;
        esac
    done
}


# 脚本使用说明
function usage()
{
    echo "    脚本可传入的参数如下所示：     "
    echo "        +--------------------+------------------+ "
    echo "        |       参  数       |    描  述        | "
    echo "        +--------------------+------------------+ "
    echo "        |   -c | --clean     |   清除缓存       | "
    echo "        |   -o | --conda     |   更新 conda     | "
    echo "        |   -p | --python    |   更新 python    | "
    echo "        |   -m | --module    |   更新所有库     | "
    echo "        |   -a | --all       |   更新全部       | "
    echo "        |   -h | --help      |   使用帮助       | "
    echo "        +--------------------+------------------+ "
}


printf "\n================================================================================\n"
if [ "$#" -eq 0 ]; then
    usage
    exit 0
else
    flush_env
    case_argument "$@"
fi
printf "================================================================================\n\n"

exit 0
