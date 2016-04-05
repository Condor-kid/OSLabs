#include <iostream>
#include <fstream>
#include <cstring>
using namespace std;

typedef char db;
typedef short dw;
typedef int dd;

char FileName[11 + 1] = "HELLO   COM";

#pragma pack (1) // ��1�ֽڶ���
struct Header{
	dw jmpShort;//BS_jmpBOOT һ������תָ��
	db nop;
	db BS_OEMName[8];	// ������
	dw BPB_BytesPerSec; //ÿ�����ֽ�����Bytes/Sector��	0x200
	db BPB_SecPerClus;	//ÿ����������Sector/Cluster��	0x1
	dw BPB_ResvdSecCnt;	//Boot��¼ռ�ö�������	ox1
	db BPB_NumFATs;	//���ж���FAT��	0x2
	dw BPB_RootEntCnt;	//��Ŀ¼���ļ������	0xE0
	dw BPB_TotSec16;	//��������	0xB40[2*80*18]
	db BPB_Media;	//����������	0xF0
	dw BPB_FATSz16;	//ÿ��FAT����ռ������	0x9
	dw BPB_SecPerTrk;	//ÿ�ŵ���������Sector/track��	0x12
	dw BPB_NumHeads;	//��ͷ����������	0x2
	dd BPB_HiddSec;	//����������	0
	dd BPB_TotSec32;	//���BPB_TotSec16=0,�����������������	0
	db BS_DrvNum;	//INT 13H����������	0
	db BS_Reserved1;	//������δʹ��	0
	db BS_BootSig;	//��չ�������(29h)	0x29
	dd BS_VolID;	//�����к�	0
	db BS_VolLab[11];	//��� 'wkcn'
	db BS_FileSysType[8];	//�ļ�ϵͳ����	'FAT12'
	db other[448];	//�������뼰��������	�������루ʣ��ռ���0��䣩
	dw _55aa;	//��510�ֽ�Ϊ0x55����511�ֽ�Ϊ0xAA	0xAA55
};

#pragma pack (1) // ��1�ֽڶ���
struct Entry{
	db DIR_Name[11];
	db DIR_Attr;
	db temp;
	db ratio;
	dw DIR_WrtTime;
	dw DIR_WrtDate;
	dw DIR_VISDate;
	dw FAT32_HIGH;
	dw LAST_WrtTime;
	dw LAST_WrtDate;
	dw DIR_FstClus;
	dd DIR_FileSize;
};

#pragma pack (1) // ��1�ֽڶ���
struct FAT{
	db data[3];
};

void PrintChar(char c){
	cout << c;
}

fstream fin("build/disk.img",ios::binary | ios::in);
void PrintHex(char num){
	const char ch[16] = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};
	PrintChar(ch[(num>>4)&0xF]);
	PrintChar(ch[(num)&0xF]);
	cout << endl;
}
int getFAT(int i){
	//�û��������ĵ�һ���ص������002
	fin.seekg(512 * 1 + i * 3 / 2);
	int f;
	fin.read((char*)&f,2);
	cout << "hex" << endl;
	PrintHex(((f&0xFF00) >> 8));
	PrintHex(f&0xFF);

	// 00 00 00 00 00 00 00
	if (i % 2 == 1){
		//��12
		f = (f >> 4) & 0xFFF;
	}else{
		//��12
		f &= 0xFFF;
	}
	cout << "fat   " << f << endl;
	return f;
}

bool matchSTR(char *astr,char *bstr,int len){
	for (int i = 0;i < len;++i){
		if (astr[i] != bstr[i])return false;
	}
	return true;
}

bool FindEntry(Entry &e){
	for (int j = 0; j < 14;++j){
		fin.seekg((19+j) * 512, ios::beg);
		for (int k = 0;k < 512 / 32;++k){
			fin.read((char*)&e, 32);
			cout << "Te:" << e.DIR_Name << endl;
			if (matchSTR(e.DIR_Name, FileName,11)){
				return true;
			}
		}
	}
	return false;
}

int main(){
	cout << "See you" << endl;
	Header header;
	fin.read((char*)&header, 512);
	cout << header.BS_OEMName << endl;
	Entry e;
	bool can = FindEntry(e); 
	cout <<"Find" << can << endl;
	cout << e.DIR_FileSize << endl;
	int u = e.DIR_FstClus;
	//ofstream fout(FileName, ios::binary);
	char buf[512];
	while(!(u >= 0xFF8)){
		//��
		int offset = 512 * 33 + (u - 2) * 512;
		//fin.seekg(offset,ios::beg);
		//fin.read(buf,512);
		cout << u<< endl;
		u = getFAT(u);
		if (u >= 0xFF8 && e.DIR_FileSize % 512 != 0){
			//fout.write(buf,e.DIR_FileSize % 512);
		}else{
			//fout.write(buf,512);
		}
	}
	return 0;
}
