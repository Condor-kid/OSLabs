#ifndef _THREAD_H_
#define _THREAD_H_

#include "pcb.h"
#include "port.h"

struct thread_t{
	uint16_t tid;
};

__attribute__((regparm(3)))
uint8_t thread_create(thread_t *t, __attribute__((regparm(1)))void* (*func)(void*), void *attr){
	asm volatile("int 0x21;int 0x08;"::"a"(0x0700)); // 关闭进程切换, 更新PCB值
	INIT_SEGMENT();
	uint16_t runid;
	asm volatile("int 0x21;":"=a"(runid):"a"(0x0200));
	LoadPCB(runid); // note:IP!
	if (_p.KIND == K_THREAD){
		func(attr); // 执行函数
		SetTaskState(runid, T_DEAD);
		asm volatile("int 0x21;"::"a"(0x0800)); // 开启时钟
		asm volatile("int 0x08;"); // 马上切到下一进程
		while(1){}
		return 0; // 子进程返回0
	}
	uint8_t newID = FindEmptyPCB();
	uint16_t PROG_SEG_S;
	ReadPort(3,&PROG_SEG_S,sizeof(PROG_SEG_S));
	uint16_t addrseg = PROG_SEGMENT + PROG_SEG_S;
	PROG_SEG_S += 0x10; // 因为是以段计数的
	WritePort(3,&PROG_SEG_S,sizeof(PROG_SEG_S));
	//[ds:si] -> [es:di]
	asm volatile("push ds;push si;push es;push di;"
			"mov ds,ax;"
			"mov es,dx;"
			"xor si,si;"
			"xor di,di;"
			"cld;"
			"COPY_STACK:;"
			"movsw;movsw;movsw;movsw;"
			"movsw;movsw;movsw;movsw;"
			"loop COPY_STACK;"
			"pop di;pop es;pop si;pop ds;"
			:
			:"a"(_p.SEG),"d"(addrseg),"c"(0x10)
			);

	// 注意, ID与RunID类型是不同的,db和dw
	_p.ID = newID;
	_p.SS = addrseg;
	_p.PARENT_ID = runid;
	_p.KIND = K_THREAD;
	t->tid = newID;
	WritePCB(newID);
	asm volatile("int 0x21;"::"a"(0x0900)); // ++RunNum
	asm volatile("int 0x21;"::"a"(0x0800)); // 开启进程切换
	return newID;
}


__attribute__((regparm(2)))
uint8_t thread_join(thread_t _t, void **_thread_retn){
	INIT_SEGMENT();
	uint16_t tid = _t.tid;
	while(1){
		if (GetTaskState(tid) == T_DEAD)break;
	}
	uint16_t ax;
	GetTaskAttr(tid, &_p.AX, ax);	
	if (_thread_retn)*_thread_retn = (void*)(long)ax;
	return tid;
}
#endif
