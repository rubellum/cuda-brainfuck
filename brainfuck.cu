#include <stdio.h>
#include <stdlib.h>

#define MEMMAX 30000
#define DEVMEMMAX 32 // 16kB / 512

__global__ void devBrainfuck(char *devCode, char *outMem)
{
  int tid = threadIdx.x;
  int tcnt = blockDim.x;
  char *cp = devCode;
  extern __shared__ char mem[];
  char *mp = &mem[tid];
  int i, kc;

  // 初期化
  mem[tid] = tid;
  for (i = 1; i < tcnt; i++) {
    mem[i * tcnt + tid] = 0;
  }

  // 命令実行
  while (*cp != '}') {
    switch (*cp) {
    case '+':
      (*mp)++;
      break;
    case '-':
      (*mp)--;
      break;
    case '>':
      mp += tcnt;
      break;
    case '<':
      mp -= tcnt;
      break;
    case '[':
      if (*mp == 0) {
	cp++;
	kc = 0;
	while (*cp != ']' || kc > 0) {
	  if (*cp == '[') kc++;
	  if (*cp == ']') kc--;
	  cp++;
	}
      }
      break;
    case ']':
      if (*mp != 0) {
	cp--;
	kc = 0;
	while (*cp != '[' || kc > 0) {
	  if (*cp == ']') kc++;
	  if (*cp == '[') kc--;
	  cp--;
	}
      }
      break;
    }
    cp++;
  } 
  outMem[tid] = *mp;
}

int brainfuck(char *code)
{
  char *cp = code;
  char mem[MEMMAX];
  char *mp = mem;
  int  kc; // カッコカウンタ(カッコワルイ)
  int  tc;
  int  cc;
  char *devCode, *outMem;
  int  i;

  // BFホストメモリ初期化
  for (i = 0; i < MEMMAX; i++) {
    mem[i] = 0;
  }

  // BF命令実行
  while (*cp) {
    switch (*cp) {
    case '+':
      (*mp)++;
      break;
    case '-':
      (*mp)--;
      break;
    case '>':
      mp++;
      break;
    case '<':
      mp--;
      break;
    case '.':
      printf("%c(%d)\n", *mp, *mp);
      //putchar(*mp);
      break;
    case ',':
      while ((*mp = getchar()) == '\n');
      break;
    case '[':
      if (*mp == 0) {
	cp++;
	kc = 0;
	while (*cp != ']' || kc > 0) {
	  if (*cp == '[') kc++;
	  if (*cp == ']') kc--;
	  cp++;
	}
      }
      break;
    case ']':
      if (*mp != 0) {
	cp--;
	kc = 0;
	while (*cp != '[' || kc > 0) {
	  if (*cp == ']') kc++;
	  if (*cp == '[') kc--;
	  cp--;
	}
      }
      break;

    case '{': // 拡張
      tc = *mp; // スレッド数
      cp++;
      cc = 0;
      while (cp[cc++] != '}');
      cudaMalloc((void**)&devCode, sizeof(char) * cc); // 命令(デバイス)
      cudaMemcpy(devCode, cp, sizeof(char) * cc, cudaMemcpyHostToDevice);

      cudaMalloc((void**)&outMem,  sizeof(char) * tc); // 実行結果

      //for (i = 0; i < cc; i++) putchar(cp[i]);
      //printf("/cc=%d tc=%d\n", cc, tc);

      // 実行
      dim3 grid(1, 1);
      dim3 block(tc, 1, 1);
      devBrainfuck <<< grid, block, tc * DEVMEMMAX >>> (devCode, outMem);

      // 結果取得
      cudaMemcpy(mp+1, outMem, sizeof(char) * tc, cudaMemcpyDeviceToHost);
      
      //for (i = 0; i < tc; i++) printf("[%d]%c\n", i, mp[i+1]);

      cudaFree(devCode);
      cudaFree(outMem);

      cp += cc - 1;
      break;
    }
    cp++;
  }

  return 0;
}

int main(int argc, char *argv)
{
  char *code = "+++++++++[>++++++++>+++++++++++>+++++<<<-]>.>++.+++++++..+++.>-.------------.<++++++++.--------.+++.------.--------.>+.";
  
  brainfuck(code); // Hello World
  printf("\n");
  
  code = ">>+++[<+++++++++>-]<-{>>+++++++++[<++++++++++>-]<+++++++<[>+<-]>}[>.[-]<[->+<]>-]";
  brainfuck(code); // print a to z
}
