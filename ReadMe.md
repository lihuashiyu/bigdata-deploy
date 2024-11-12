# bigdata-deploy

  主要是大数据各个组件的安装部署，以及编写的启停脚本，可用于大数据平台的搭建，做到从 0 开始进行大数据的学习

## 目录结构

```shell
    bigdata-deploy                                                             # 根目录
      ├──bin                                                                   # 部署脚本目录
      ├──conf                                                                  # 配置文件目录
      ├──doc                                                                   # 部署文档目录
      ├──lib                                                                   # 部署过程中使用到的 jar 
      ├──patch                                                                 # git 补丁
      └──script                                                                # 部署的软件启停脚本
              ├─apache                                                         # Apache  软件启停脚本
              ├─database                                                       # 数据库  软件启停脚本
              ├─elastic                                                        # Elastic 软件启停脚本
              ├─other                                                          # 其它    软件启停脚本
              └─system                                                         # 系统软件编译安装脚本
```
