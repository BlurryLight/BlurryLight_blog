---
layout: post
cid: 413
title: "Crouton安装Debian 9+xfce4后出现触摸板不能轻触点击的问题"
slug: 413
date: 2017-04-03
updated: 2019-01-03
status: publish
author: panda
categories: 
  - debian
tags: 
---


这个问题蛮少见的，因为完整安装Debian的话应该是会带这个驱动，但是利用Crouton安装出来的Debian没有，所以导致我的Chromebook在Linux下触摸板工作的不太正常。
```
sudo apt install xserver-xorg-input-synaptics
```
然后在xfce4的设置—鼠标与触摸板中会多出触摸板的选项。