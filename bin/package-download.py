#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""=================================================================================================
    ProjectName   ：  bigdata-deploy
    FileName      ：  package-download
    CreateTime    ：  2023-07-29 20:59:36
    Author        ：  lihua_shiyu
    Email         ：  lihuashiyu@github.com
    PythonCompiler：  3.9.13
    Description   ：  下载软件包，以及 爬取 AliYun 镜像的 epel 等 rpm_dict 包
================================================================================================="""

import os
import sys
import requests
from typing import Dict, List
from bs4 import BeautifulSoup
from contextlib import closing


class Config:
    def __init__(self):
        self.HEADERS_DICT = \
            {
                "Accept": "*/*",
                "Accept-Encoding": "gzip, deflate, br",
                "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6",
                "Origin": "https://mirrors.aliyun.com",
                "Referer": "https://mirrors.aliyun.com/",
                "Sec-Ch-Ua": "\"Not.A/Brand\";v=\"8\", \"Chromium\";v=\"114\", \"Microsoft Edge\";v=\"114\"",
                "Sec-Ch-Ua-Mobile": "?0",
                "Sec-Ch-Ua-Platform": "\"Windows\"",
                "Sec-Fetch-Dest": "empty",
                "Sec-Fetch-Mode": "cors",
                "Sec-Fetch-Site": "same-site",
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51"
            }
        
        self.ALIYUN_EPEL_URL = "https://mirrors.aliyun.com/epel/9/Everything/x86_64/Packages/"
        self.ALIYUN_PYPI_URL = "https://mirrors.aliyun.com/pypi/simple/"
        
        self.PARAM_DICT = \
            {
                "spm": "a2c6h.25603864.0.0.7bcf427bOOzHCP"
            }
        
        
class ExtraPackagesEnterpriseLinux:
    def __init__(self, url: str, header_dict: Dict[str, str], param_dict: Dict[str, str]) -> None:
        self.url = url
        self.header_dict = header_dict
        self.param_dict = param_dict
    
    def query_dir(self) -> List[str]:
        response = requests.get(url=self.url, headers=self.header_dict, params=self.param_dict)
        soup = BeautifulSoup(response.text, "lxml")
        content_list = soup.select("tbody td[class=link] a[href]")
        
        rpm_dir_list = []
        for content in content_list:
            rpm_dir = content.contents[0]
            if "parent" not in rpm_dir.lower():
                rpm_dir_list.append(f"{self.url.strip('/')}/{rpm_dir}")
        
        return rpm_dir_list
    
    def get_rpm_url(self, rpm_dir: str) -> List[Dict[str, str]]:
        response = requests.get(url=rpm_dir, headers=self.header_dict, params=self.param_dict)
        soup = BeautifulSoup(response.text, "lxml")
        name_list = soup.select("tbody td[class=link] a[href]")
        size_list = soup.select("tbody td[class=size]")
        date_list = soup.select("tbody td[class=date]")
        
        rpm_info_list = []
        for l in range(len(name_list)):
            rpm_info = {}
            rmp_name = name_list[l].text
            if "parent" not in rmp_name.lower():
                rpm_info["name"] = rmp_name
                rpm_info["size"] = size_list[l].text
                rpm_info["date"] = date_list[l].text
                rpm_info["url"] = f"{rpm_dir.strip('/')}/{rmp_name}"
                rpm_info_list.append(rpm_info)
                
        return rpm_info_list

    def rpm_download(self, rpm_url: str, path: str) -> None:
        dir_name, file_name = os.path.split(os.path.abspath(sys.argv[0]))        
        absolute_path = os.path.abspath(f"{dir_name.rstrip('/')}/{path}")
        
        with closing(requests.get(rpm_url, headers=self.header_dict, stream=True)) as response:
            chunk_size = 1024
            with open(file=absolute_path, mode="wb") as file:
                for data in response.iter_content(chunk_size=chunk_size):
                    file.write(data)
                    

if __name__ == '__main__':
    config = Config()
    epel = ExtraPackagesEnterpriseLinux(url=config.ALIYUN_EPEL_URL, header_dict=config.HEADERS_DICT, param_dict=config.PARAM_DICT)
    dir_list = epel.query_dir()
    for dir in dir_list:
        for rpm_dict in epel.get_rpm_url(rpm_dir=dir):
            print(f"rpm_dict ===> {rpm_dict}")
            epel.rpm_download(rpm_url=rpm_dict["url"], path=f"../logs/{rpm_dict['name']}")
            
