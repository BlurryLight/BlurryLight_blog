
---
title: "Manjaro下texlive环境配置指北"
date: 2020-08-15T17:58:25+08:00
draft: false
# tags: [ "" ]
categories: [ "Linux"]
# keywords: [ ""]
lastmod: 2020-08-15T17:58:25+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "Linux下texlive环境配置指北"
toc: false
# latex support
# katex: true
# markup: mmark
---

Linux下安装texlive环境大致分为两种方式，一种是从包管理器中安装，二是从下载已经打包好的texlive镜像。

在Ubuntu这种带版本的发行版我可能会偏向第一种，因为安装简单，但是在Manjaro这种滚动发行版上最好选择第二种方案。原因有两点，第一texlive会经常随着系统的升级而滚动升级，但是风险是万一在赶论文ddl的时候把texlive滚坏了就会很麻烦。第二个是texlive带有自己的包管理器`tlmgr`，这个和`arch`系的包管理器`pacman`并不兼容，因此需要一个特别的与`pacman`兼容的包管理器。(PS: Arch下的Python也有这个问题，用python3-pip升级由pacman安装的Python包以后可能会导致pacman无法管理这部分文件)。

# Texlive安装

这部分没什么好说的，在喜欢的镜像处下载texlive的完整安装包texlive.iso(我用的[阿里云镜像](https://mirrors.aliyun.com/CTAN/systems/texlive/Images/)）,挂载后安装。

- 挂载iso `mkdir iso & sudo mount -o loop ./texlive.iso ./iso `
- `./install-tl --gui`(依赖图形库tk,没有的话需要`pacman -S tk`)
- 高级设置，去除不需要的文字和editor

![安装说明](/image/texlive.png)

官网还会提示复制`texlive-fontconfig.conf`到`~/.fonts.conf`，以让系统找到texlive安装的字体。我没有做，因为texlive默认会安装`Fandol`系列的宋体，而Linux下一些wine出来的应用(`wine-qq`)会寻找宋体。如果系统里安装了宋体的话，wine出来的应用可能会以宋体来显示，很难看。实际测试不需要复制字体`xelatex`也能找到所需要的字体。


# vscode配置

我用vscode写Latex，插件里有`LaTex Workshop`很方便，默认配置就可以进行latex源文件和pdf的正向查找和反向查找(从pdf跳到tex源文件)。但是我个人习惯在`Okular`PDF阅读器中阅读pdf，所以需要一些额外的配置。

我使用`latexmk`来管理编译过程，它可以一键进行标准的`tex->bib->tex*2`的过程，所以填加一个`recipes`,并加入一些额外的设置。

```json
  "latex-workshop.latex.recipes": [
    {
      "name": "xelatex",
      "tools": [
        "xelatex"
      ]
    },
    {
      "name": "latexmk",
      "tools": [
        "latexmk"
      ]
    },
  ]，
   "latex-workshop.view.pdf.viewer": "external",
  "latex-workshop.view.pdf.external.viewer.command": "okular",
  "latex-workshop.view.pdf.external.viewer.args": [
    "--unique",
    "%PDF%"
  ],
  "latex-workshop.view.pdf.external.synctex.command": "okular",
  "latex-workshop.view.pdf.external.synctex.args": [
    "--unique",
    "%PDF%#src:%LINE%%TEX%"
  ]
```

# okular配置

以上配置以后，应该可以从vscode中跳跃到okular中了，但是要从okular跳跃回vscode需要在okular配置一下。

进入`设置->配置okular->编辑器->自定义编辑器`，填入

```
code --goto %f:%l
```


