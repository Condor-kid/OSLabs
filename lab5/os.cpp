asm(".code16gcc\n");
//asm("jmp 0:main");
#include <stdint.h>
#include "include/io.h"
#include "include/string.h"
#include "include/disk.h"
#include "include/keyboard.h"
#include "include/task.h"
//#include "include/interrupt.h"

const char *OS_INFO = "MiraiOS 0.1";
const char *PROMPT_INFO = "wkcn > ";
const char *NOPROG_INFO = "No User Process is Running!";
const char *BATCH_INFO = "Batching Next Program: ";
const char *LS_INFO = "Please Input These Number to Run a Program or more :-)\n\r1,2,3,4 - 45 angle fly char\n\r5 Draw my name";

const uint16_t maxBufSize = 128;
char buf[maxBufSize]; // 指令流
int bufSize = 0;
int par[16][2];
int parSize = 0;
int batchList[5] = {5,1,2,3,4};
int batchID = 0;
int batchSize = 0;


//extern "C" void WritePCB(uint16_t addr);
extern "C" uint16_t ShellMode;
extern "C" uint16_t RunNum;
extern "C" const uint16_t PROG_SEGMENT;
extern "C" uint8_t INT09H_FLAG;

uint16_t PROG_SEGMENT_S = 0;

__attribute__((regparm(1)))
int RunProg(char *filename){
	if (RunNum >= MaxRunNum)return 0;
	//addr = (char*)(((PROG_SEGMENT + PROG_SEGMENT_S) << 4) + 0x100); 
	//uint16_t addrseg = (PROG_SEGMENT + PROG_SEGMENT_S); 
	uint16_t offset = 0x100;
	uint16_t addrseg = (PROG_SEGMENT + PROG_SEGMENT_S);
	int si = LoadFile(filename,offset,addrseg);
	if (si == 0)return 0;
	PROG_SEGMENT_S += ((si + 0x100 + (1<<4) - 1) >> 4);

	//设置用户程序运行标志
	asm volatile(
			"push es;"
			"push si;"
			"push ax;"
			"mov ax, 0x00;"
			"mov es, ax;"
			"mov ax, 0x7c00;"
			"mov si, ax;"
			"mov ax, 0;"
			"mov es:[si],ax;"
			"pop ax;"
			"pop si;"
			"pop es;"
			);
	//WritePCB(addrseg);
	uint8_t pcbID = FindEmptyPCB();
	if (!pcbID)return 0;
	_p.ID = pcbID; 
	_p.CS = addrseg;
	_p.DS = addrseg;
	_p.SS = addrseg;
	_p.IP = 0x100;
	_p.SP = 0x100 - 4;
	_p.FLAGS = 512;
	_p.STATE = T_READY;
	_p.SIZE = si;
	int ni = 0;
	for (int i = 0;i < 8 && filename[i] != ' ';++i)_p.NAME[ni++] = filename[i];
	_p.NAME[ni++] = '.';
	for (int i = 8;i < 11 && filename[i] != ' ';++i)_p.NAME[ni++] = filename[i];
	for (;ni<16;++ni)_p.NAME[ni] = 0;
	WritePCB(pcbID);
	++RunNum;
	return si;
}

__attribute__((regparm(1)))
int RunProg(int i){
	if (i == 5){
		char f[12] = "KAN     COM";
		return RunProg(f);
	}
	char filename[12] = "WKCN1   COM";
	filename[4] = i + '0';
	cls();
	SetAllTask(T_RUNNING, T_SUSPEND);
	return RunProg(filename);
}

void top(){
	PrintStr(" There are ");
	PrintNum(RunNum,WHITE);
	PrintStr(" Progresses :-)",WHITE);
	PrintStr(NEWLINE,WHITE);
	Top();
}


__attribute__((regparm(2)))
void PrintInfo(const char* str, uint16_t color){
	PrintStr(PROMPT_INFO,LCARM);
	PrintStr(str,color);
	PrintStr(NEWLINE,color);
}

__attribute__((regparm(1)))
bool CommandMatch(const char* str){
	return (!strcmp(buf + par[0][0], str));
}

__attribute__((regparm(1)))
int GetNum(int i){
	//第一个参数 i = 1
	int j = par[i][0];
	int k = par[i][1];
	int res = 0;
	for (;j<k;++j){
		char c = buf[j];
		res = res * 10 + c - '0';
	}
	return res;
}

__attribute__((regparm(1)))
bool IsNum(int i){
	int j = par[i][0];
	int k = par[i][1];
	if (j >= k)return false;
	for (;j<k;++j){
		char c = buf[j];
		if (c < '0' || c > '9')return false;
	}
	return true;
}

void Execute(){  
	if (bufSize <= 0)return;
	batchSize = 0;
	batchID = 0;
	for (int i = 0;i < bufSize && batchSize < 5;++i){
		char c = buf[i];
		int y = c - '0';
		if (y >= 1 && y <= 5){
			batchList[batchSize++] = y;
		}else{
			if (c != ' ')break;
		}
	}
	if (batchSize == 1){
		batchSize = 0;
	}
	if (batchSize >= 2){
		return;
	}
	buf[bufSize] = ' ';
	//以空格为分隔符号,最多十六个参数
	int i,j;
	i = 0; j = 0;
	while (i < 16 && j < bufSize){
		for (;buf[j] == ' ' && j < bufSize;++j){
			buf[j] = 0;
		}
		par[i][0] = j;
		for (;buf[j] != ' ' && j < bufSize;++j);
		if (buf[j] == ' ')buf[j] = 0;
		par[i][1] = j;
		if (par[i][1] <= par[i][0])break;
		++j;
		++i;
		parSize = i;
	}
	/*
	for (int i = 0;i < parSize;++i){
		for (int j = par[i][0];j<par[i][1];++j){
			PrintChar(buf[j],YELLOW);
		}
		PrintStr(NEWLINE);
	}
	*/
	if (CommandMatch("uname")){
		PrintInfo(OS_INFO,WHITE);
	}else if (CommandMatch("top")){
		top();
	}else if (CommandMatch("cls")){
		cls();
	}else if (CommandMatch("r")){
		if(RunNum > 1){
			ShellMode = 1;
			SetAllTask(T_RUNNING,T_SUSPEND);
			cls();
		}else{
			PrintInfo(NOPROG_INFO, RED);
		}
	}else if(CommandMatch("killall")){
		KillAll();
		cls();
	}else if(CommandMatch("k") || CommandMatch("kill")){
		for(int q=1;q<parSize;++q)KillTask(GetNum(q));
	}else if(CommandMatch("wake")){
		for(int q=1;q<parSize;++q)SetTaskState(GetNum(q),T_RUNNING,T_SUSPEND);
	}else if(CommandMatch("suspend")){
		for(int q=1;q<parSize;++q)SetTaskState(GetNum(q),T_SUSPEND,T_RUNNING);
	}else if (IsNum(0)){
		for (int k = 0;k < parSize && buf[k];++k){
			char c = buf[k];
			int y = c - '0';
			if (y >= 1 && y <=5){
				RunProg(y);
			}
		}
		//CLS();
		ShellMode = 1;
	}else{
		//Check File
		char filename[12] = "        COM";
		for (int i = 0;i < 11;++i){
			char c = buf[i];
			if (c == '.' || c == 0)break;
			if (c >= 'a' && c <= 'z')c = c - 'a' + 'A';
			filename[i] = c;
		}
		if(RunProg(filename)){
			ShellMode = 1;
		}else 
			PrintInfo("Command not found, Input \'help\' to get more info",RED);
	}
	bufSize = 0;
}

void sleep(){ 
	int temp = 0;
	while(temp  < 10000){
		int ut = 10000;
		while ( ut > 0){
			--ut;
		}
		++temp;
	}
}

bool NeedRetnShell(){
	uint8_t a;
	asm volatile(
			"push si;"
			"push es;"
			"mov ax, 0x00;"
			"mov es, ax;"
			"mov ax, 0x7c00;"
			"mov si, ax;"
			"mov ax, es:[si];"
			"pop es;"
			"pop si;"
			:"=a"(a)
			);
	return (a && ShellMode);
}

int main(){  
	cls();
	DrawText(OS_INFO,0,0,LGREEN);
	DrawText("You can input \'help\' to get more info",1,0,LGREEN);	
	SetCursor(2,0);
	while(1){
		//Tab
		uint16_t key = GetKey();
		if (key == KEY_CTRL_C){
			cls();
		}
		//ShellMode = 0时, 为Shell操作
		if (ShellMode){
			//ShellMode = 1时, 切换到程序执行
			if (key == KEY_CTRL_Z || key == KEY_ESC){
				ShellMode = 0;
				if (key == KEY_CTRL_Z){
					KillAll();
				}else{
					SetAllTask(T_SUSPEND,T_RUNNING);
				}
				cls();
			}
			if (NeedRetnShell()){
				KillAll();
			}
			if (RunNum == 1){
				ShellMode = 0;
			}
			continue;
		}
		//非Shell
		//
		if (batchSize > 0 && batchID < batchSize){
			PrintStr(BATCH_INFO,YELLOW);
			int id = batchList[batchID++];
			PrintChar(id + '0',YELLOW);
			sleep();
			cls();
			RunProg(id);
			ShellMode = 1;
			continue;
		}

		PrintStr(PROMPT_INFO,LCARM);
		buf[0] = 0;
		bufSize = 0; // clean buf
		while(1){
			char c = getchar();
			 if (c == '\r'){
				PrintStr(NEWLINE);
				Execute();
				break;
			}else if (c == '\b'){
				if (bufSize > 0){
					PrintChar('\b');
					PrintChar(' ');
					PrintChar('\b');
					buf[--bufSize] = 0;
				}
			}else {
				if (bufSize < maxBufSize - 1){
					PrintChar(c, WHITE);
					buf[bufSize++] = c;
					buf[bufSize] = 0;
				}
 			}
 		}
 	 }  
	return 0;
} 
