
---
title: "LRU Cache的简单实现"
date: 2021-01-10T20:20:31+08:00
draft: false
# tags: [ "" ]
categories: [ "cpp"]
# keywords: [ ""]
lastmod: 2021-01-10T20:20:31+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "LRU_Cache的简单实现"
toc: false
# latex support
# katex: true
# markup: mmark
---

CS:APP的最后一个proxy lab需要实现一个LRU cache用于代理服务器的缓存。
定义一个数据块 `data_block`，用于存放socket的数据。

```cpp
#define MAX_CACHE_SIZE 1049000
#define MAX_OBJECT_SIZE 102400
struct data_block
{
    char data[MAX_OBJECT_SIZE];
    uint32_t size;
};
```

常见的LRU实现包含一个链表，用于存放数据块，一个hash表，用于存放key到链表节点的指针的映射关系(其实我感觉优先队列也可以)。

如果没有hash表，每次查找cache需要用`O(n)`的时间。
链表可以自己在数据节点实现，实现只需要实现两个辅助函数`detach_node`,`insert_node(pos)`用于实现将节点从链表中间断开，插入头部。

```cpp
class LRU_cache
{
    private:
    std::list<data_block>  data_;
    // store references of key in cache
    std::unordered_map<std::string, decltype(data_)::iterator> key_map_;
    uint32_t max_element_ = 10;
    uint32_t max_size_ = MAX_CACHE_SIZE;
    std::mutex lk_;
    uint32_t used_size_ = 0;
    public:
    LRU_cache(uint32_t max_elem, uint32_t max_size):max_element_(max_elem),max_size_(max_size)
    {
        data_ = {};
        key_map_ = {};
    }
    
    const data_block* get(std::string url);
    void put(std::string url, const char* buf,uint32_t size);
    }

};
```

查找`key`比较容易，直接查hash表，有节点的话将查找到的节点断开，插入到头部。

```cpp
const data_block* get(std::string url)
{
    std::lock_guard<std::mutex> lk(lk_);
    if(key_map_.size() == 0)return nullptr;
    auto it = key_map_.find(url);
    if(it != key_map_.end())
    {
        auto data_node = it->second;
        if(data_node != data_.begin())
        {
            data_.splice(data_.begin(),data_,data_node); //insert node to head
        }
        return &(*data_node);
    }
    return nullptr;
}
```

更新数据分为两种情况：
- 链表内已经有这个Cache key，但是要更新数据
- 链表内没有Cache，加入新的节点

无论是更新新的数据还是加入新的数据，都要维护总体Cache的大小，如果大小超出Cache的大小要把链表尾部的节点挨个踢出去，直到大小满足要求。
```cpp
void put(std::string url, const char* buf,uint32_t size)
{
    std::lock_guard<std::mutex> lk(lk_);
    auto it = key_map_.find(url);
    // for debug
    // std::cout<<"List size:" << data_.size()<<std::endl;
    // std::cout<<"url: "<<url<<std::endl;
    if(it != key_map_.end()) //update old value
    {
        auto data_node = it->second;
        if(data_node != data_.begin())
        {
            data_.splice(data_.begin(),data_,data_node);
        }
        std::memcpy(data_node->data,buf,size);
        //update size
        auto tmp_used_size = used_size_ - data_node->size + size;
        data_node->size = size;
        while(tmp_used_size > max_size_)
        {
            auto backit =  data_.back();
            tmp_used_size -= backit.size;
            data_.pop_back();
        }
        used_size_ = tmp_used_size;
    }
    else //insert new node
    {
        data_.emplace_front(data_block());
        std::memcpy(data_.front().data,buf,size);
        data_.front().size = size;
        used_size_ += size;
        auto tmp_used_size = used_size_;
        while(tmp_used_size > max_size_ || data_.size() > max_element_)
        {
            auto backit =  data_.back();
            tmp_used_size -= backit.size;
            data_.pop_back();
        }
        used_size_ = tmp_used_size;
        key_map_[url] = data_.begin();
    }
```