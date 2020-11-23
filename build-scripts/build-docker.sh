#!/bin/bash
set -e

usage(){
    echo
    echo "Build example Docker container for JARVICE bitstream protection"
    echo 
    echo "build-docker.sh [-h]"
    echo "build-docker.sh [-f dsa] [-m machine-type] [-p program-bitstream]"
    echo "    [-R remove-bitstream] [-r xilinx-runtime] docker_repo docker_tag"
    echo ""
    exit 0
}

which docker 2>&1 > /dev/null || exit 1

workspace="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
# Use Docker workspace for build
workspace="${workspace}/../docker-build"

OPTIND=1
DSA=""
JARVICE_MACHINE=""
XCLBIN_PROGRAM=""
XCLBIN_REMOVE=""
XRT_RUNTIME=""
DOCKER_REPO=""
DOCKER_TAG=""
while getopts "hf:m:p:R:r:" opt; do
    case "$opt" in
        h)
            usage
            ;;
        f)
            DSA=$OPTARG
            ;;
        m)
            JARVICE_MACHINE=$OPTARG
            ;;
        p)
            XCLBIN_PROGRAM=$OPTARG
            ;;
        R)
            XCLBIN_REMOVE=$OPTARG
            ;;
        r)
            XRT_RUNTIME=$OPTARG
            ;;
        ?)
            usage
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z $DSA ]; then 
    DSA=xilinx_u250_xdma_201820_1
    printf "WARNING: Xilinx DSA not set\n"
    printf "\t Setting DSA := ${DSA}\n"
fi
if [ -z $JARVICE_MACHINE ]; then
    JARVICE_MACHINE=nx6u
    printf "WARNING: JARVICE Machine Type not set\n"
    printf "\t Setting JARVICE_MACHINE := ${JARVICE_MACHINE}\n"
fi
if [ -z $XCLBIN_PROGRAM ]; then
    XCLBIN_PROGRAM=krnl_vdotprod.hw.xilinx_u250_xdma_201820_1.xclbin
    printf "WARNING: Xilinx programming bitstream not set\n"
    printf "\t Setting XCLBIN_PROGRAM := ${XCLBIN_PROGRAM}\n"
fi
if [ -z $XCLBIN_REMOVE ]; then
    XCLBIN_REMOVE=krnl_sum_scan.hw.xilinx_u250_xdma_201820_1.xclbin
    printf "WARNING: Xilinx protection bitstreams not set\n"
    printf "\t Setting XCLBIN_REMOVE := ${XCLBIN_REMOVE}\n"
fi
if [ -z $XRT_RUNTIME ]; then
    XRT_RUNTIME=201802.2.1.83_16.04
    printf "WARNING: Installation for Xilinx runtime not set\n"
    printf "\t Setting XRT_RUNTIME := ${XRT_RUNTIME}\n"
fi
# Check for correct file extensions 
if [ "${XCLBIN_PROGRAM##*.}" = "*.xclbin" ]; then
    printf "ERROR: bitstream must be *.xclbin file\n"
    exit -1
fi
# Update Dockerfile for XRT runtime verion
sed "s/<xrt-runtime>/$XRT_RUNTIME/g" ${workspace}/Dockerfile > \
        ${workspace}/Dockerfile.tmp

DOCKER_REPO=$1
DOCKER_TAG=$2
if [ -z ${DOCKER_REPO} ] || [ -z ${DOCKER_TAG} ]; then
    printf "CRITICAL WARNING: Missing Docker repository information\n"
    printf "\t Build exiting\n"
    usage
fi
docker build --build-arg DSA=${DSA} \
    --build-arg JARVICE_MACHINE=${JARVICE_MACHINE} \
    --build-arg XCLBIN_PROGRAM=${XCLBIN_PROGRAM} \
    --build-arg XCLBIN_REMOVE=${XCLBIN_REMOVE} \
    --file ${workspace}/Dockerfile.tmp \
    -t ${DOCKER_REPO}:${DOCKER_TAG} ${workspace} 

docker push ${DOCKER_REPO}:${DOCKER_TAG}

rm ${workspace}/Dockerfile.tmp
