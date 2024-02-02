#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
====================================================================================================
    ProjectName   ：  bigdata-deploy
    FileName      ：  rename.py
    CreateTime    ：  2024-02-01 22:32:38
    ModifiedTime  ：  2024-02-01 23:14:14
    Author        ：  lihua shiyu
    Email         ：  lihuashiyu@github.com
    Description   ：  重命名 nginx 上传文件，pip install bottle
====================================================================================================
"""

from bottle import run
from bottle import os
from bottle import post
from bottle import request


@post("/upload")
def fix_update_file_name():
    old_name = request.forms.get("file.name")
    full_name = request.forms.get("file.path")
    path = os.path.join(full_name, os.path.pardir)
    dir = os.path.abspath(path=path)
    os.rename(full_name, os.path.join(dir, old_name))
    
    return "ok"


if __name__ == '__main__':
    run(host='aliyun', port=47723)
