COMPONENT=Demo1AppC
# CFLAGS += -I$(TOSDIR)/lib/printf
TINYOS_ROOT_DIR?=../..
TINYOS_OS_DIR?=$(TINYOS_ROOT_DIR)/tos
CFLAGS += -I$(TINYOS_OS_DIR)/lib/printf
# include $(MAKERULES)
include $(TINYOS_ROOT_DIR)/Makefile.include

