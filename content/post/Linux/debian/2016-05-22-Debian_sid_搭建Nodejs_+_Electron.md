---
layout: post
cid: 401
title: "Debian sid 搭建Nodejs + Electron"
slug: debian-sid-搭建nodejs-electron
date: 2016-05-22
updated: 2016-05-22
status: publish
draft: true
author: panda
categories: 
  - linux
tags: 
---




本来有包管理器安装Nodejs是很简单的，但是由于<b>古拉拉黑暗能量</b>的影响，npm下载几乎没速度。
方法如下：


<!--more-->


1.用包管理器安装Nodejs
<code lang='bash'>sudo apt-get install nodejs npm</code>
你以为就这么简单，Naive!
2.建立软链接
由于Debain打包规范，nodejs的命令行命令被命名为nodejs，而不是node。但是npm默认的在安装包的时候会调用node命令，所以会导致npm无法正常安装第三方包
```bash
sudo ln -s /usr/bin/nodejs  /usr/bin/node#建立软链接
```
3.切换npm到cnpm，一个开源项目。
cnpm是对npm的封装，据说有一些功能好像不能用 XD,但是其引用的是淘宝的npm镜像仓库，所以可以不受<strong>古拉拉黑暗能量</strong>的影响了
<a href="https://github.com/cnpm/cnpm" target="_blank">github:cnpm/cnpm</a>
```bash
sudo npm install cnpm -g --registry=https://registry.npm.taobao.org
```
使用npm的时候可以直接用cnpm了，或者直接建立个软链接替代npm也可以的～
4.安装Electron
Electron是一个跨平台的图形库，基于Node.js。大名鼎鼎的Atom也是用这货写的，当然，效率堪忧。
```bash
cnpm install --save-dev electron-prebuilt
```
