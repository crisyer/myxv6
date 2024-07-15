	#
        # code to switch between user and kernel space.
        #
        # this code is mapped at the same virtual address
        # (TRAMPOLINE) in user and kernel space so that
        # it continues to work when it switches page tables.
	#
	# kernel.ld causes this to be aligned
        # to a page boundary.
        #
	.section trampsec
.globl trampoline
trampoline:
.align 4
.globl uservec
uservec:    
        #这段代码是RISC-V架构下用户空间异常处理程序的一部分，通常位于内核的trap处理代码中。当用户空间进程触发一个系统调用或其他类型的异常时，控制将转移到这个异常处理程序。以下是代码的逐行解析：
        # 首先，它交换了a0和sscratch寄存器中的值。sscratch寄存器指向用户进程的trapframe结构，该结构通常被映射到用户空间的一个特定地址。trapframe结构用于保存异常发生时的用户空间寄存器状态。
        # 接下来，代码将用户空间的寄存器值保存到trapframe中。每个寄存器的内容都被保存到trapframe的相应偏移量处，这样可以在异常处理完成后恢复用户空间的上下文。
        # 用户空间的a0寄存器内容也被保存到trapframe的a0字段中，这可能是因为某些系统调用需要传递参数。
        # 然后，内核栈指针（sp）从trapframe的kernel_sp字段中恢复，以确保内核栈的正确性。
        # 当前HART ID（硬件线程ID）被加载到tp寄存器中，从trapframe的kernel_hartid字段获取。
        # 加载usertrap()函数的地址，这是内核中处理用户异常的函数，其地址存储在trapframe的kernel_trap字段中。
        # 内核页表（由satp寄存器管理）从trapframe的kernel_satp字段恢复，然后执行sfence.vma指令来刷新TLB（Translation Lookaside Buffer），确保页表更改立即生效。
        # 最后，跳转到usertrap()函数，开始异常处理流程。由于usertrap()不返回，这意味着处理过程将直接控制流程转向内核中的异常处理逻辑，直到异常处理完成并准备好恢复用户进程。
        # 整个过程确保了用户空间和内核空间之间的上下文隔离和正确切换，同时保留了用户进程的上下文，以便在异常处理后能够恢复执行。
	# 注释说明了这段代码的作用：它是用户空间触发陷阱时的入口点，
        # 使用户态的陷阱处理能够在内核空间执行，但仍然使用用户页表。
        # trap.c sets stvec to point here, so
        # traps from user space start here,
        # in supervisor mode, but with a
        # user page table.
        #
        # sscratch points to where the process's p->trapframe is
        # mapped into user space, at TRAPFRAME.
        #
        
	# swap a0 and sscratch
        # so that a0 is TRAPFRAME
        csrrw a0, sscratch, a0 // 保存trapfram到a0

        # save the user registers in TRAPFRAME 
        # 接下来，代码将用户空间的寄存器值保存到trapframe中。
        # 每个寄存器的内容都被保存到trapframe的相应偏移量处，这样可以在异常处理完成后恢复用户空间的上下文。
        sd ra, 40(a0)
        sd sp, 48(a0)
        sd gp, 56(a0)
        sd tp, 64(a0)
        sd t0, 72(a0)
        sd t1, 80(a0)
        sd t2, 88(a0)
        sd s0, 96(a0)
        sd s1, 104(a0)
        sd a1, 120(a0)
        sd a2, 128(a0)
        sd a3, 136(a0)
        sd a4, 144(a0)
        sd a5, 152(a0)
        sd a6, 160(a0)
        sd a7, 168(a0)
        sd s2, 176(a0)
        sd s3, 184(a0)
        sd s4, 192(a0)
        sd s5, 200(a0)
        sd s6, 208(a0)
        sd s7, 216(a0)
        sd s8, 224(a0)
        sd s9, 232(a0)
        sd s10, 240(a0)
        sd s11, 248(a0)
        sd t3, 256(a0)
        sd t4, 264(a0)
        sd t5, 272(a0)
        sd t6, 280(a0)

	# save the user a0 in p->trapframe->a0
        # 用户空间的a0寄存器内容也被保存到trapframe的a0字段中，这可能是因为某些系统调用需要传递参数。
        csrr t0, sscratch
        sd t0, 112(a0)

        # 然后，内核栈指针（sp）从trapframe的kernel_sp字段中恢复，以确保内核栈的正确性。
        ld sp, 8(a0)

        # 当前HART ID（硬件线程ID）被加载到tp寄存器中，从trapframe的kernel_hartid字段获取。
        ld tp, 32(a0)

        # 加载usertrap()函数的地址，这是内核中处理用户异常的函数，其地址存储在trapframe的kernel_trap字段中。
        ld t0, 16(a0)

        # 内核页表（由satp寄存器管理）从trapframe的kernel_satp字段恢复，
        #然后执行sfence.vma指令来刷新TLB（Translation Lookaside Buffer），确保页表更改立即生效。
        ld t1, 0(a0)
        csrw satp, t1
        sfence.vma zero, zero

        # a0 is no longer valid, since the kernel page
        # table does not specially map p->tf.

        # 最后，跳转到usertrap()函数，开始异常处理流程。由于usertrap()不返回，
        # 这意味着处理过程将直接控制流程转向内核中的异常处理逻辑，直到异常处理完成并准备好恢复用户进程。
        jr t0

.globl userret
userret:
        # userret(TRAPFRAME, pagetable)
        # switch from kernel to user.
        # usertrapret() calls here.
        # a0: TRAPFRAME, in user page table.
        # a1: user page table, for satp.

        # switch to the user page table.
        csrw satp, a1
        sfence.vma zero, zero

        # put the saved user a0 in sscratch, so we
        # can swap it with our a0 (TRAPFRAME) in the last step.
        ld t0, 112(a0)
        csrw sscratch, t0

        # restore all but a0 from TRAPFRAME
        ld ra, 40(a0)
        ld sp, 48(a0)
        ld gp, 56(a0)
        ld tp, 64(a0)
        ld t0, 72(a0)
        ld t1, 80(a0)
        ld t2, 88(a0)
        ld s0, 96(a0)
        ld s1, 104(a0)
        ld a1, 120(a0)
        ld a2, 128(a0)
        ld a3, 136(a0)
        ld a4, 144(a0)
        ld a5, 152(a0)
        ld a6, 160(a0)
        ld a7, 168(a0)
        ld s2, 176(a0)
        ld s3, 184(a0)
        ld s4, 192(a0)
        ld s5, 200(a0)
        ld s6, 208(a0)
        ld s7, 216(a0)
        ld s8, 224(a0)
        ld s9, 232(a0)
        ld s10, 240(a0)
        ld s11, 248(a0)
        ld t3, 256(a0)
        ld t4, 264(a0)
        ld t5, 272(a0)
        ld t6, 280(a0)

	# restore user a0, and save TRAPFRAME in sscratch
        csrrw a0, sscratch, a0
        
        # return to user mode and user pc.
        # usertrapret() set up sstatus and sepc.
        sret
