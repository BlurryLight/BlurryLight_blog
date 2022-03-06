
---
title: "Hugo的GitInfo为nil的问题"
date: 2022-02-18T15:11:32+08:00
draft: false
# tags: [ "" ]
categories: [ "hugo"]
# keywords: [ ""]
# lastmod: 2022-02-18T15:11:32+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "4f3428ec"
toc: false
mermaid: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

我现在的博客程序用的是Hugo，并且版本`Pin`在了`0.68.3`，因为高版本似乎禁用了`mmark`这个格式但是我现在写Katex需要它。
最近试图增加一个新的功能，是追踪文章的`LastMod`更新时间，并且添加commit hash值和commit msg。

![cmtmsg](https://img.blurredcode.com/img/202202181513512.png?x-oss-process=style/compress)


对应的代码差不多类似于,需要用到Hugo提供的`.GitInfo`结构体(https://gohugo.io/variables/git/)。
```html
{{ if and (.Site.Params.GitRepo.enable) (.GitInfo)}}
  <p class="date" title="Commit: {{ .GitInfo.Subject }}">LastMod:<a href="{{ .Site.Params.GitRepo.Host }}/{{ .GitInfo.AbbreviatedHash}}">{{ $lastmod }}</a></p> 
{{ else }}
  <p class="date">LastMod:{{ $lastmod }}</p> 
{{ end }}

```

## 获取的`.GitInfo`为nil

这个功能在本地是验证通过的没问题的，上传到CI上后发现**部分文章**并不能获取到`GitInfo`信息，调试一番以后发现其打印出来其值为Nil，但是有些文章如`about.md`这种又是能够正确生成的。
初步怀疑是`Cloudflare Pages`的编译环境可能有问题，换到`Github Actions`以后问题依然能够稳定重现，换着花样搜索也没有头绪。

## 发现问题

不死心的再换着花样搜索了一下，发现一个人的提问[GitInfo fails if there is an umlaut in the folder path](https://discourse.gohugo.io/t/gitinfo-fails-if-there-is-an-umlaut-in-the-folder-path/32746)，大概就是文件路径里有元音字母的时候获取不到`.GitInfo`。
我突然意识到我获取不到`.GitInfo`的文章都是中文文件名，但是我本地的`git`关闭了`quotepath`这个设置，因此git能正确获取到其中文名字。

在`quotepath`设置打开的时候，git会尝试把所有的非ASCII字符转义并用双引号将其包裹起来，如
![](https://img.blurredcode.com/img/202202181524425.png?x-oss-process=style/compress)

而关闭`quotepath`的格式为

![](https://img.blurredcode.com/img/202202181524467.png?x-oss-process=style/compress)

意识到这一点后，在CI的`pipeline`里多添加一步指令设置git关闭`quotePath`，问题就解决了，hugo也能正确获取到所有文章的Git信息了，见[pages.yml](https://github.com/BlurryLight/BlurryLight_blog/blob/76265a7e3265036e8c59a3e2055725dff18daa33/.github/workflows/pages.yml#L34)