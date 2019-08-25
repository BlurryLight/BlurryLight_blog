---
title: "FakeSTL From Scratch | AVL TREE的实现"
date: 2019-06-04T16:57:12+08:00
draft: false
# tags: [ "" ]
categories: [ "C++","STL"]
# keywords: [ ""]
lastmod: 2019-06-04T16:57:12+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "FakeSTL_From_Scratch____AVL_TREE的实现"
tags:
  - cpp
  - FakeSTL
---

## Why AVL Tree?

STL里平衡二叉树应用的很广泛，主要是标准规定了查找、插入和删除的复杂度。`set`,`multiset`,`map`,`multimap`下面都是平衡二叉
树，主流的实现版本都是用`rbtree`来实现。红黑树理论上在插入和删除的时候都比AVL树性能更好一点，在查找的时候AVL树性能更好，
因为AVL树有更严格的平衡条件。
在写tinySTL中我选择了AVL树而不是红黑树，具体原因有以下两点：

1. 红黑树的插入好写，删除的各种case多的要命。有多麻烦写过的人都知道。相反AVL的删除和插入都类似，只需要处理`LL`，`LR`，`RL`和`RR`四种情况，其中两种是对称的，实际上只有两种情况。

2. AVL树和RBtree的性能究竟有多大差距也有争议，如[AVL/RBTREE 实际比较](http://www.skywind.me/blog/archives/1987)。


## AVL树的实现

### AVL节点定义和辅助函数
一个包含有高度信息和节点数目信息的AVL树可以定义为以下的数据结构
```cpp
struct node {
    int data;
    int height;
    int n; //左右子树的总节点数目
    struct node* parent;
    struct node* lChild;
    struct node* rChild;
}
```
为了更新高度和更新总的数目，必须要给`node`节点添加更多的函数，其中包括

```cpp
    void update_height()
    {
        this->height = std::max(this->lChild ? lChild->height : 0, this->rChild ? rChild->height : 0)
                       + 1;
    }
    void update_n()
    {
        this->n = (this->lChild ? lChild->n : 0) + (this->rChild ? rChild->n : 0) + 1;
    }
```
同时，还需要计算平衡因子。平衡因子可以定义为**左子树的高度减去右子树的高度**，根据AVL树的要求，当任一节点平衡因子绝对值
大于1的时候，就需要旋转节点以维持平衡。具体的旋转放在后面讲，计算平衡因子的代码很简单。
```cpp
    int get_imbalance_factor()
    {
        return (lChild ? lChild->height : 0) - (rChild ? rChild->height : 0);
    }
```

### AVL树的旋转
#### LL型
第一种情况，被称为LL型，它的典型情况如下，括号内为平衡因子
可以看出，LL型的成立条件是
**root的平衡因子>1且root->lChild的平衡因子>0**
```
T1,T2,T3,T4都是子树
         z(2)                                   y(0)
        / \                                   /   \
     y(1)   T4      Right Rotate (z)         x(0)  z(0)
      / \          - - - - - - - - ->      /  \    /  \
  x(0)   T3                               T1  T2  T3  T4
    / \
  T1   T2
```
它的实现主要分以下几步

- 和链表的操作一样，将z->parent->l(r)Child替换为y，把z接到y的右孩子上，更新z的parent到y

- 把T3接到z上

- 更新z和y的节点数，因为他们的子树发生了变化，这里只需要更新z和y

- 从z开始往上循环，直到走到根节点，更新高度

可以直白的翻译成如下代码

```cpp
node* right_rotate(node* root)
//root 等于z
//返回值是new_root,等于旋转后的root，也即是y
{
    node* new_root = root->lChild;
    node *tmp = root->lChild->rChild; //tmp就是断开的T3
    if (root->parent) {
        if (root == root->parent->lChild) {
            root->parent->lChild = new_root;
        } else {
            root->parent->rChild = new_root;
        }
    }

    new_root->parent = root->parent;
    new_root->rChild = root;
    root->parent = new_root;
    root->lChild = tmp;
    if (tmp) //T3有可能是个nullptr
        tmp->parent = root;
    //先更新z的节点总数，再更新y的节点总数
    root->update_n();
    new_root->update_n();

    while (root) {
        root->update_height();
        root = root->parent;
    }
}

```
**右旋**的代码完全一样，只是左右子树，平衡因子都相反而已。

#### LR型

LR型即需要一次左旋，再要一次右旋的情况
LR型的成立条件是

**root的平衡因子>1,且root->lChild的平衡因子<0**
```
     z(2)                            z                           x
    / \                            /   \                        /  \
 y(-1) T4  Left Rotate (y)        x    T4  Right Rotate(z)    y      z
  / \      - - - - - - - - ->    /  \      - - - - - - - ->  / \    / \
T1   x                          y    T3                    T1  T2 T3  T4
    / \                        / \
  T2   T3                    T1   T2
```
如何去修正这样的LR型呢，可以写一个`left_rigt_rotate`的函数，也可以分别两次调用
```cpp
node* fix_lr_case(node* root)
{
    auto tmp = root->lChild->rChild;
    left_rotate(root->lChild);
    right_rotate(root);
    return tmp;
}
```
**RL**型和LR型完全对称。


### AVL树的插入

AVL树的插入分两部分，第一部分是找位置。平衡二叉树的节点值总是左边小，右边大，因此可以快速搜索，找到`nullptr`后停止。
实现的简单思路如下

- 建立一个`parent`指针，它从`root`开始搜索，如果value比`parent->data`大，就搜索右子树，否则左子树。直到`parent->lChild`
  或者`parent->rChild`是`nullptr`，在这里新建节点，此时`parent`指针正好是新建节点的`parent`。\\

- 从`parent`往上更新高度，这里注意，并非一定要回溯到根节点，如下图所示情况，更新到x节点即可停止更新高度。当某一节点另一
  子树的高度>=新加入节点的子树的总高度时，更新到此节点即可停止更新。

```
     x(height = 2)
   /      \
  parent   T1(height = 1)
  /
new_node
```
直白的翻译成代码可以翻译成
```cpp
void insert(node* root,const value_type& val)
{
    node_type *parent = root;
    while (true) {
        ++parent->n;
        if (parent->data > val) {
            if (parent->lChild) {
                parent = parent->lChild;
            } else {
                parent->lChild = createNode(val);
                parent->lChild->parent = parent;
                break;
            }
        } else {
            if (parent->rChild) {
                parent = parent->rChild;
            } else {
                parent->rChild = createNode(val);
                parent->rChild->parent = parent;
                break;
            }
        }
    }
    //插入完节点以后，parent指针现在指向新建节点的parent
    //现在从parent往上更新高度

    //branch_height的效果是用来记录parent更新前的高度
    // parent = parent->parent后，将高度与branch_height比较，如果parent->height > branch_height，则不用继续回溯更新
    int branch_height = 1;
    do{
        if (parent == root)
            break;
        if (parent->height > branch_height)
            break;
        parent->height = branch_height + 1;
        if (parent->get_imbalance_factor() > 1) {
            //LR case
            if (parent->lChild->get_imbalance_factor() < 0) {
                left_rotate(parent->lChild);
            }
            //LL case
            right_rotate(parent);
            break;
        } else if (parent->get_imbalance_factor() < -1) {
            //RL case
            if (parent->rChild->get_imbalance_factor() > 0) {
                right_rotate(parent->rChild);
            }
            //rr case
            left_rotate(parent);
            break;
        }
        branch_height = parent->height;
        parent = parent->parent;
    }while(parent);

}
```

### AVL树的删除

删除操作主要分3种情况：

1. 被删除节点是叶节点，直接删除

2. 被删除节点只有一个孩子，剔除该节点，孩子与该节点的父母连接上，操作等同于双向链表的删除

3. 被删除节点有两个孩子。按照中序遍历的要求，寻找被删除节点的后继节点，交换两个节点的值的做法是错误的，因为STL要求操作不
   能使迭代器失效。应该按照双向链表的节点删除操作，断开被删除节点和后继节点的所有连接，将后继节点接回被删除节点的原位置。

   删除操作建议阅读这篇博客[AVL Tree | Set 2
   (Deletion)](https://www.geeksforgeeks.org/avl-tree-set-2-deletion)。

### AVL树的巡秩访问

`call by rank(index)`也是STL的常用操作，蛮力算法可以如下访问，后果就是查找复杂度退化为单链表O(N)

```cpp
for(int i = 0;i!=rank;++i)
{
    /*中序遍历*/
}
```

正常算法应该符合以下逻辑

- index<=左子树的节点总数，说明目标在左子树，继续寻找左子树

- index == 左子树的节点 + 1，当前节点就是要找的节点

- index >左子树的节点+1，目标在所在节点的右子树。 index -= （左子树的节点总数 + 1）,然后寻找当前目标的右子树。

实现如下
```cpp
node* at(node* root,size_type i)
{
    if (i > root->n || i < 0)
        exit(1);

    size_type index = i + 1; //因为按照stl习惯，at通常从0开始，而我们记录节点总数时往往从1开始，表明有1个节点


    while (root) {
        int left_size = root->lChild ? root->lChild->n : 0;

        if (index <= left_size) {
            root = root->lChild;
        } else if (index == (left_size + 1)) {
            break;
        } else {
            index -= (left_size + 1);
            root = root->rChild;
        }
    }
    return root;
}
```


