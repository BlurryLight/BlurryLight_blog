---
layout: post
cid: 435
title: "CPP Exercises"
slug: 435
date: 2019-01-07
updated: 2019-01-09
status: publish
author: panda
categories: 
  - cpp
  - LeetCode
tags: 
---


做一些CPP的练习。
不讲究奇技淫巧，不讲究运行速度。
以练习C++11的语法和强调代码的可读性为主要目标。


<!--more-->


 - 按照标准实现`strlen`,`strcpy`,`strncpy`,`strcat`,`strncat`,`strcmp`

    ```cpp
    
    size_t strlen1(const char* str)
    {
        size_t tmp;
        while(*str++)
            tmp++;
        return tmp;
    }
    //baddress指针存储了目标数组开始的地址
    char* strcpy1(char* dest,const char* src)
    {
        if((dest==NULL) ||(src==NULL))
            return NULL;
        auto baddress = dest;
        while(*src!='\0')
            *dest++ = *src++;
        return baddress;
    }
    char* strncpy1(char* dest,const char* src,size_t count)
    {
        if((dest==NULL) ||(src==NULL))
            return NULL;
        auto baddress = dest;
        while(count-- &&(*dest++ = *src++))
            ;
        //根据标准，src复制完后count未到0，应该补上\0
        for (; count-- ; *dest++ = '\0');
        return baddress;
    }
    char* strcat1(char* dest,const char* src)
    {
        //strcpy(dest+strlen(src));
    
        if((dest==NULL) ||(src==NULL))
            return NULL;
        auto baddress = dest;
        while(*dest!='\0')
            dest++;
        while(*dest++ = *src++)
            ;
        return baddress;
    }
    char* strncat1(char* dest,const char* src,size_t count)
    {
        
    
        if((dest==NULL) ||(src==NULL))
            return NULL;
        auto baddress = dest;
        while(*dest!='\0')
            dest++;
        while(count-- &&(*dest++ = *src++))
            ;
        return baddress;
    }
    
    int strcmp1(const char* lhs,const char* rhs)
    {
        if((lhs==NULL) ||(rhs==NULL))
            return NULL;
        while(*lhs==*rhs && *rhs)
        {
            lhs++;
            rhs++;
        }
    //标准中规定的是左<右时返回负值，相等时返回0
        if(*lhs<*rhs)
            return -1;
        else if (*lhs==*rhs) {
            return 0; }
        else {
            return 1;
        }
    
    }
    
    
    ```



