
---
title: "xv6的mmap的实现"
date: 2021-07-18T17:03:00+08:00
draft: false
# tags: [ "" ]
categories: [ "xv6"]
# keywords: [ ""]
# lastmod: 2021-07-18T17:03:00+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "f586ed81"
toc: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

很长一段时间没整理xv6的相关笔记了。`mmap`是Linux下的一个比较常用的api，可以将磁盘的文件映射到虚拟内存中。
实现`mmap`需要用到`lazy`分配的机制，这样才允许mmap映射远大于内存的文件到虚拟内存中。

# Lazy 分配的实现
常规的添加两个syscall用于`mmap`和`munmap`。mit的实验中不需要实现`mmap`的第一个参数`addr`,交由内核来决定，最后一个参数`offset`不需要实现，flag只需要实现`map_private`和`map_shared`。

在`proc`中新建`struct vma`作为`slots`，由于mmap的测试量比较小，官方给了提示可以直接开栈上数组，不用走`kalloc`分配堆内存。在`mmap`的`syscall`里处理逻辑，

```cpp
  struct vma* v = 0;
  for(int i = 0; i < 16;i++)
  {
      if(!p->vmas[i].valid_) // we find one
      {
          v = &(p->vmas[i]);
          v->valid_ = 1;
          addr = p->sz;
          v->addr_ = addr;
          v->length_ = length;
          v->flags_ = flags;
          v->prot_ = prot;
          v->file_ptr_ = f;
          filedup(f); //重要：任何一个mmap都要维护文件的引用计数
          break;
      }
  }
```

同时负责参照`lazy`分配的实现，在系统中断处处理`Page Fault`的中断，注意边界情况的处理。

一个合法的page fault的触发要验证:
- 这个虚拟地址处于被mmap的区间范围内
- 这个虚拟地址没有超过进程的虚拟地址空间


```cpp
      uint64 ka = (uint64)kalloc();
      if(ka == 0) goto bad;
      memset((void*)ka,0,PGSIZE);
      va = PGROUNDDOWN(va);
      int permission = PTE_U;
      if(v->prot_ & PROT_READ)
        permission |= PTE_R;
      if(v->prot_ & PROT_WRITE)
        permission |= PTE_W;
      struct vma* v = &p->vmas[i];
      ilock(v->file_ptr_->ip);
      readi(v->file_ptr_->ip,0,ka,va - v->addr_,PGSIZE);
      iunlock(v->file_ptr_->ip);
      if(mappages(p->pagetable,va,PGSIZE,ka,permission) < 0)
      {
          kfree((void*)ka);
          goto bad;
      }
      goto good;
bad:
    p->killed = 1;
good:
    (void)0;
  }
```

# munmap的实现

没什么好说的，注意处理四种不同的情况
- `munmap`整个区域，`vma`结构体清零并且关闭文件描述符
- 从头部`munmap`部分区域，归还被`munmap`的区域给系统内存，`vma`的length减少，起始地址增加。`naive`的实现可以先unmap整个区域，然后从新映射后半部分的区域。
- 从中间`munmap`到文件末尾，只需要减少`vma`的length和归还被unmap的区域。
- 从中间`addr1`开始`munmap`，`munmap`到`addr2`，相当于文件的中端被`munmap`了。mit的实验测试没有测试这个情况，我也没仔细去实现这个情况。这个情况的实现需要`mmap`支持从指定的偏移开始映射，能想到的实现需要`munmap`整个文件,然后重新`mmap`头部和`mmap`尾部。 

# fork的处理

子进程要继承父进程的所有的`mmap`区域，但是可以不处理页表，这样子进程的mmap读取的时候会重新触发page fault。在Linux里这里应该要细化的处理，尽量使子进程的页表和父进程的页表形成`cow`，会节约物理内存的使用。

主要要维护文件描述符`fd`的引用计数，在`exit`函数的时候减少所有被`mmap`区域的引用计数，并且如果有`map_shared`的区域要把更改写回到硬盘文件。
```cpp
  memcpy(np->vmas,p->vmas,sizeof(struct vma) * 16);
  for(int i = 0;i<16;i++)
  {
      if(np->vmas[i].valid_)
      {
          filedup(np->vmas[i].file_ptr_);
      }
  }
```