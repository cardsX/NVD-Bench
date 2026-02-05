# NVD-Bench
A Docker-based monitoring and stress-test suite for NVIDIA GPU hardware validation and P2P performance benchmarking.

---

**NVD-Bench** is a toolkit based on **microservices (Docker)** designed for validation, stress-testing, and performance monitoring of NVIDIA multi-GPU systems. 

The primary goal of this project is to verify hardware health, analyze thermal efficiency, and measure interconnect bandwidth between cards in an isolated and reproducible environment.

---

## Features
* **Intensive Stress Test (Burst):** Maximum computational load to test the stability of Power Supply Units (PSU) and cooling systems.
* **Peer-to-Peer Benchmark (P2P):** Measurement of latency and bandwidth (GB/s) between GPU pairs via PCIe bus or NVLink.
* **Real-time Monitoring:** Automatic capture of critical metrics (Temperature, Power Draw, Clock, Utilization) into CSV files for long-term analysis.
* **Microservices Architecture:** Each test runs inside an isolated container, ensuring the host system's drivers and libraries remain untouched.



## Prerequisites
* **Host OS:** Linux (Ubuntu recommended) with NVIDIA Drivers installed.
* **Docker:** Version 20.10+ with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html).
* **Tools:** `make` and `bash`.

---

## Usage
To run the tests, use the following commands:
- `make build`: To prepare the environment.
- `make run-burst DURATION=10`: To run a 10-minute stress test.
- `make run-p2p`: To check GPU-to-GPU communication.
- `make help`: Display the help message.
---


## Quick Start

### 1. Initialization
Prepare system folders and set correct log permissions:
```bash
chmod +x install.sh
./install.sh
```

### 2. Build Images
Compile the microservices for stress testing and P2P communication:
```bash
make build
```

### 3. Running Tests
You can customize tests by passing variables directly to the make command.

| Command	| Description |	Default  Parameters |
| ------- | ----------- | ------------------- |
| `make run-burst`	| Starts thermal stress test	  | DURATION=1 (min), GPUS=all |
| `make run-p2p`    | Starts interconnect benchmark	| GPUS=all                   |


#### Advanced Usage Examples:
```bash
# Run a 30-minute stress test on GPU 0 only
make run-burst DURATION=30 GPUS=device=0

# Run a test with a safety thermal limit set to 80°C
make run-burst DURATION=10 TEMP_LIMIT=80
```


## Metric Analysis

All logs are saved in the ./logs/ folder in CSV format. Each file includes:

- `timestamp`: Time of recording.
- `gpu_util`: GPU Core utilization percentage.
- `temp_c`: GPU Core temperature in Celsius.
- `pwr_w`: Instantaneous power consumption in Watts.
- `clk_mhz`: Operating graphics clock frequency.


## Hardware Safety

The system includes a software-level protection layer: if the GPU temperature exceeds the value set in TEMP_LIMIT (default 85°C), the microservice immediately terminates the process to prevent permanent hardware damage.


## Cleanup

To stop active tests or remove built images from your system:
```bash
make stop   # Stop any active test containers
make clean  # Remove Docker images and temporary build files
```



