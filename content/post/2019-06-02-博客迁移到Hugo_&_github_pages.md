---
title: "博客迁移到Hugo & github pages"
date: 2019-06-02T10:30:01+08:00
draft: false
# tags: [ "" ]
categories: [ "hugo"]
# keywords: [ ""]
lastmod: 2019-06-02T10:30:01+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "博客迁移到Hugo & github pages"
---

## 迁移原因

原来的服务器体验了一把GFW VIP待遇，先是被TCP阻断，随后直接IP block了。幸亏没有被DNS污染，不然就浪费了我辛辛苦苦想的域名
了。不过服务器维护起来也很费劲，加上原有的`typecho`的`stable`版停留在17年不更新了，`Dev`分支虽然在推进但是不想做小白鼠。
一劳永逸迁移到`hugo`平台，源文件用`git`管理，免去备份数据库的烦恼。

## 迁移过程

首先用[AlanDecode/Typecho-Plugin-Tp2MD](https://github.com/AlanDecode/Typecho-Plugin-Tp2MD)插件（感谢作者的付出），格式
需要自己手动修改一下成`hugo`需要的格式，默认的是`hexo`格式的，有些细微的差别。然后就是标准的建站流程了。
