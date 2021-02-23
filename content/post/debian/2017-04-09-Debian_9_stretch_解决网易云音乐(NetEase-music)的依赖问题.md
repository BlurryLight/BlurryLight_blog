---
layout: post
cid: 415
title: "Debian 9 stretch 解决网易云音乐(NetEase-music)的依赖问题"
slug: 415
date: 2017-04-09
updated: 2019-01-03
status: publish
author: panda
categories: 
  - linux
tags: 
---


>明明记得stretch已经冻结了，于是无聊的时候直接从jessie升级上了stretch,内核升级到4.9带来了一堆问题，但是最麻烦的还是一些旧的软件包被废弃了，导致一些软件的依赖满足不了。


<!--more-->

[网易云音乐][1] 提供多种版本的客户端下载，我一开始记得用`Deepin`的版本比较好，这次也沿用了`deepin`的版本。Ubuntu 16.04的没测试，但是据说也可以通过同样的方法安装上。

## 1.安装软件包
`sudo apt isntall -f `一般用于解决依赖问题，不过这次由于依赖被废弃的原因所以就没办法了。先用`dpkg -i`安装上下载的软件包，然后记录下缺少的依赖，再用`apt remove `卸载掉网易云音乐，最后用`apt install`安装刚才缺少的依赖。最后会卡在`libqt5libqgtk2`这个依赖上（如果用ubuntu的deb的话应该还会缺失`libfontconfig1`）

## 2.手动解决依赖
```bash
没有可用的软件包 libqt5libqgtk2，但是它被其它的软件包引用了。
这可能意味着这个缺失的软件包可能已被废弃，
或者只能在其他发布源中找到
然而下列软件包会取代它：
  qt5-style-plugins:i386 qt5-style-plugins
```
这个软件包已经被`qt5-style-plugins`取代了，所以需要先`apt install qt5-style-plugins`.

### 拆包
```bash
# 先创建软件包目录
mkdir -p extract/DEBIAN
# 用dpkg解压
#注意，DEBIAN必须大写
dpkg-deb -x neteasemusic.deb extract/
dpkg-deb -e neteasemusic extract/DEBIAN
```
然后修改依赖
```bash
vim extract/DEBIAN/control
#在depends一栏，删除libqt5libqgtk2的依赖
```
重新打包
```bash
# 建立软件包生成目录
mkdir build
# 重新打包
dpkg-deb -b extract/ build/
```
打完的包会在build/目录下，使用`dpkg -i `安装即可。

### 但是，这样重新打包后仍然无法运行，主要是chrome-sandbox的权限设置问题(原因不明，对打包机制不了解)
要求`chrome-sandbox`必须属于`root:root`组，并权限必须是`4755`.
```
sudo chown root.root /usr/lib/netease-cloud-music/chrome-sandbox 
sudo chmod 4755 /usr/lib/netease-cloud-music/chrome-sandbox
```

文章转载，修改于:
debian安装网易云解决依赖问题 – FindSpace http://www.findspace.name/easycoding/1875#comment-1812

  [1]: https://music.163.com/#/download