---
layout: post
cid: 380
title: "解决Debian和windows相差八小时的问题"
slug: 解决debian和windows相差八小时的问题
date: 2016-04-10
updated: 2016-04-10
status: publish
author: panda
categories: 
  - linux
tags: 
---


windows在查询时间时，采用读取<em>CMOS</em>时间作为标准时间,而Linux如果采用UTC（世界协调时）时间，则会在读取CMOS时间后，按照时区（北京时间为东八区）来计算时间，所以如果不小心在Linux中启用了UTC时间，就总是会和windows相差八小时。


<!--more-->


<strong>解决办法如下：</strong>
在Debian7以后，关于时间的配置文件从/etc/default/rcS中移到了/etc/adjtime。
```bash
vim /etc/adjtime
将UTC替换为LOCAL
```
如果没有adjtime这个文件
```bash
sudo hwclock --adjust#生成文件
```

完成以后，
```bash
sudo hwclock --hctosys
```
将时间写入CMOS
