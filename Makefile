
KERNEL_SOURCE_PATH ?= /lib/modules/$(shell uname -r)/build
CROSS_COMPILE_PREFIX ?= 

ARCH ?= arm

obj-m := sqrt.o

CC = $(CROSS_COMPILE_PREFIX)gcc

all:
	@echo "--------------------------------------------------------"
	@echo "Building Kernel Module for ARCH=$(ARCH) using source tree at:"
	@echo "$(KERNEL_SOURCE_PATH)"
	@echo "--------------------------------------------------------"
	$(MAKE) -C $(KERNEL_SOURCE_PATH) M=$(PWD) modules

clean:
	@echo "--------------------------------------------------------"
	@echo "Cleaning up generated files..."
	@echo "--------------------------------------------------------"
	$(MAKE) -C $(KERNEL_SOURCE_PATH) M=$(PWD) clean
	rm -f stress_test *.o *~ core .depend .*.cmd *.ko *.mod.c
	rm -f Module.symvers modules.order
	
stress_test: stress_test.c
	$(CC) stress_test.c -o stress_test -lm -lpthread

# Phony targets to prevent confusion with similarly named files
.PHONY: all clean stress_test
