#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  language-install
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
JAVA_HOME="/opt/java/jdk"                                                      # JAVA 默认安装路径 
PYTHON_HOME="/opt/python"                                                      # Python 默认安装路径 
SCALA_HOME="/opt/java/scala"                                                   # Scala  默认安装路径 
MAVEN_HOME="/opt/apache/maven"                                                 # Maven  默认安装路径 
GRADLE_HOME="/opt/apache/gradle"                                               # Gradle 默认安装路径 


# 刷新环境变量
function flush_env()
{
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    
    echo "    ************************** 刷新环境变量 **************************    "
    if [ -e "${HOME}/.bash_profile" ]; then
        source "${HOME}/.bash_profile"
    elif [ -e "${HOME}/.bashrc" ]; then
        source "${HOME}/.bashrc"
    fi
    
    source "/etc/profile"
    
    echo "    ************************** 获取公共函数 **************************    "
    # shellcheck source=./common.sh
    source "${ROOT_DIR}/bin/common.sh"
    
    export -A PARAM_LIST=()
    read_param "${ROOT_DIR}/conf/${CONFIG_FILE}"
}


# 根据文件名获取软件版本号（$1：下载软件包 url 的 key）
function get_version()
{
    local version
    
    version=$(get_name "$1" | grep -oP "\d*\.\d*\.\d+")
    
    echo "${version}" 
}


# 卸载系统自带的 OpenJdk
# shellcheck disable=SC2024
function uninstall_open_jdk()
{
    local password software_list software
    password=$(get_password)
    
    echo "    ******************************* 检查系统自带 OpenJdk *******************************    "
    # 获取系统安装的 OpenJdk
    software_list=$(echo "${password}" | sudo -S rpm -qa | grep -iE "java|jdk")
    if [ ${#software_list[@]} -gt 0 ]; then
        echo "    ******************************* 卸载系统自带 OpenJdk *******************************    "
        # 卸载系统安装的 MariaDB
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
    
    echo "    ************************* 开始安装 java *************************    "
    JAVA_HOME=$(get_param "java.home")                                         # 获取 Java 安装路径
    file_decompress "java.url" "${JAVA_HOME}"                                  # 解压 Java 安装包
    append_env "java.home" "1.8.361"                                           # 添加 Java 到环境变量
    
    echo "    ************************* 测试 java 安装 *************************    "
    java  -version                                                             # 测试 java
    javac -version                                                             # 测试 javac
}


# 安装并测试 Python，仅 rhel 7.*/8.* 使用
function python_install()
{
    local system_version src_folder version password 
    
    system_version=$(grep -i "linux" /etc/redhat-release | tr -cd '[0-9]\.' | awk -F '.' '{print $1}')
    if [[ "${system_version}" -lt "9" ]]; then
        echo "    ************************* 开始安装 Python *************************    "
        PYTHON_HOME=$(get_param "python.home")                                 # 获取 Python 安装路径
        file_decompress "python.url"                                           # 解压 Python 安装包
        
        echo "    *********************** 生成 Makefile 文件 ************************    "
        # 获取源码目录，斌进入该目录
        src_folder=$(cd "$(ls -F "${ROOT_DIR}/package" | grep "/$")" || exit; pwd)
        cd "${src_folder}" || exit 
        ./configure prefix="${PYTHON_HOME}" --enable-optimizations >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
        
        echo "    ************************* 编译安装 Python *************************    "
        # 编译并安装 Python
        cd "${src_folder}" && make          >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  
        cd "${src_folder}" && make install  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        
        version=$(get_version "python.url" | awk -F '.' '{print $2}')
        "${PYTHON_HOME}/bin/python3.${version}" -V                             # 查看 python 版本
        "${PYTHON_HOME}/bin/pip3.${version}"    -V                             # 查看 pip 版本
        
        echo "    *********************** 添加 Python 环境变量 ***********************    " 
        password=$(get_password)
        echo "${password}" | sudo -S rm /usr/bin/python                        # 删除原来的 python -> python2 软连接
        echo "${password}" | sudo -S ln -s /usr/bin/python2 /usr/bin/python2.7 # 重新创建 python2 的软连接
            
        # 修改 yum 使用的 python 版本
        echo "${password}" | sudo -S sed -i "s|#!\/usr\/bin\/python|#!\/usr\/bin\/python2.7|g" /usr/bin/yum 
        echo "${password}" | sudo -S sed -i "s|#!\/usr\/bin\/python|#!\/usr\/bin\/python2.7|g" /usr/libexec/urlgrabber-ext-down
        
        # 创建 python 和 pip 的软连接    
        echo "${password}" | sudo -S ln -s "${PYTHON_HOME}/bin/python3.${version}" /usr/bin/python
        echo "${password}" | sudo -S ln -s "${PYTHON_HOME}/bin/pip3.${version}"    /usr/bin/pip
        
        echo "    ************************* 测试 Python 安装 *************************    "
        # 测试 Python
        { echo "#!/usr/bin/env python3.x"; echo ""; echo "print(\"Hello World! \")"; echo ""; } >> "${ROOT_DIR}/logs/test.py"
        chmod +x "${ROOT_DIR}/logs/test.py"
        "${ROOT_DIR}/logs/test.py"
    else
        echo "    *********************** 系统已经安装 Python ***********************    "
    fi
}


# 修改 Python 的包管理工具 pip 相关配置
function pip_config()
{
    local password
    echo "    ************************* 开始设置 pip 镜像源 *************************    "
    password=$(get_password)
    
    mkdir -p "${HOME}/.pip"
    append_param "[global]"                                             "${HOME}/.pip/pip.conf"
    append_param "index-url = https://mirrors.aliyun.com/pypi/simple/"  "${HOME}/.pip/pip.conf"
    append_param "[install]"                                            "${HOME}/.pip/pip.conf"
    append_param "trusted-host=mirrors.aliyun.com"                      "${HOME}/.pip/pip.conf"  
    
    echo "${password}" | sudo -S cp -frp "${HOME}/.pip" /root/
    echo "${password}" | sudo -S pip install mycli  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
}


# 安装并测试 Scala
function scala_install()
{
    echo "    ************************* 开始安装 Scala *************************    "
    SCALA_HOME=$(get_param "scala.home")                                       # 获取 Scala 安装路径
    file_decompress "scala.url" "${SCALA_HOME}"                                # 解压 Scala 安装包
    append_env "scala.home" "2.12.18"                                          # 添加 Scala 到环境变量
    
    echo "    ************************* 测试 scala 安装 *************************    "
    scala  -version                                                            # 测试 Scala     
}


# 安装并测试 Maven
function maven_install()
{
    echo "    ************************* 开始安装 Maven *************************    "
    MAVEN_HOME=$(get_param "maven.home")                                       # 获取 Maven 安装路径
    file_decompress "maven.url" "${MAVEN_HOME}"                                # 解压 Maven 安装包
     
    echo "    ************************* 修改 Maven 为阿里云  *************************    "
    cp -fpr "${ROOT_DIR}/conf/maven-settings.xml" "${MAVEN_HOME}/conf/settings.xml"
    sed -i "s|\${MAVEN_HOME}|${MAVEN_HOME}|g"     "${MAVEN_HOME}/conf/settings.xml"
    
    echo "    ************************* 测试 Maven 安装 *************************    "
    append_env "maven.home" "3.8.8"                                            # 添加 Maven 到环境变量
    mvn -v                                                                     # 测试 Maven    
}


# 安装并测试 Gradle
function gradle_install()
{
    echo "    ************************* 开始安装 Gradle *************************    "
    GRADLE_HOME=$(get_param "gradle.home")                                     # 获取 Gradle 安装路径
    file_decompress "gradle.url" "${GRADLE_HOME}"                              # 解压 Gradle 安装包
    
    echo "    ************************* 修改 Gradle 为阿里云  *************************    "
    cp -fpr "${ROOT_DIR}/conf/gradle-gradle.properties" "${GRADLE_HOME}/gradle.properties"
    cp -fpr "${ROOT_DIR}/conf/gradle-init.gradle"       "${GRADLE_HOME}/init.gradle"
    cp -fpr "${ROOT_DIR}/conf/gradle-init.gradle"       "${GRADLE_HOME}/init.d/init.gradle"
    
    echo "    ************************* 测试 Gradle 安装 *************************    "
    append_env "gradle.home" "7.6.2"                                         # 添加 Gradle 到环境变量
    gradle  -version                                                            # 测试 Gradle
}


printf "\n================================================================================\n"
if [ "$#" -gt 0 ]; then
    flush_env                                                                  # 刷新环境变量    
fi

# 匹配输入参数
case "$1" in
    # 1. 安装 java 
    java | -j)
        java_install
    ;;
    
    # 2. 安装 scala 
    scala | -s)
        scala_install
    ;;
    
    # 3. 安装 python 
    python | -p)
        python_install
        pip_config
    ;;
    
    # 4. 安装 maven
    maven | -m)
        maven_install
    ;;
    
    # 5. 安装gradle
    gradle | -g)
        gradle_install
    ;;
    
    # 6. 安装必要的软件包
    all | -a)
        java_install
        scala_install
        python_install
        pip_config
        maven_install
        gradle_install
    ;;
    
    # 10. 其它情况
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
printf "================================================================================\n\n"
exit 0
