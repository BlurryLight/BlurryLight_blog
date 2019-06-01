---
layout: post
cid: 369
title: "关于chromebook在安装crouton后没有声音的解决办法"
slug: 关于chromebook在安装crouton后没有声音的解决办法
date: 2016-03-25
updated: 2017-08-03
status: publish
author: panda
categories: 
  - debian
tags: 
---


<blockquote>
  最近去弄了一台chromebook回来，13寸1080p屏幕，8小时以上的超级续航，不到200刀的价格，Linux原生支持，这价格也没有谁可以比了.
</blockquote>


<!--more-->


用Crouton安装了熟悉的Debian后，遇到了没有声音的问题，alsa也无法正常工作，初步判断是驱动出了问题
在Crouton的issue发现了和我同样问题的人，解决办法如下：
```bash
sudo sh -e ~/Downloads/crouton -u -n jessie ＃升级chroot到最新版
```
友情提示：这里是需要翻墙的。这里在升级的过程中需要下载一个声卡驱动，而这个声卡驱动需要经过谷歌的服务器。可以先用ChromeOs连上VPN,或者使用修改过的Crouton，或者手动下载那个驱动，然后修改Crouton脚本直接指定位置。

<h2>附上备注：</h2>

<strong>备份</strong>：
```bash
sudo edit-chroot -b chrootname
```
<strong>注意：打包文件***.tar.gz放在Downloads文件夹，但是一定要把它拷贝到别处或者上传云盘，否则万一chrome OS崩溃，这个文件夹的东西就全没了。</strong>
<strong>恢复</strong>:
```bash
sudo sh -e ~/Downloads/crouton -f ~/Downloads/***.tar.gz
```
PS：
用了几天的ChromeOS，早年也在自己的实机上使用过，但是用的时候还不够成熟，但现在的ChromeOS在有了切换Linux的强力后援下，在操作系统内热切换，且依然拥有着强劲续航，不像MBA那样换了系统续航就如尿崩。
