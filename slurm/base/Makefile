include ../../.env
IMAGE = clustercockpit/slurm.base
SLURM_VERSION = 24.05.3
.PHONY: build clean

build:
	docker build -t $(IMAGE):$(SLURM_VERSION) .

clean:
	@[ -z $(docker images -q $(IMAGE):$(SLURM_VERSION)) ] || docker rmi $(IMAGE):$(SLURM_VERSION)
