#!/bin/bash

# Example kernels to build from SDAccel Examples on GitHub
# Kernels string uses | delimiter
repo_path="SDAccel_Examples/getting_started/misc"
kernels="'sum_scan|vdotprod'"

usage(){
    echo
    echo "build-xcl-examples.sh  [-t <target>] -u <jarvice-user> -k <jarvice-apikey> -d <dsa>"
    echo
}

my_error(){
    echo
    printf "ERROR: $1"
    echo 
    usage
    exit -1
}

which curl 2>&1 > /dev/null || my_error "curl not in PATH"
which jq 2>&1 > /dev/null || my_error "jq not in PATH"

OPTIND=1
jarvice_user=""
jarvice_apikey=""
DSA=""
# Default to SW emulation
TARGET="sw_emu"
while getopts "u:k:d:t:" opt; do
    case "$opt" in
        u)
            jarvice_user=$OPTARG
            ;;
        k)
            jarvice_apikey=$OPTARG
            ;;
        d)
            DSA=$OPTARG
            ;;
        t)
            TARGET=$OPTARG
            ;;
    esac
done

[[ -z ${jarvice_user} ]] && my_error "JARVICE user not set"
[[ -z ${jarvice_apikey} ]] && my_error "JARVICE apikey not set"
[[ -z ${DSA} ]] && my_error "Xilinx DSA not set"
workdir=$(mktemp -d)
cd ${workdir}
# JARVICE job for Xilinx SDAccel environment
cat <<- EOF > ${workdir}/job.json
{
  "app": "xilinx-sdx_dev_2018_2_xdf",
  "staging": false,
  "checkedout": false,
  "application": {
    "command": "server",
    "geometry": "1904x943"
  },
  "machine": {
    "type": "n2",
    "nodes": 1
  },
  "vault": {
    "name": "drop.jarvice.com",
    "readonly": false,
    "force": false
  },
  "user": {
    "username": "${jarvice_user}",
    "apikey": "${jarvice_apikey}"
  }
}
EOF
# Use RESTful API to interact with JARVICE
jarvice_api="https://api.jarvice.com/jarvice"
rest_options="-H \"Content-Type: application/json\"" 
rest_options+="-X POST -d @${workdir}/job.json"
job=$(curl ${rest_options} "${jarvice_api}/submit" 2> /dev/null | jq -r .number)
echo Started JARVICE job: $job
# Check if job is running
rest_options="-H \"Content-Type: application/json\" -X GET"
rest_options+=" ${jarvice_api}/status?username=${jarvice_user}"
rest_options+="&apikey=${jarvice_apikey}&number=${job}"
while true; do
    status=$(curl ${rest_options} 2> /dev/null | jq -r .[].job_status)
    if [ "${status}" = "PROCESSING STARTING" ]; then
        break
    fi    
    sleep 15
done
sleep 10
# Get connection information for job
rest_options="-H \"Content-Type: application/json\" -X GET"
rest_options+=" ${jarvice_api}/connect?username=${jarvice_user}"
rest_options+="&apikey=${jarvice_apikey}&number=${job}"
connect=$(curl ${rest_options} 2> /dev/null)
address=$(echo ${connect} | jq -r .address)
password=$(echo ${connect} | jq -r .password)
# Script to run on JARVICE
# 'EOF' w/ '' prevents bash variable substitution
cat <<- 'EOF' > ${workdir}/run.sh
#!/bin/bash
my_error(){
    printf "ERROR: $1"
    exit -1
}
set -e
OPTIND=1
DSA=""
repo_path=""
kernels=""
TARGET=""
jarvice_user=""
jarvice_apikey=""
jarvice_job=""
retvault=""
while getopts "d:r:k:t:u:K:j:R:" opt; do
    case "$opt" in
        d)
            DSA=$OPTARG
            ;;
        r)  
            repo_path=$OPTARG
            ;;
        k)
            kernels=$OPTARG
            ;;
        t)
            TARGET=$OPTARG
            ;;
        u)
            jarvice_user=$OPTARG
            ;;
        K)
            jarvice_apikey=$OPTARG
            ;;
        j)
            jarvice_job=$OPTARG
            ;;
        R)
            retvault=$OPTARG
            ;;
    esac
done
[[ -z $DSA ]] && my_error "DSA not set\n"
[[ -z $repo_path ]] && my_error "repo_path not set\n"
[[ -z ${kernels} ]] && my_error "kernels not set\n"
[[ -z ${TARGET} ]] && my_error "TARGET not set\n"
[[ -z ${jarvice_user} ]] && my_error "JARVICE user not set\n"
[[ -z ${jarvice_apikey} ]] && my_error "JARVICE API key not set\n"
[[ -z ${jarvice_job} ]] && my_error "JARVICE job number not set\n"
[[ -z ${retvault} ]] && my_error "Return vault not set\n"
workdir=$(mktemp -d)
cd ${workdir}
mkdir -p ${workdir}/exe
mkdir -p ${workdir}/xclbin/${DSA}
# Clone Xilinx SDAccel Example directory
# NOTE: clone not using /data. Will not persist past session termination
git clone --depth 1 https://github.com/Xilinx/SDAccel_Examples
source /opt/xilinx/xilinx-setup.sh
# Compile SDAccel example kernels from ${kernels}
# Turn kernels into an array
kernels=(${kernels//|/ })
# This loop will spawn parallel threads
for kernel in ${kernels[@]}; do
(   
    make -C ${repo_path}/${kernel} DEVICES=${DSA} TARGET=${TARGET}
    cp ${repo_path}/${kernel}/xclbin/*.xclbin ${workdir}/xclbin/${DSA}
    cp ${repo_path}/${kernel}/${kernel} ${workdir}/exe
) &
done
wait
sleep 5
cd ${workdir}
tar -czf ${DSA}.tar.gz exe xclbin
# Return examples to user vault
cp ${DSA}.tar.gz ${retvault}
rm -rf ${workdir}
# Send shutdown for job
jarvice_shutdown="https://api.jarvice.com/jarvice/shutdown"
jarvice_shutdown+="?username=${jarvice_user}&apikey=${jarvice_apikey}"
jarvice_shutdown+="&number=${jarvice_job}"
curl -X GET ${jarvice_shutdown} 
EOF
# Setup temporary ssh key with job
ssh_options="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
ssh-keygen -f ${workdir}/id_rsa -N "" 2>&1 > /dev/null
ssh_cmd="mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
echo "Enter this password at prompt: ${password}"
cat ${workdir}/id_rsa.pub | ssh ${ssh_options} nimbix@${address} ${ssh_cmd}
# Use temporary ssh key to authenticate to JARVICE job
ssh_options+=" -i ${workdir}/id_rsa"
# Create unique vault directory for run
ssh_cmd="mktemp -d --tmpdir=/data xcl_XXX"
retdir=$(ssh ${ssh_options} nimbix@${address} ${ssh_cmd})
echo "Job ${job} building ${retdir}/${DSA}.tar.gz"
echo "Check JARVICE dashboard for status"
# Copy run.sh to JARVICE job
ssh_cmd="cat > /tmp/run.sh && chmod +x /tmp/run.sh" 
cat ${workdir}/run.sh | ssh ${ssh_options} nimbix@${address} ${ssh_cmd} 
# Run SDAccel kernel build script in JARVICE job
# nohup prevents build from stopping
# run.sh will request shutdown using JARVICE API
ssh_cmd="sh -c \"( ( nohup /tmp/run.sh -d ${DSA} -r ${repo_path} -k ${kernels}"
ssh_cmd+=" -t ${TARGET} -u ${jarvice_user} -K ${jarvice_apikey} -j ${job}"
ssh_cmd+=" -R ${retdir} > xcl.out 2> xcl.err ) & )\""
ssh ${ssh_options} nimbix@${address} "${ssh_cmd}"
# Remove work directory
rm -rf ${workdir}
