---
layout: post
cid: 421
title: "C++的string和char*并不隐式转换"
slug: 421
date: 2017-08-04
updated: 2017-08-04
status: publish
author: panda
categories: 
  - cpp
tags: 
---


# string转const char*
```cpp

   string s = "abc";

   const char* c_s = s.c_str();
```

## const char*转string

```cpp

   const char* c_s = "abc";

   string s(c_s);
```

在libcurl的设置POST中遇见了诡异的Bug，本来是好端端的url，post过去结果怎么都不对劲。后来查了API才注意到
`CURLcode curl_easy_setopt(CURL *handle, CURLOPT_POSTFIELDS, char *postdata); `
其POST的参数内容类型为`char*`，而我的URL的类型为`std::string`。这也是脚本语言写多了，对类型不敏感导致的错误
