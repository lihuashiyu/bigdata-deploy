## 1. 编译安装 GCC 12.3.0

### 1.1 源码下载 

从 [**GNU 阿里云镜像网站**](https://mirrors.aliyun.com/gnu/) 下载 **[gcc-12.3.0](https://mirrors.aliyun.com/gnu/gcc/gcc-12.3.0/gcc-12.3.0.tar.gz)** 到本地

```bash
    wget https://mirrors.aliyun.com/gnu/gcc-12.3.0.tar.gz
```

### 1.2 安装必要的工具包

```bash
    sudo dnf update                                                                           # 更新源
    sudo dnf install -y gcc gcc-c++ kernel-devel pcsc-lite-libs elfutils-libelf-devel make    # redhat 系列
    sudo dnf install -y zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel
    sudo dnf install -y libffi-devel zlib1g-dev zlib* 
    
    sudo apt update                                                                           # 更新源
    sudo apt install -y gcc gcc-c++ kernel-devel pcsc-lite-libs elfutils-libelf-devel make    # debian 系列
    sudo apt install -y zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel
    sudo apt install  -y libffi-devel zlib1g-dev zlib* 
```

### 1.3 解压并下载必要的依赖源码

```bash
    tar -zxvf gcc-12.3.0.tar.gz                                                # 解压源码包
    cd gcc-12.3.0 || exit                                                      # 进入解压的源码
    ./contrib/download_prerequisites                                           # 下载所需要的配置
```

### 1.4 编译安装

```bash
    cd gcc-12.3.0 || exit                                                      # 进入解压的源码
    ./configure  -prefix=/opt/gcc --enable-checking=release --enable-languages=c,c++ --disable-multilib # 生成 Makefile 文件
    make -j6                                                                   # 使用 6 个逻辑核心进行编译
    make install                                                               # 安装
```

### 1.5 创建环境变量和软连接

```bash
    cd /opt/gcc || exit                                                        # 进入安装目录
    /opt/gcc/bin/gcc -v                                                        # 查看 gcc 版本
    /opt/gcc/bin/g++ -v                                                        # 查看 g++ 版本
    
    sudo ln -s /opt/gcc/bin/gcc /usr/bin/gcc12                                 # 创建 gcc 的软连接
    sudo ln -s /opt/gcc/bin/g++ /usr/bin/g++12                                 # 创建 g++ 的软连接
```

### 1.6 测试安装结果

```bash
    # 编写 hello.c 并进行编译
    #include <stdio.h>
    int main()
    {
        printf("Hello World!");
        return 0;
    }
    
    gcc12 -Wall hello.c -o hello                                               # 用 gcc 编译 
    ./hello                                                                    # 运行编译结果
```

<br>

## 2. 编译安装 Python 3.9

### 2.1 源码下载

从 [**Python 官网**](https://www.python.org/) 下载源码到本地，ubuntu 20.* 自带 3.8，redhat 7 系列自带 2.7.6，redhat 8 系列自带 2.7.18，redhat 9 系列自带 3.9 

```bash
    wget https://www.python.org/ftp/python/3.11.4/Python-3.11.4.tgz            # 下载 Python-3.11.4 源码 
    wget https://www.python.org/ftp/python/3.10.11/Python-3.10.11.tgz          # 下载 Python-3.10.11 源码 
    wget https://www.python.org/ftp/python/3.9.17/Python-3.9.17.tgz            # 下载 Python-3.9.17 源码 
    wget https://www.python.org/ftp/python/3.8.17/Python-3.8.17.tgz            # 下载 Python-3.8.17 源码 
    wget https://www.python.org/ftp/python/3.7.17/Python-3.7.17.tgz            # 下载 Python-3.7.17 源码
```

### 2.2 编译安装

```bash
    tar -zxvf Python-3.9.17.tgz                                                # 解压源码包
    cd Python-3.9.17 || exit                                                   # 进入解压的源码
    ./configure prefix=/opt/python --enable-optimizations                      # 生成 Makefile 文件
    
    make && make install                                                       # 编译并安装
```

### 2.3 创建环境变量和软连接

```bash
    /opt/python/bin/python3.9 -V                                               # 查看 python 版本
    /opt/python/bin/pip3.9 -V                                                  # 查看 pip 版本
    
    sudo rm /usr/bin/python                                                    # 删除原来的 python -> python2 软连接
    sudo ln -s /usr/bin/python2 /usr/bin/python2.7                             # 重新创建 python2 的软连接
    
    vim /usr/bin/yum                                                           # 修改 yum 使用的 python 版本
        #!/usr/bin/python ==> #!/usr/bin/python2.7
    vim /usr/libexec/urlgrabber-ext-down                                       # 修使用的 python 版本
        #!/usr/bin/python ==> #!/usr/bin/python2.7
    
    sudo ln -s /opt/python/bin/python3.9 /usr/bin/python                       # 创建 python 的软连接
    sudo ln -s /opt/python/bin/pip3.9 /usr/bin/pip                             # 创建 pip 的软连接
```

### 2.4 测试 hello

```bash
    echo '#!/usr/bin/env python'   >> hello.py
    echo '# -*- coding: utf-8 -*-' >> hello.py
    echo 'print("hello")'          >> hello.py
    
    chmod +x hello.py                                                          # 添加可执行权限
    ./hello.py                                                                 # 运行测试脚本
```

### 2.5 修改 pip 为国内源

```bash
    mkdir -p ~/.pip/                                                           # 创建 pip 配置文件路径
    
    # 修改为 清华源
    echo "[global]"                                             >> ~/.pip/pip.conf 
    echo "index-url = https://pypi.tuna.tsinghua.edu.cn/simple" >> ~/.pip/pip.conf 
    echo "[install]"                                            >> ~/.pip/pip.conf 
    echo "trusted-host = https://pypi.tuna.tsinghua.edu.cn"     >> ~/.pip/pip.conf    
    
    # 修改为 阿里源
    echo "[global]"                                             >> ~/.pip/pip.conf 
    echo "index-url = https://mirrors.aliyun.com/pypi/simple/"  >> ~/.pip/pip.conf 
    echo "[install]"                                            >> ~/.pip/pip.conf 
    echo "trusted-host=mirrors.aliyun.com"                      >> ~/.pip/pip.conf 
```

<br>

## 3. 编译安装 git 

### 3.1 源码下载

从 [**GitHub 官网**](https://github.com) 或 **[git 官网](https://git-scm.com/downloads)** 下载源码到本地

```bash
    wget https://github.com/git/git/archive/refs/tags/v2.39.2.tar.gz           # GitHub 官网
    wget https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.39.2.tar.gz     # git 官网
```

### 3.2 编译安装

```bash
    tar -zxvf git-2.39.2.tar.gz                                                # 解压源码包
    cd git-2.39.2 || exit                                                      # 进入解压的源码
    
    make prefix=/opt/github/git all                                            # 指定安装路径编译
    make prefix=/opt/github/git install                                        # 安装到指定路径
```

### 3.3 测试编译结果

```bash
    /opt/github/bin/git -v                                                     # 查看 git 版本
    sudo ln -s /opt/github/bin/git /usr/bin/git                                # 创建 git 的软连接
```

<br>

## 4. 安装 htop

### 4.1 源码下载

从 [**GitHub 官网**](https://github.com/) 下载 或 **[htop-3.2.2](https://github.com/htop-dev/htop/releases/download/3.2.2/htop-3.2.2.tar.xz)** 的源码到本地

```bash
    wget https://github.com/htop-dev/htop/releases/download/3.2.2/htop-3.2.2.tar.xz      # 下载 Python-3.10.10 源码
```

### 4.2 编译安装

```bash
    tar -Jzvf htop-3.2.2.tar.xz                                                # 解压源码包
    cd htop-3.2.2 || exit                                                      # 进入解压的源码
    
    ./configure -prefix=/opt/htop                                              # 生成 Makefile 
    make  &&  make install                                                     # 编译并安装到
```

### 4.3 测试编译结果

```bash
    /opt/htop/bin/htop                                                         # 查看
    sudo ln -s /opt/htop/bin/htop /usr/bin/htop                                # 创建 git 的软连接
```

<br>
