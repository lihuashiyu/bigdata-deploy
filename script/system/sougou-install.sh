#!/usr/bin/env bash

# ==================================================================================================
#    FileName      ：  sougou-install.sh
#    CreateTime    ：  2025-02-11 16:08:34
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  Debian 系统安装搜狗输入法
# ==================================================================================================

SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../../" || exit; pwd)                            # 项目根目录
LOG_FILE="${ROOT_DIR}/logs/sougou-install-$(date +%F).log"                     # 程序操作日志文件
    
SOGOU_HOME="/opt/sogoupinyin"                                                  # 搜狗输入法安装路径
SOGOU_DEB="${ROOT_DIR}/lib/sogoupinyin_4.2.1.145_amd64.deb"                    # 搜狗输入法安装包
    
    
# 刷新环境变量
function flush_env()
{
    echo "    ************************** 刷新环境变量 **************************    "
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    
    # 检查是否以 root 身份运行
    if [ "$EUID" -ne 0 ]; then
        echo "    ***************** 请使用 sudo 或以 root 用户运行 ******************    "
        exit 1
    fi
    
    source "${HOME}/.bashrc"                                                   # 用户环境变量文件
    source "/etc/profile"                                                      # 系统环境变量文件路径
}
    
    
# 卸载 fcitx5 及其依赖
function remove_fcitx()
{
    echo "    ************************** 卸载 Fcitx5 **************************    "
    
    {
        apt purge      -y  fcitx5*                                             # 卸载 fcitx5 及其依赖
        apt autoremove -y                                                      # 自动删除无用软件
    }  >> "${LOG_FILE}" 2>&1
    
    if [ $? -ne 0 ]; then
        echo "    *************************** 卸载失败 ****************************    "
        exit 1
    fi
}
    
    
# 安装 fcitx4 输入法框架
function install_frame()
{
    echo "    ************************** 安装 Fcitx4 **************************    "
    
    {
        apt update                                                             # 更新缓存
        apt install -y fcitx fcitx-frontend-gtk2 fcitx-frontend-gtk3 fcitx-frontend-qt5 libgsettings-qt1 libqt5quickwidgets5 libqt5qml5 libqt5quick5 libqt5quickwidgets5 qml-module-qtquick2
        
        cp -fpr  /usr/share/applications/fcitx.desktop  /etc/xdg/autostart/    # 添加开机自启
    } >> "${LOG_FILE}" 2>&1

    if [ $? -ne 0 ]; then
            echo "    ************************** 安装框架失败 **************************    "
        exit 1
    fi
}


# 安装搜狗输入法
function install_sogou()
{
    echo "    ************************* 安装搜狗输入法 **************************    "
    {
        apt autoclean                                                              # 清除缓存
        apt update                                                                 # 更新缓存
        apt autoremove --purge   -y                                                # 自动删除无用联包
        
        apt --fix-broken install -y  "${SOGOU_DEB}"  >> "${LOG_FILE}" 2>&1         # 安装搜狗输入法
    } >> "${LOG_FILE}" 2>&1
        
    if [ $? -ne 0 ]; then
            echo "    ************************** 搜狗安装失败 **************************    "
        exit 1
    fi
}
    
    
# 修复搜狗库文件冲突：无法输入中文
function fix_lib()
{
    echo "    ************************** 修复依赖冲突 **************************    "
    local lib                                                                  # 定义局部变量
    local system_lib_dir="/usr/lib/x86_64-linux-gnu"                           # 系统库
    local sogou_lib_dir="${SOGOU_HOME}/files/lib/qt5/lib"                      # 搜狗 QT 库
    local sogou_plugin_dir="${SOGOU_HOME}/files/lib/qt5/plugins"               # 搜狗 Plugin 库
    
    local qt_list=(libQt5Core.so.5 libQt5Gui.so.5 libQt5Widgets.so.5 libQt5DBus.so.5 libQt5Qml.so.5 libQt5Network.so.5 libQt5Quick.so.5 libQt5QuickWidgets.so.5 libQt5Svg.so.5 libQt5XcbQpa.so.5 libFcitxQt5DBusAddons.so.1 libgsettings-qt.so.1 libpcre.so.3)
    local plugin_list=(iconengines/libqsvgicon.so imageformats/libqsvg.so platforminputcontexts/libfcitxplatforminputcontextplugin.so platforms/libqlinuxfb.so platforms/libqminimal.so platforms/libqoffscreen.so platforms/libqxcb.so xcbglintegrations/libqxcb-glx-integration.so)
    
    # 备份搜狗库
    if [ -d "${SOGOU_HOME}/back" ]; then
        mkdir -p    "${SOGOU_HOME}/back"                                       # 创建备份文件
        cp    -fpr  "${SOGOU_HOME}"/files/* "${SOGOU_HOME}/back"               # 备份文件
    fi
    
    # QT 库修复
    for lib in "${qt_list[@]}"
    do
        rm -f  "${sogou_lib_dir}/${lib}"                                       # 删除 QT 冲突库
        ln -s  "${system_lib_dir}/${lib}" "${sogou_lib_dir}/${lib}"            # 创建 QT 软链接
    done
    
    # 插件库修复
    for lib in "${plugin_list[@]}"
    do
        rm -f  "${sogou_plugin_dir}/${lib}"                                         # 删除 Plugin 冲突库
        ln -s  "${system_lib_dir}/qt5/plugins/${lib}" "${sogou_plugin_dir}/${lib}"  # 创建 Plugin 软链接
    done
    
    if [ $? -ne 0 ]; then
            echo "    ************************** 依赖修复失败 **************************    "
        exit 1
    fi
}
    
    
# 配置输入法环境变量
function set_env()
{
    echo "    ************************** 配置网卡信息 **************************    "
    local sogou_conf="/etc/environment.d/sogou.conf"                           # 定义局部变量
    
    echo "GTK_IM_MODULE=fcitx"   >   "${sogou_conf}"                           # 添加 GTK 配置
    echo "QT_IM_MODULE=fcitx"    >>  "${sogou_conf}"                           # 添加 QT  配置
    echo "XMODIFIERS=@im=fcitx"  >>  "${sogou_conf}"                           # 添加 XM  配置
    
    im-config -n fcitx           >> "${LOG_FILE}" 2>&1                         # 更新输入法配置
    # chown -R "${USER}:${USER}"   "${SOGOU_HOME}"                             # 修改安装目录权限
    
    if [ $? -ne 0 ]; then
            echo "    ************************** 依赖修复失败 **************************    "
        exit 1
    else
        echo "    ==+==+==+==> 安装完成，请执行以下操作：    "
        echo "    ==+==+==+==> 1. KDE 添加 fcitx 自启动    "
        echo "    ==+==+==+==> 2. 重启系统；    "
        echo "    ==+==+==+==> 3. 修改配置：配置 -> 输入法 -> 选择搜狗拼音"
        echo "    ==+==+==+==> 4. 默认切换快捷键为 Ctrl + 空格"
    fi
}
    
    
# 脚本使用说明
function usage()
{
    echo "    脚本可传入的参数如下所示：     "
    echo "        +--------------------+--------------+ "
    echo "        |       参  数       |    描  述    | "
    echo "        +--------------------+--------------+ "
    echo "        |   -r | --remove    |   卸载冲突   | "
    echo "        |   -f | --frame     |   安装框架   | "
    echo "        |   -i | --install   |   安装搜狗   | "
    echo "        |   -x | --fix       |   修复依赖   | "
    echo "        |   -s | --set       |   配置环境   | "
    echo "        |   -h | --help      |   帮助信息   | "
    echo "        |   -a | --all       |   执行全部   | "
    echo "        +--------------------+--------------+ "
}
    
    
# 匹配输入参数
function case_argument()
{
    case "$1" in
        r | remove | -r | --remove)                                            # 卸载 fcitx5 及其依赖
            remove_fcitx
        ;;
        
         f | frame | -f | --frame)                                             # 安装 fcitx4 输入法框架
            install_frame
        ;;
         
        i | install | -i | --install)                                          # 安装搜狗输入法
            install_sogou
        ;;
        
        x | fix | -x | --fix)                                                  # 修复搜狗库文件冲突
            fix_lib
        ;;
        
        s | set | -s | --set)                                                  # 配置输入法环境变量
            set_env
        ;;
        
        h | help | -h | --help)                                                # 使用说明
            usage
            exit 1
        ;;
        
        a | all | -a | --all)                                                  # 执行所有程序
            remove_fcitx
            install_frame
            install_sogou
            fix_lib
            set_env
        ;;
        
        *)                                                                     # 错误参数
            usage
            return
        ;;
    esac
}
    
    
printf "\n================================================================================\n"
# 判断输入参数
if [ "$#" -gt 0 ]; then
    flush_env                                                                  # 刷新环境变量
    
    for argument in "$@"
    do
        case_argument "${argument}"                                            # 执行输入参数
    done
    
    echo "    +-----------------------------------------+"
    echo "    |        重启生效：shutdown -r now        |"
    echo "    +-----------------------------------------+"
else
    usage
fi
printf "================================================================================\n\n"
exit 0
