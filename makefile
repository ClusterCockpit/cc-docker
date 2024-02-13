SLURM_ROOT_DIR = /usr
SLURM_INC_DIR = /usr/include/slurm
SLURM_LIB_DIR = /usr/lib64/slurm
SLURM_BUILD = 22.05.2
SLURM_BUILD_DIR = /opt/slurm

PLUGIN_TYPE = prep
PLUGIN_NAME = pika
PLUGIN_FILE = $(PLUGIN_TYPE)_$(PLUGIN_NAME).so

SRC_FILE = slurm-prep-pika_v4.c

CC      = gcc
CFLAGS  ?= -Wall -fPIC -g -I$(SLURM_INC_DIR) -I$(SLURM_BUILD_DIR) -I/opt/slurm/src/ -I/opt/nats.c/src
LDFLAGS ?= --shared -L.

all: $(PLUGIN_FILE)

default: $(PLUGIN_FILE)

$(PLUGIN_FILE): $(SRC_FILE)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

install: $(PLUGIN_FILE)
	install -m 755 $(PLUGIN_FILE) $(SLURM_LIB_DIR)

clean:
	rm -f $(PLUGIN_FILE)

mrproper: clean
