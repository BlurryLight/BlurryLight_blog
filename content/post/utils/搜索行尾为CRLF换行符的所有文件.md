
---
title: "搜索行尾为CRLF换行符的所有文件"
date: 2022-03-06T20:45:25+08:00
draft: false
# tags: [ "" ]
categories: [ "utils"]
# keywords: [ ""]
# lastmod: 2022-03-06T20:45:25+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "265a6886"
toc: true
mermaid: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

# autoCRLF的问题

在多个平台工作的时候经常需要注意换行符的问题，Windows习惯使用`CRLF(\r\n)`作为换行符，而`Linux`习惯采用`LF(\n)`，MacOS没用过没有发言权。
尽管现在不同平台的现代IDE和编辑器都能正确处理换行符的问题，但是有必要在同一项目里采用相同的换行符。我个人的习惯是不管在任何平台都采用`LF`换行符。

在Windows平台下由于默认的换行符为`CRLF`，因此在`Unity`或者在`Powershell`里新建文件都会默认以`CRLF`结尾。
将`CRLF`结尾的文件提交到Git里会提示一个警告，要求设置`autoCRLF`，大概就是`checkin`的文件会帮你自动把CRLF转到LF，然后`checkout`的时候会帮你自动把`LF`转到`CRLF`。我个人不喜欢这个选项，很多人也不喜欢，比如[GitHub 第一坑：换行符自动转换](http://ourjs.com/detail/586e04574edfe07ccdb2347a)。`git`会偷偷摸摸的更改你的换行符，而且在有些落后的diff工具里，不会标识换行符发生了改变，导致你面对diff摸不着头脑。

![搜索行尾为CRLF换行符的所有文件-2022-03-06-20-50-03](https://img.blurredcode.com/img/搜索行尾为CRLF换行符的所有文件-2022-03-06-20-50-03.png?x-oss-process=style/compress)

# 寻找CRLF

遗憾的是Git不会提示你哪些文件是CRLF结尾的，每当收到这个警告就必须挨着排查到底哪个文件是CRLF的，重复劳动很心碎。
迫切需要一种`grep`手段来快速搜索。
一种来自stackoverflow的解决方案(https://stackoverflow.com/a/73969)

```bash
find . -not -type d -exec file "{}" ";" | grep CRLF
```

试了下，有点慢，主要是会搜索所有的子目录和子文件(哪怕这些文件在.gitignore)里面。

`ripgrep`会遵守`.gitignore`，并且它比`grep`更快，尝试着在`bash`里写出，其中`rg -l`是列出文件列表，`-g`选项可以设置`glob`的模式，这里排除了一些常见的目录和后缀名

```bash
rg -l -g \!build/* -g \!*.meta  -g \!public/ '\x0d'
# 也可以在bashrc里写成alias
alias findcrlf="rg -l '\x0d' -g \!build/* -g \!*.meta -g \!public" 
```

试了一下基本能达到想要的效果
![搜索行尾为CRLF换行符的所有文件-2022-03-06-21-15-16](https://img.blurredcode.com/img/搜索行尾为CRLF换行符的所有文件-2022-03-06-21-15-16.png?x-oss-process=style/compress)