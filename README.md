# AzureBatch_CLI     
This script demonstrates interacting with the Azure Batch Service using the Azure CLI (also known as the xplat cli).cds
sdf
## Features:
•	Works with an Azure Batch account set to “UserSubscription” (run in your own subscription)
•	Authenticates with AAD (required when running batch in UserSubscription mode
•	Connect worker nodes to a VNET/Subnet you specify (for high speed, private network connectivity between worker nodes and a head node/NFS server).
•	Syntax:    
o	./sendtoazurebatch.sh -i /mnt/resource/batch/tasks/shared/files/ -c /mnt/resource/batch/tasks/shared/files/calpuff.exe -j MyJob -p MyPool
•	Requires Azure CLI 2 installed. See https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
•	The head node where this script is run should have the same mount point path to the inp and met files as the worker nodes. E.g. /mnt/resource/batch/tasks/shared/files/ should also exist on the head node.
o	If the head node VM and NFS server are the same VM, then simply create the nfs mount point to itself. 
•	The az login command on 42
o	Once you have authenticated to Azure using this command, you can comment it out as it can become annoying. Azure will cache the AAD login for a period of time in your shell. 
o	Alternatively you can setup a Service Principal login. I’ve added the code (commented out) and links to set this up. 
•	Ensure you have a VNET with a subnet already created in the Azure Portal. Also, the head node VM should already be connected to this same VNET/Subnet. You may need to recreate or shutdown/copy the head node VM as VMs cannot change VNETs at this time. 
•	To obtain the SUBNET_ID, browse to https://resources.azure.com/
o	Click Subscriptions->your subscription where you are running batch->resourceGroups->select the resource group containing the VNET->Providers->Microsoft.Network->virtualNetworks->subnets->select the subnet (sometimes called ‘default’) and copy the contents of “id” into the SUBNET_ID. It should resemble something like:
	/subscriptions/388994e7-efd5-43cc-a103-71e9071ea717/resourceGroups/CentOS/providers/Microsoft.Network/virtualNetworks/CentOS-vnet/subnets/default
•	You will also have to adjust the IP of the NFS server in STARTUP_CMDS. 
•	Also with NFS there are lots of tuning options. I’m no expert but I recommend playing with the NFS options to get the file read/write performance up. 
o	I followed this article when setting up NFS on my head node. https://www.howtoforge.com/tutorial/setting-up-an-nfs-server-and-client-on-centos-7/ 

