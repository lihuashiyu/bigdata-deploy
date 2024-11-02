#!/usr/bin/env bash
# shellcheck disable=SC2024

# =========================================================================================
#    FileName      ：  language-install.sh
#    CreateTime    ：  2023-07-10 09:17:31
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  安装开发所用的语言包以及相关工具
# =========================================================================================


SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="language-install-$(date +%F).log"                                    # 程序操作日志文件
USER=$(whoami)                                                                 # 当前登录使用的用户


# 刷新环境变量
function flush_env()
{    
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    
    echo "    ************************** 刷新环境变量 **************************    "
    # 判断用户环境变量文件是否存在
    if [ -e "${HOME}/.bash_profile" ]; then
        source "${HOME}/.bash_profile"                                         # RedHat 用户环境变量文件
    elif [ -e "${HOME}/.bashrc" ]; then
        source "${HOME}/.bashrc"                                               # Debian、RedHat 用户环境变量文件
    fi
    
    source "/etc/profile"                                                      # 系统环境变量文件路径
    
    echo "    ************************** 获取公共函数 **************************    "
    # shellcheck source=./common.sh
    source "${ROOT_DIR}/bin/common.sh"                                         # 当前程序使用的公共函数
    
    export -A PARAM_LIST=()                                                    # 初始化 配置文件 参数
    read_param "${ROOT_DIR}/conf/${CONFIG_FILE}"                               # 读取配置文件，获取参数    
}


# 卸载系统自带的 OpenJdk
function uninstall_open_jdk()
{
    local password software_list software                                      # 定义局部变量
    password=$(get_password)                                                   # 获取管理员密码
    
    echo "    ********************** 检查系统自带 OpenJdk **********************    "
    # 获取系统安装的 OpenJdk
    software_list=$(echo "${password}" | sudo -S rpm -qa | grep -iE "java|jdk")
    if [ ${#software_list[@]} -gt 0 ]; then
        echo "    ********************** 卸载系统自带 OpenJdk **********************    "
        # 卸载系统安装的 OpenJdk
        for software in ${software_list}
        do
             echo "${password}" | sudo -S rpm -e --nodeps "${software}" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        done 
    fi
}


# 安装并测试 java
function java_install()
{
    uninstall_open_jdk                                                         # 卸载系统自带的 OpenJdk
    local java_version password test_count                                     # 定义局部变量
    
    echo "    ************************* 开始安装 java **************************    "
    JAVA_HOME=$(get_param "java.home")                                         # 获取 Java 安装路径
    java_version=$(get_version "java.url")                                     # 获取 Java 版本号
    password=$(get_password)                                                   # 获取管理员密码
    
    download        "java.url"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1        # 下载 Java 安装包
    file_decompress "java.url" "${JAVA_HOME}"                                  # 解压 Java 安装包
    
    append_env "java.home" "${java_version}"                                   # 添加 Java 到环境变量
    append_param "export CLASSPATH=.:\${JAVA_HOME}/lib/*.jar:\${JAVA_HOME}/lib/*.jar:\${CLASSPATH}" "/etc/profile.d/${USER}.sh"
    append_param " "                                                                            "/etc/profile.d/${USER}.sh"
    
    echo "    ************************* 测试 java 安装 *************************    "
    { java  -version; javac -version; }  > "${ROOT_DIR}/logs/java-test.log" 2>&1 
    
    test_count=$(grep -nic "java" "${ROOT_DIR}/logs/java-test.log")
    if [ "${test_count}" -eq 4 ]; then
        echo "    **************************** 安装成功 ****************************    "
    else    
        echo "    **************************** 安装失败 ****************************    "
    fi
}


# 安装并测试 Python，仅 rhel 7.*/8.* 使用
function python_install()
{
    local system_version src_folder version password test_count                # 定义局部变量
    
    system_version=$(grep -i "linux" /etc/redhat-release | tr -cd '[0-9]\.' | awk -F '.' '{print $1}')
    if [[ "${system_version}" -lt "9" ]]; then
        echo "    ************************* 开始安装 Python *************************    "
        PYTHON_HOME=$(get_param "python.home")                                 # 获取 Python 安装路径
        download        "python.url"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  # 下载 Python 源码
        file_decompress "python.url"                                           # 解压 Python 安装包
        
        echo "    *********************** 生成 Makefile 文件 ************************    "
        src_folder=$(find "${ROOT_DIR}/package"/*  -maxdepth 0 -type d -print) # 获取 Python 源码的绝对路径
        cd "${src_folder}" || exit                                             # 进入 Python 源码目录
        # 设置 Python 安装路径
        ./configure prefix="${PYTHON_HOME}" --enable-optimizations >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
        
        echo "    ************************* 编译安装 Python *************************    "
        {
            cd "${src_folder}" || exit                                         # 进入 Python 源码目录
            make                                                               # 编译 Python 源码  
            make install                                                       # 安装 Python 二进制
        }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        
        version=$(get_version "python.url" | awk -F '.' '{print $2}')          # 获取 python 版本号
        {
            "${PYTHON_HOME}/bin/python3.${version}" -V                         # 查看 python 版本
            "${PYTHON_HOME}/bin/pip3.${version}"    -V                         # 查看 pip 版本
        } >> "${ROOT_DIR}/logs/python-test.log" 2>&1
        
        test_count=$(grep -nic "${version}" "${ROOT_DIR}/logs/python-test.log")
        if [ "${test_count}" -ne 2 ]; then
            echo "    ************************** 编译安装失败 ***************************    "
            return 1
        fi
        
        echo "    ********************** 添加 Python 环境变量 ***********************    " 
        password=$(get_password)
        echo "${password}" | sudo -S rm    /usr/bin/python                     # 删除原来的 python -> python2 软连接
        echo "${password}" | sudo -S ln -s /usr/bin/python2 /usr/bin/python2.7 # 重新创建 python2 的软连接
            
        # 修改 yum 使用的 python 版本
        echo "${password}" | sudo -S sed -i "s|#!\/usr\/bin\/python|#!\/usr\/bin\/python2.7|g" /usr/bin/yum 
        echo "${password}" | sudo -S sed -i "s|#!\/usr\/bin\/python|#!\/usr\/bin\/python2.7|g" /usr/libexec/urlgrabber-ext-down
        
        # 创建 python 和 pip 的软连接
        echo "${password}" | sudo -S ln -s "${PYTHON_HOME}/bin/python3.${version}" /usr/bin/python
        echo "${password}" | sudo -S ln -s "${PYTHON_HOME}/bin/pip3.${version}"    /usr/bin/pip
        
        echo "    ************************ 测试 Python 安装 *************************    "
        # 测试 Python
        { echo "#!/usr/bin/env python"; echo ""; echo "print(\"Hello Python ${version}! \")"; echo ""; } >> "${ROOT_DIR}/logs/test.py"
        chmod +x "${ROOT_DIR}/logs/test.py"                                    # 给文件添加执行权限
        test_count=$("${ROOT_DIR}/logs/test.py" | grep -ci "${version}!")      # 获取执行后的结果
        
        if [ "${test_count}" -eq 1 ]; then
            echo "    **************************** 安装成功 ****************************    "
        else    
            echo "    **************************** 安装失败 ****************************    "
        fi
    else
        echo "    *********************** 系统已经安装 Python ***********************    "
    fi
}


# 修改 Python 的包管理工具 pip 相关配置
function pip_config()
{
    echo "    *********************** 开始设置 pip 镜像源 ***********************    "
    local password                                                             # 定义局部变量
    password=$(get_password)                                                   # 获取管理员密码
    mkdir -p "${HOME}/.pip"                                                    # 创建必要的目录
    cat /dev/null > "${HOME}/.pip/pip.conf"                                    # 创建配置文件
    
    # 修改当前用户的 pip 镜像源
    append_param "[global]"                                             "${HOME}/.pip/pip.conf"
    append_param "index-url = https://mirrors.aliyun.com/pypi/simple/"  "${HOME}/.pip/pip.conf"
    append_param "[install]"                                            "${HOME}/.pip/pip.conf"
    append_param "trusted-host=mirrors.aliyun.com"                      "${HOME}/.pip/pip.conf"  
    
    # 修改当 root 的 pip 镜像源
    echo "${password}" | sudo -S cp -frp "${HOME}/.pip" /root/
    echo "${password}" | sudo -S pip install mycli  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
}


# 安装并测试 Scala
function scala_install()
{
    echo "    ************************* 开始安装 Scala *************************    "
    local scala_version test_count                                             # 定义局部变量
    
    SCALA_HOME=$(get_param "scala.home")                                       # 获取 Scala 安装路径
    scala_version=$(get_version "scala.url")                                   # 获取 Scala 版本号
    
    download        "scala.url"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1       # 下载 Scala 安装包
    file_decompress "scala.url" "${SCALA_HOME}"                                # 解压 Scala 安装包
    
    append_env "scala.home" "${scala_version}"                                 # 添加 Scala 到环境变量
    
    echo "    ************************ 测试 scala 安装 *************************    "
    scala -version  > "${ROOT_DIR}/logs/scala-test.log" 2>&1                   # 获取 Scala 版本
    test_count=$(grep -ci "${scala_version}" "${ROOT_DIR}/logs/scala-test.log") 
    
    if [ "${test_count}" -eq 1 ]; then
        echo "    **************************** 安装成功 ****************************    "
    else    
        echo "    **************************** 安装失败 ****************************    "
    fi    
}


# 安装并测试 Maven
function maven_install()
{
    echo "    ************************* 开始安装 Maven **************************    "
    local maven_version test_count                                             # 定义局部变量
    
    MAVEN_HOME=$(get_param "maven.home")                                       # 获取 Maven 安装路径
    maven_version=$(get_version "maven.url")                                   # 获取 Maven 版本号
    
    download        "maven.url"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1       # 下载 Maven 软件包
    file_decompress "maven.url" "${MAVEN_HOME}"                                # 解压 Maven 安装包
     
    echo "    *********************** 修改 Maven 为阿里云 ***********************    "
    cp -fpr "${ROOT_DIR}/conf/maven-settings.xml" "${MAVEN_HOME}/conf/settings.xml"
    sed -i "s|\${MAVEN_HOME}|${MAVEN_HOME}|g"     "${MAVEN_HOME}/conf/settings.xml"
    
    echo "    ************************* 测试 Maven 安装 *************************    "
    append_env "maven.home" "${maven_version}"                                 # 添加 Maven 到环境变量
    
    test_count=$(mvn -v | grep -ci "${maven_version}")                         # 测试 Maven 
    if [ "${test_count}" -eq 1 ]; then
        echo "    **************************** 安装成功 ****************************    "
    else    
        echo "    **************************** 安装失败 ****************************    "
    fi           
}


# 安装并测试 Gradle
function gradle_install()
{
    echo "    ************************ 开始安装 Gradle *************************    "
    local gradle_version test_count                                            # 定义局部变量
    
    GRADLE_HOME=$(get_param "gradle.home")                                     # 获取 Gradle 安装路径
    gradle_version=$(get_version "gradle.url")                                  # 获取 Maven 版本号
    
    download        "gradle.url"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1      # 下载 Gradle 安装包
    file_decompress "gradle.url" "${GRADLE_HOME}"                              # 解压 Gradle 安装包
    
    echo "    ********************** 修改 Gradle 为阿里云 **********************    "
    cp -fpr "${ROOT_DIR}/conf/gradle-gradle.properties" "${GRADLE_HOME}/gradle.properties"
    cp -fpr "${ROOT_DIR}/conf/gradle-init.gradle"       "${GRADLE_HOME}/init.gradle"
    cp -fpr "${ROOT_DIR}/conf/gradle-init.gradle"       "${GRADLE_HOME}/init.d/init.gradle"
    
    echo "    ************************ 测试 Gradle 安装 ************************    "
    append_env "gradle.home" "${gradle_version}"                               # 添加 Gradle 到环境变量
    
    test_count=$(gradle  -version | grep -ci "${gradle_version}")              # 测试 Maven 
    if [ "${test_count}" -eq 1 ]; then
        echo "    **************************** 安装成功 ****************************    "
    else    
        echo "    **************************** 安装失败 ****************************    "
    fi     
}


printf "\n================================================================================\n"
# 1. 获取脚本执行开始时间
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 2. 刷新变量
if [ "$#" -gt 0 ]; then
    export JAVA_HOME PYTHON_HOME SCALA_HOME MAVEN_HOME GRADLE_HOME 
    flush_env                                                                  # 刷新环境变量    
fi

# 3. 匹配输入参数
case "$1" in
    # 3.1 安装 java 
    java | -j)
        java_install
    ;;
    
    # 3.2 安装 scala 
    scala | -s)
        scala_install
    ;;
    
    # 3.3 安装 python 
    python | -p)
        python_install
        pip_config
    ;;
    
    # 3.4 安装 maven
    maven | -m)
        maven_install
    ;;
    
    # 3.5 安装gradle
    gradle | -g)
        gradle_install
    ;;
    
    # 3.6 安装所有
    all | -a)
        java_install
        scala_install
        python_install
        pip_config
        maven_install
        gradle_install
    ;;
    
    # 3.7 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：   "
        echo "        +----------+-------------------+ "
        echo "        |  参  数  |      描   述      |  "
        echo "        +----------+-------------------+ "
        echo "        |    -j    |   安装 java       | "
        echo "        |    -s    |   安装 scala      | "
        echo "        |    -p    |   安装 python     | "
        echo "        |    -m    |   安装 maven      | "
        echo "        |    -g    |   安装 gradle     | "
        echo "        |    -a    |   安装以上所有    | "
        echo "        +----------+-------------------+ "
    ;;
esac

# 4. 获取脚本执行结束时间，并计算脚本执行时间
end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)
if [ "$#" -ge 1 ]; then
    echo "    脚本（$(basename "$0")）执行共消耗：$(( end - start ))s ...... "
fi

printf "================================================================================\n\n"
exit 0
