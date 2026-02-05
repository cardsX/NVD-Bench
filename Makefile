help:
	@echo "Available commands:"
	@echo "  build       - Build Docker images"
	@echo "  run-burst   - Run GPU stress test (params: DURATION, GPUS, TEMP_LIMIT)"
	@echo "  run-p2p     - Run P2P bandwidth test (params: DURATION, GPUS)"
	@echo "  stop        - Stop active containers"
	@echo "  clean       - Remove images and logs"

# Editable Variables
IMAGE_BURST := gpu-burst-bench
IMAGE_P2P   := gpu-p2p-bench
LOG_PATH    := $(shell pwd)/logs

# Default Parameters
DURATION    ?= 1
TEMP_LIMIT  ?= 85 # Temperature in Celsius
GPUS        ?= all
NAME        ?= gpu_session_$(shell date +%s)

.PHONY: help build-all run-burst run-p2p stop clean

build-all:
	docker build -t $(IMAGE_BURST) -f build/burst.Dockerfile .
	docker build -t $(IMAGE_P2P) -f build/p2p.Dockerfile .

run-p2p:
	@echo "Evaluates the throughput of PCIe lanes or NVLink, ensuring GPUs can exchange data without CPU bottlenecks."
	docker run --rm --name $(NAME) \
		--gpus '"$(GPUS)"' \
        -v $(LOG_PATH):/var/log \
        -e DURATION_MIN=$(DURATION) \
        $(IMAGE_P2P)

run-burst:
    @echo "Monitors thermal saturation points, power draw consistency (Watts), and identifies thermal throttling events where the GPU drops its clock speed to prevent overheating."
	docker run --rm --name $(NAME) \
		--gpus '"$(GPUS)"' \
		-v $(LOG_PATH):/var/log \
		-e DURATION_MIN=$(DURATION) \
		-e MAX_TEMP_LIMIT=$(TEMP_LIMIT) \
		$(IMAGE_BURST)

stop:
	@echo "Stop active NVD-Bench containers..."
	docker ps -q --filter "ancestor=$(IMAGE_BURST)" | xargs -r docker stop
	docker ps -q --filter "ancestor=$(IMAGE_P2P)" | xargs -r docker stop

clean:
	@echo "Clean images and temporary files..."
	docker rmi $(IMAGE_BURST) $(IMAGE_P2P) || true
	rm -rf build/temp_*
