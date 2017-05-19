# Azure Batch CLI     
This script demonstrates interacting with the Azure Batch (https://azure.microsoft.com/en-us/services/batch/) service using the Azure CLI (also known as the xplat cli). 

Most Azure Batch examples show uploading/downloading input and executable files from Azure Blob Storage. However, in the case where a large volume of files needs to be copied to the worker nodes, or copied off the worker nodes, Azure Blob storage throughput limits and throttling may slow down these jobs. To work around this issue you can run the worker nodes in your own VNET/Subnet next to an existing NFS server VM, which provides low latency, greater network bandwidth and no throttling limits (beyond the VM bandwidth limits). 

The `sendtoazurebatch.sh` script is designed to deploy and run Linux worker nodes in your own subscription and VNET/Subnet. The worker nodes connect to an existing NFS server VM (which you manually provision) that contains the input files and executable to run. Often this NFS Server VM can also act as your head node, where you run this script from. This script was built around CentOS 7 but can be easily modified to support any Linux distro supported by Azure Batch.

## Features
- Works with an Azure Batch account set to “UserSubscription” (run in your own subscription)
- Authenticates with AAD (required when running batch in "UserSubscription" mode
- Connect worker nodes to a VNET/Subnet in your subscription (for high speed, low latency private network connectivity between worker nodes and the head node/NFS server).
- Runs startup commands and task commands as 'admin'

## Syntax   
`./sendtoazurebatch.sh -i /mnt/resource/batch/tasks/shared/files/ -c /mnt/resource/batch/tasks/shared/files/calpuff.exe -j MyJob -p MyPool`

where:
- -i is the path to the input files (it will look for files with the extension you specify in 
- -c is the path to the executable
- -j is the name of the Job
- -p is the name of the Pool

The script will perform the following:

- Create one Pool
- Create one Job
- Create one task for each input file found with the extension specified in INPUT_FILE_EXTENSION
- Install the NFS client on the CentOS 7 worker VMs
- Mount the NFS mount point exported from the NFS server (which can also be the Head node VM)
- Run the executable with the input file as an argument, spreading these tasks across all the worker nodes.
- The executable writes its output back to the same NFS mount point

## Requirements
1. You have already setup an Azure Batch account with Pool Allocation mode set to "User Subscription"
1. Script requires Azure CLI 2 installed. See https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
1. The head node where this script is run should have the same mount point path to the input files as the worker nodes. E.g. /mnt/resource/batch/tasks/shared/files/ should also exist on the head node.
1. If the head node VM and NFS server are the same VM, then simply create the nfs mount point to itself. 
1.	The az login command on line 42...once you have authenticated to Azure using this command, you can comment it out as it can become annoying. Azure will cache the AAD login for a period of time in your shell. Alternatively you can setup a Service Principal login. I’ve added the code (commented out) and links to set this up. 
1.	Ensure you have a VNET with a subnet already created in the Azure Portal. Also, the head node VM should already be connected to this same VNET/Subnet.  
1.	To obtain the SUBNET_ID, browse to https://resources.azure.com/ and perform the following: Click Subscriptions->your subscription where you are running Azure Batch->resourceGroups->select the resource group containing the VNET->Providers->Microsoft.Network->virtualNetworks->subnets->select the subnet (sometimes called ‘default’) and copy the contents of “id” into the SUBNET_ID. It should resemble something like: `/subscriptions/388994e7-efd5-43cc-a103-71e9071ea717/resourceGroups/CentOS/providers/Microsoft.Network/virtualNetworks/CentOS-vnet/subnets/default`
1. You will also have to adjust the IP of the NFS server in STARTUP_CMDS and add any other startup commands, separated by a `;`
1. Also with NFS there are lots of tuning options. I recommend playing with the NFS options to optimize file read/write performance. 


