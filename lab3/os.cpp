asm(".code16gcc\n");
//asm("jmp 0:main");
#include <stdint.h>
#include "include/io.h"
const char *OS_INFO = "MiraiOS 0.1";
const char *PROMPT_INFO = "wkcn > ";

const osi maxBufSize = 128;
char buf[maxBufSize]; // 指令流
osi bufSize = 0;


extern "C" void RunProg(osi);
void Execute(){
	char c = buf[0];
	if (c >= '0' && c <= '9'){
		RunProg(c - '0' + 10);
	}
}
extern "C" void OK();

int main(){ 
	CLS();
	DrawText(OS_INFO,0,0,LGREEN);
	SetCursor(1,0);
	//DrawText(PROMPT_INFO,3,0,WHITE);
	OK();
	while(1){
		PrintStr(PROMPT_INFO,LCARM);
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
				if (bufSize < maxBufSize){
					PrintChar(c, WHITE);
					buf[bufSize++] = c;
				}
 			}
 		}
 	} 
	return 0;
} 
