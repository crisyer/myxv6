// Physical memory allocator, for user processes,
// kernel stacks, page-table pages,
// and pipe buffers. Allocates whole 4096-byte pages.

#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "spinlock.h"
#include "riscv.h"
#include "defs.h"

void freerange(void *pa_start, void *pa_end);

extern char end[]; // first address after kernel.
                   // defined by kernel.ld.

uint page_ref[(PHYSTOP - KERNBASE) / PGSIZE]; // 将用户态内存/4k,也就是一个位置对应一个页

struct run {
  struct run *next;
};

struct {
  struct spinlock lock;
  struct run *freelist;
} kmem;

void
kinit()
{
  initlock(&kmem.lock, "kmem");
  freerange(end, (void*)PHYSTOP);
}

void
freerange(void *pa_start, void *pa_end)
{
  char *p;
  p = (char*)PGROUNDUP((uint64)pa_start);
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    kfree(p);
}

// Free the page of physical memory pointed at by v,
// which normally should have been returned by a
// call to kalloc().  (The exception is when
// initializing the allocator; see kinit above.)
void
kfree(void *pa)
{
  struct run *r;

  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    panic("kfree");

  if(page_ref[COW_INDEX(pa)] > 1) { // 引用次数 free了,不一定马上就释放内存,可能是共享内存
    page_ref[COW_INDEX(pa)]--;
    return;
  }
  page_ref[COW_INDEX(pa)] = 0; //不大于1,说明没有其他进程引用,可以释放内存

  // Fill with junk to catch dangling refs.
  memset(pa, 1, PGSIZE);

  r = (struct run*)pa;

  acquire(&kmem.lock);
  r->next = kmem.freelist;
  kmem.freelist = r;
  release(&kmem.lock);
}

// Allocate one 4096-byte page of physical memory.
// Returns a pointer that the kernel can use.
// Returns 0 if the memory cannot be allocated.
void *
kalloc(void)
{
  struct run *r;

  acquire(&kmem.lock);
  r = kmem.freelist;
  if(r)
    kmem.freelist = r->next;
  release(&kmem.lock);

  if(r) {
    memset((char*)r, 5, PGSIZE); // fill with junk
    page_ref[COW_INDEX(r)] = 1;
  }
  return (void*)r;
}
/**
 * 这段代码实现了RISC-V架构下Copy-On-Write（COW）机制的一部分，用于处理虚拟内存页面的复制，特别是当一个原本只读共享的页面需要变为可写时的情况。下面是对代码功能的概述：

地址对齐：va被向下舍入到最近的页面边界，确保处理的是完整的页面。
边界检查：确认va没有超过最大虚拟地址MAXVA。
页表遍历：使用walk函数找到虚拟地址va对应的页表条目。如果walk未能找到有效的条目，函数返回-1。
物理地址和标志获取：从页表条目中解析出物理地址pa和标志flags。
COW检查：如果flags包含PTE_COW标志，这表明页面是通过COW机制共享的，现在需要对其进行写操作。
复制页面：分配新的物理内存页面，并将原有页面的内容复制到新页面中。
解除原有映射：使用uvmunmap函数解除原有物理页面在虚拟地址空间的映射。
更新标志：修改flags，移除PTE_COW标志，并添加PTE_W标志使页面可写。
重新映射页面：使用mappages函数将新分配的物理页面映射到虚拟地址va，并应用更新后的flags。如果映射失败，释放新分配的内存并返回-1。
成功返回：如果一切顺利，函数返回0表示成功。
总的来说，cow_alloc函数在检测到对共享只读页面的写入需求时，会复制该页面，
 */
  int
  cow_alloc(pagetable_t pagetable, uint64 va) {
    va = PGROUNDDOWN(va);
    if(va >= MAXVA) return -1;
    pte_t *pte = walk(pagetable, va, 0);
    if(pte == 0) return -1;
    uint64 pa = PTE2PA(*pte);
    if(pa == 0) return -1;
    uint64 flags = PTE_FLAGS(*pte);
    if(flags & PTE_COW) {
      uint64 mem = (uint64)kalloc();
      if (mem == 0) return -1;
      memmove((char*)mem, (char*)pa, PGSIZE);
      uvmunmap(pagetable, va, 1, 1);
      flags = (flags | PTE_W) & ~PTE_COW;
      //*pte = PA2PTE(mem) | flags;
    if (mappages(pagetable, va, PGSIZE, mem, flags) != 0) {
        kfree((void*)mem);
        return -1;
      }
    }
    return 0;
  }