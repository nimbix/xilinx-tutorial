# Xilinx Tutorial for JARVICE platform 

This project will go over how to:
* build FPGA kernels using Xilinx SDAccel. Each kernel will produce a SDx bitstream `*.xclbin` that can be used with the Xilinx Runtime (XRT).
* Create JARVICE applications for Xilinx FPGA machine types

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

This project can be used on Linux or Mac OSX w/ amd64 architecture. The following packages are required:
* curl: command line tool for transferring data with URL syntax
* jq: lightweight and flexible command-line JSON processor
* docker: Linux container runtime 

*NOTE* requires accounts on:
* [JARVICE](https://platform.jarvice.com/) to build SDAccel Examples and create JARVICE application using [PushToCompute](https://jarvice.readthedocs.io/en/latest/cicd/). Sign up [here](https://www.nimbix.net/contact-us/)
* Docker registry (e.g. [DockerHub](https://hub.docker.com/))

#### Ubuntu/Debian
```
sudo apt-get update
sudo apt-get install -y docker.io curl jq
```

#### RedHat/CentOS/Fedora
```
sudo yum install -y docker-io curl jq
```

#### Mac OSX
* Install [Docker for MAC](https://store.docker.com/editions/community/docker-ce-desktop-mac)
* Install [Homebrew](https://brew.sh/)
```
brew install curl jq
```

### Installing

Clone repository from GitHub

```
git clone https://github.com/nimbix/xilinx-tutorial
```

## Building sample JARVICE application using FPGAs
 
This project uses [Xilinx SDAccel Examples](https://github.com/Xilinx/SDAccel_Examples) to demonstrate how to create a JARVICE application using an Xilinx FPGA machine type.

### Build SDAccel bitstreams 

The `build-scripts/build-xcl-examples.sh` uses the [JARVICE API](https://jarvice.readthedocs.io/en/latest/api/) to submit a build job with the `Xilinx SDAccel Development` environment. The default kernels are `sum_scan` and `vdotprod` from `getting_started/misc` section. Update `repo_path` and `kernels` at the beginning of the script to select different kernel from [Xilinx SDAccel Examples](https://github.com/Xilinx/SDAccel_Examples). The `kernels` string uses `|` as a delimiter. 

```
./build-scripts/build-xcl-examples.sh  [-t <target>] -u <jarvice-user> -k <jarvice-apikey> -d <dsa>
```

`-t` SDAccel target flag. sw_emu (default) |hw_emu|hw
`-u` JARVICE username
`-k` JARVICE API key
`-d` Xilinx DSA for target FPGA platform. xilinx_u250_xdma_201820_1 (current support for Alveo u250)

### Create Docker container for JARVICE application

The `build-scripts/build-docker.sh` will create a Docker container for a JARVICE application utilizing a Xilinx FPGA machine type. `docker-build` contains the `Dockerfile` and build context for the container. A JARVICE application requires additional metadata provided by [AppDef.json](https://jarvice.readthedocs.io/en/latest/appdef/). The FPGA machine types will also require `*.xclbin` file for each SDx kernel. [See additional information](https://jarvice.readthedocs.io/en/latest/appdef/#using-xilinx-fpga-binaries)

The following instructions assume the container registry is [DockerHub](https://hub.docker.com/)

```
docker login
./build-scripts/build-docker.sh <docker_repo> <docker_tag>
```

`<docker_repo>` e.g. nimbix/xilinx-tutorial
`<docker_tag>` e.g. latest

*Note* Pushing to a DockerHub repository that does not exist will create a *public* repo

## Create JARVICE application 

Follow the [PushToCompute](https://jarvice.readthedocs.io/en/latest/cicd/) flow using the container created above

Run `/opt/example/run-test.sh` inside JARVICE job to test example FPGA kernel

## Authors

* **Kenneth Hill** - *Initial work* - [NIMBIX](https://github.com/nimbix)

## License

This is an Open Source project - see the [LICENSE.md](LICENSE.md) file for details

