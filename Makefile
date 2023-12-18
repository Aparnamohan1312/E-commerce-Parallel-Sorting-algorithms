NVCC = nvcc
NVCC_FLAGS = -O3

LD_FLAGS    = -lcudart
EXE	        = main
OBJ	        = main.o

.PHONY: run 

run: $(OBJ)
	$(NVCC) $(OBJ) -o $(EXE) $(LD_FLAGS)

main.o:
	$(NVCC) -std=c++11 -rdc=true -c -o $@ main.cu $(NVCC_FLAGS) -DOPTIMIZED 
	
clean:
	rm -rf *.o $(EXE)