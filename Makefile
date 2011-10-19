all:	bf

bf:	brainfuck.cu
	nvcc -o $@ $^