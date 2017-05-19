#!/bin/bash
# Sample BASH script for using Azure Batch in 'User Subscription' mode. It assumes CentOS 7 as the worker node O/S.
# Developed by Kevin Hilscher, Microsoft.

# Requires Azure CLI 2 installed. See https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

# For examples of using Azure Batch with the CLI, see https://docs.microsoft.com/en-us/azure/batch/batch-cli-get-started

# The head node where this script is run should have the same mount point to the input files as the worker nodes

# Syntax
# ./sendtoazurebatch.sh -i /mnt/resource/batch/tasks/shared/files/ -c /mnt/resource/batch/tasks/shared/files/some.exe -j MyJob -p MyPool

while getopts i:c:j:p: option
do
 case "${option}"
 in
 i) INPUT_FILE_PATH=${OPTARG};;
 c) EXE_PATH=${OPTARG};;
 j) JOB_NAME=${OPTARG};;
 p) POOL_NAME=$OPTARG;;
 esac
done

BATCHACCOUNT="MYBATCHACCOUNT"
RESOURCEGROUP="MYRESOURCEGROUP"
BATCHURL="https://MYBATCHACCOUNT.westus.batch.azure.com/"
POOL_NODE_COUNT="2"
POOL_VM_SIZE="Standard_A1" #For testing, to keep costs low.
MAX_TASKS_PER_NODE="1" #Can go up to 4 x number of cores on VM
NODE_OS_PUBLISHER="OpenLogic"
NODE_OS_OFFER="CentOS"
NODE_OS_SKU="7.2"
NODE_AGENT_SKU="batch.node.centos 7"
INPUT_FILE_EXTENSION="*.inp"
STARTUP_CMDS="/bin/bash -c 'set -e; set -o pipefail; yum install nfs-utils -y; mkdir /mnt/resource/batch/tasks/shared/files/; mount 10.8.3.4:/nfs /mnt/resource/batch/tasks/shared/files/; wait'"
SUBNET_ID="/subscriptions/112233e7-efd5-43cc-a103-84e9071ea717/resourceGroups/CentOS/providers/Microsoft.Network/virtualNetworks/CentOS-vnet/subnets/default" # See https://docs.microsoft.com/en-us/rest/api/batchservice/add-a-pool-to-an-account#bk_netconf
AAD_APPLICATION_ID=""
SERVICE_PRINCIPAL_PWD=""
TENANT_ID=""

# Authenticate to CLI session interactively. If you do this once, you can comment this out as it'll cache the login
az login

# Authenticate to CLI session via Service Principal.
# To create a Service Principal, see https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli
# or https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-create-service-principal-portal
# az login --service-principal -u $AAD_APPLICATION_ID --password $SERVICE_PRINCIPAL_PWD --tenant $TENANT_ID

# Connect to the Batch account
az batch account login -g $RESOURCEGROUP -n $BATCHACCOUNT

# Create a new Linux pool with a virtual machine configuration. The image reference 
# and node agent SKUs ID can be selected from the ouptputs of the above list command.
# The image reference is in the format: {publisher}:{offer}:{sku}:{version} where {version} is
# optional and will default to 'latest'.
# Use 'az batch pool node-agent-skus list' to determine --node-agent-sku-id

# We need to send Json to Batch because the CLI doesn't support all the options we need when creating a Pool
# Batch API Reference https://docs.microsoft.com/en-us/rest/api/batchservice/
# https://docs.microsoft.com/en-us/rest/api/batchservice/add-a-pool-to-an-account

echo -e "{
  \"odata.metadata\":\"$BATCHURL\$metadata#pools/@Element\",
  \"id\":\"$POOL_NAME\",
  \"displayName\":\"$POOL_NAME\",
  \"vmSize\":\"$POOL_VM_SIZE\",
  \"virtualMachineConfiguration\": {
      \"imageReference\": {
        \"publisher\":\"$NODE_OS_PUBLISHER\",
        \"offer\":\"$NODE_OS_OFFER\",
        \"sku\":\"$NODE_OS_SKU\",
        \"version\":\"latest\"
      },
      \"nodeAgentSKUId\":\"$NODE_AGENT_SKU\"
  },
  \"resizeTimeout\":\"PT15M\",
  \"maxTasksPerNode\":$MAX_TASKS_PER_NODE,
  \"taskSchedulingPolicy\": {
    \"nodeFillType\":\"Spread\"
  },
  \"enableAutoScale\":false,
  \"enableInterNodeCommunication\":true,
  \"networkConfiguration\": {
    \"subnetId\":\"$SUBNET_ID\"
  },
  \"startTask\": {
    \"commandLine\":\"$STARTUP_CMDS\",
    \"userIdentity\": {
      \"autoUser\": {
        \"scope\":\"pool\",
        \"elevationLevel\":\"admin\"
      }
    },
    \"maxTaskRetryCount\":2,
    \"waitForSuccess\":true
  }
}" > $POOL_NAME.json

# Create the pool
az batch pool create --json-file $POOL_NAME.json

# Resize pool to desired number of nodes
az batch pool resize --pool-id $POOL_NAME --target-dedicated $POOL_NODE_COUNT

# Create job
az batch job create --id $JOB_NAME --pool-id $POOL_NAME

# Now we will add tasks to the job. One task per .inp file found.
# We need to send Json to Batch because the CLI doesn't support all the options we need when creating a task
# Batch API Reference https://docs.microsoft.com/en-us/rest/api/batchservice/
echo Searching for input files at: $INPUT_FILE_PATH
FILES_FOUND="$(find $INPUT_FILE_PATH -name '$INPUT_FILE_EXTENSION' | wc -l)"
echo 'Total input files found: ' $FILES_FOUND

COUNT=1
for i in $( find $INPUT_FILE_PATH -name '$INPUT_FILE_EXTENSION' ); do

    echo -e "{
        \"odata.metadata\":\"$BATCHURL\$metadata#tasks/@Element\",
        \"id\":\"$COUNT\",
        \"commandLine\":\"/bin/bash -c 'set -e; set -o pipefail; ${EXE_PATH} ${i}; wait'\",
        \"userIdentity\": {
            \"autoUser\": {
            \"scope\":\"pool\",
            \"elevationLevel\":\"admin\"
            }
        }
    }" > task$COUNT.json

    #az batch task create --job-id $JOB_NAME --command-line "/bin/bash -c 'set -e; set -o pipefail; ${EXE_PATH} ${i}; wait'" --task-id $COUNT
    az batch task create --job-id $JOB_NAME --json-file task$COUNT.json
    ((COUNT++))
done

# Now that all the tasks are added - we can update the job so that it will automatically
# be marked as completed once all the tasks are finished.
az batch job set --job-id $JOB_NAME --on-all-tasks-complete terminateJob

# Delete job along with its tasks
read -r -p "Delete job? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
then
    az batch job delete --job-id $JOB_NAME --yes
fi

# Delete pool
read -r -p "Delete pool? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
then
    az batch pool delete --pool-id $POOL_NAME --yes
fi

# TODO
# Display job status
