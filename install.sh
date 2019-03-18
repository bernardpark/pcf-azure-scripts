#!/bin/bash
#******************************************************************************
#    GCP PCF (PKS and/or PAS) Installation Script
#******************************************************************************i
#
# DESCRIPTION
#    Automates PCF Installation on GCP using the GCP CLI.
#
#
#==============================================================================
#   Global properties and tags. Modify according to your configuration.
#==============================================================================

# Application and Service Principal
SBS_ID=""
TNT_ID=""
APP_NME="BPARK Service Principal for BOSH"
APP_PWD="AppPassword"
APP_CPI="http://BPARKBOSHAzureCPI"
APP_ID=""

# Region
RGN="eastus"

# Resource Group
RSC_GRP_NME="pcf-rg"

# Network Security Groups
NSG_NME_PCF="pcf-nsg"
NSG_NME_OM="opsmgr-nsg"

# Virtual Network
VNT_NME="pcf-virtual-network"
VNT_CIDR="10.0.0.0/16"

SN_INF_NME="pcf-infrastructure-subnet"
SN_INF_CIDR="10.0.4.0/26"

SN_PAS_NME="pcf-pas-subnet"
SN_PAS_CIDR="10.0.12.0/22"

SN_SVC_NME="pcf-services-subnet"
SN_SVC_CIDR="10.0.8.0/22"

# Bosh Storage
STR_NME="bparkstorage"

CNC_STR=""

BLB_OM="opsmanager"
BLB_BSH="bosh"
BLB_STM="stemcell"

TBL_STM="stemcells"

# Additional Storage
## Standard_LRS or Premium_LRS
STR_TYP="Standard_LRS"

DPL_STR_NME_1="bparkdeploystorage1"
DPL_STR_NME_2="bparkdeploystorage2"
DPL_STR_NME_3="bparkdeploystorage3"
DPL_STR_NME_4="bparkdeploystorage4"
DPL_STR_NME_5="bparkdeploystorage5"

CNC_STR_1=""
CNC_STR_1=""
CNC_STR_1=""
CNC_STR_1=""
CNC_STR_1=""

# Load Balancers
LB_PAS_NME="pcf-lb"
LB_PAS_PL_NME="pcf-lb-be-pool"
LB_PAS_FE_IP="pcf-lb-fe-ip"
LB_PAS_PB_IP="pcf-lb-ip"
LB_PAS_PRB_NME="http8080"
LB_PAS_RLE_NME_HTTP="http"
LB_PAS_RLE_NME_HTTPS="https"

# Ops Manager
OM_URL="https://opsmanagereastus.blob.core.windows.net/images/ops-manager-2.3-build.268.vhd"
OM_NME="ops-manager-2.3-build.268.vhd"
OM_PUB_IP_NME="ops-manager-ip"
OM_PUB_IP=""
OM_PRI_IP="10.0.4.4"
OM_NIC="opsman-nic"
OM_KEY="opsman"
OM_IMG="ops-manager-2.3"
OM_VM="ops-manager-2.3"
OM_DSK_NME="opsman-2.3-osdisk"
OM_DSK_SZE="128"

#==============================================================================
#   Resources names. Modify to match your convention.
#==============================================================================

# VPC

#==============================================================================
#   Configuration details. No need to modify.
#==============================================================================

# VPC

#==============================================================================
#   Installation script below. Do not modify.
#==============================================================================

echo "*********************************************************************************************************"
echo "*** THIS SCRIPT WILL CONFIGURE AND USE YOUR GCP CLI. BEFORE YOU BEGIN MAKE SURE THIS SCRIPT IS SECURE ***"
echo "*********************************** REQUIRES gcloud and gsutil ******************************************"
echo "*********************************************************************************************************"
echo ""
echo ""

# Create Application and Service Principal
echo ""
echo "*********************************************************************************************************"
echo "******************************* Creating Application and Service Principal ******************************"
echo ""

SBS_ID=$(az account list | jq -r .[].id)

az account set \
  --subscription $SBS_ID

TNT_ID=$(az account list | jq -r .[].tenantId)

az ad app create \
  --display-name "$APP_NME" \
  --password "$APP_PWD" \
  --homepage "$APP_CPI" \
  --identifier-uris "$APP_CPI" \
  > ./app-output.json

echo "Created Application (output in app-output.json)"

APP_ID=$(cat app-output.json | jq -r .appId)

az ad sp create \
  --id $APP_ID \
  > ./sp-output.json

echo "Created Service Principal (output in sp-output.json)"

SP_NME=$(cat sp-output.json | jq -r .servicePrincipalNames[0])

az role assignment create \
  --assignee "$SP_NME" \
  --role "Contributor" \
  --scope /subscriptions/$SBS_ID

echo "Assigned 'Contributor' role to assignee: $SP_NME"

az provider register \
  --namespace Microsoft.Storage
az provider register \
  --namespace Microsoft.Network
az provider register \
  --namespace Microsoft.Compute

echo "Registered subscription: $SP_NME to [Microsoft.Storage,Microsoft.Network, Microsoft.Compute]"

# Deploy Ops Manager
echo ""
echo "*********************************************************************************************************"
echo "***************************************** Deploying Ops Manager *****************************************"
echo ""

az group create \
  --location $RGN \
  --name $RSC_GRP_NME \
  --subscription $SBS_ID

echo "Created Resource Group: $RSC_GRP_NME"

az network nsg create \
  --location $RGN \
  --name $NSG_NME_PCF \
  --resource-group $RSC_GRP_NME

echo "Created Network Security Group: $NSG_NME_PCF"

az network nsg rule create \
  --name ssh \
  --nsg-name $NSG_NME_PCF \
  --resource-group $RSC_GRP_NME \
  --protocol Tcp \
  --priority 100 \
  --destination-port-range '22'

az network nsg rule create \
  --name http \
  --nsg-name $NSG_NME_PCF \
  --resource-group $RSC_GRP_NME \
  --protocol Tcp \
  --priority 200 \
  --destination-port-range '80'

az network nsg rule create \
  --name https \
  --nsg-name $NSG_NME_PCF \
  --resource-group $RSC_GRP_NME \
  --protocol Tcp \
  --priority 300 \
  --destination-port-range '443'

az network nsg rule create \
  --name diego-ssh \
  --nsg-name $NSG_NME_PCF \
  --resource-group $RSC_GRP_NME \
  --protocol Tcp \
  --priority 400 \
  --destination-port-range '2222'

echo "Created Network Security Rules in $NSG_NME_PCF for [ssh,http,https,diego-ssh]"

az network nsg create \
  --location $RGN \
  --name $NSG_NME_OM \
  --resource-group $RSC_GRP_NME \

echo "Created Network Security Group: $NSG_NME_OM"

az network nsg rule create \
  --name http \
  --nsg-name $NSG_NME_OM \
  --resource-group $RSC_GRP_NME \
  --protocol Tcp \
  --priority 100 \
  --destination-port-range '80'

az network nsg rule create \
  --name https \
  --nsg-name $NSG_NME_OM \
  --resource-group $RSC_GRP_NME \
  --protocol Tcp \
  --priority 200 \
  --destination-port-range '443'

az network nsg rule create \
  --name ssh \
  --nsg-name $NSG_NME_OM \
  --resource-group $RSC_GRP_NME \
  --protocol Tcp \
  --priority 300 \
  --destination-port-range '22'

echo "Created Network Security Rules in $NSG_NME_OM for [http,https,ssh]"

az network vnet create \
  --location $RGN \
  --name $VNT_NME \
  --resource-group $RSC_GRP_NME \
  --address-prefixes $VNT_CIDR

Echo "Created Virtual Network: $VNT_NME"

az network vnet subnet create \
  --name $SN_INF_NME \
  --vnet-name $VNT_NME \
  --resource-group $RSC_GRP_NME \
  --address-prefix $SN_INF_CIDR \
  --network-security-group $NSG_NME_OM

az network vnet subnet create \
  --name $SN_PAS_NME \
  --vnet-name $VNT_NME \
  --resource-group $RSC_GRP_NME \
  --address-prefix $SN_PAS_CIDR \
  --network-security-group $NSG_NME_OM

az network vnet subnet create \
  --name $SN_SVC_NME \
  --vnet-name $VNT_NME \
  --resource-group $RSC_GRP_NME \
  --address-prefix $SN_SVC_CIDR \
  --network-security-group $NSG_NME_OM

echo "Created Subnets [$SN_INF_NME,$SN_PAS_NME,$SN_SVC_NME]"

az storage account create \
  --name $STR_NME \
  --resource-group $RSC_GRP_NME \
  --sku Standard_LRS \
  --location $RGN

echo "Created BOSH Storage Account: $STR_NME"

CNC_STR=$(az storage account show-connection-string --name $STR_NME --resource-group $RSC_GRP_NME | jq -r .connectionString)

echo "Recorded Connection String: $CNC_STR"

az storage container create \
  --name $BLB_OM \
  --connection-string $CNC_STR
  
az storage container create \
  --name $BLB_BSH \
  --connection-string $CNC_STR

az storage container create \
  --name $BLB_STM \
  --public-access blob \
  --connection-string $CNC_STR

echo "Created Blob containers $STR_NME:[$BLB_OM,$BLB_BSH,$BLB_STM]"

az storage table create \
  --name $TBL_STM \
  --connection-string $CNC_STR

echo "Created Table $TBL_STM"

az storage account create \
  --location $RGN \
  --name $DPL_STR_NME_1 \
  --resource-group $RSC_GRP_NME \
  --sku $STR_TYP \
  --kind Storage

az storage account create \
  --location $RGN \
  --name $DPL_STR_NME_2 \
  --resource-group $RSC_GRP_NME \
  --sku $STR_TYP \
  --kind Storage

az storage account create \
  --location $RGN \
  --name $DPL_STR_NME_3 \
  --resource-group $RSC_GRP_NME \
  --sku $STR_TYP \
  --kind Storage

az storage account create \
  --location $RGN \
  --name $DPL_STR_NME_4 \
  --resource-group $RSC_GRP_NME \
  --sku $STR_TYP \
  --kind Storage

az storage account create \
  --location $RGN \
  --name $DPL_STR_NME_5 \
  --resource-group $RSC_GRP_NME \
  --sku $STR_TYP \
  --kind Storage

echo "Created additional Storage Accounts: [DPL_STR_NME_1,DPL_STR_NME_2,DPL_STR_NME_3,DPL_STR_NME_4,DPL_STR_NME_5]"

CNC_STR_1=$(az storage account show-connection-string --name $DPL_STR_NME_1 --resource-group $RSC_GRP_NME | jq -r .connectionString)

echo "Recorded Connection String: $CNC_STR_1"

CNC_STR_2=$(az storage account show-connection-string --name $DPL_STR_NME_2 --resource-group $RSC_GRP_NME | jq -r .connectionString)

echo "Recorded Connection String: $CNC_STR_2"

CNC_STR_3=$(az storage account show-connection-string --name $DPL_STR_NME_3 --resource-group $RSC_GRP_NME | jq -r .connectionString)

echo "Recorded Connection String: $CNC_STR_3"

CNC_STR_4=$(az storage account show-connection-string --name $DPL_STR_NME_4 --resource-group $RSC_GRP_NME | jq -r .connectionString)

echo "Recorded Connection String: $CNC_STR_4"

CNC_STR_5=$(az storage account show-connection-string --name $DPL_STR_NME_5 --resource-group $RSC_GRP_NME | jq -r .connectionString)

echo "Recorded Connection String: $CNC_STR_5"

az storage container create \
  --name $BLB_BSH \
  --connection-string $CNC_STR_1

az storage container create \
  --name $BLB_STM \
  --public-access blob \
  --connection-string $CNC_STR_1

az storage container create \
  --name $BLB_BSH \
  --connection-string $CNC_STR_2

az storage container create \
  --name $BLB_STM \
  --public-access blob \
  --connection-string $CNC_STR_2

az storage container create \
  --name $BLB_BSH \
  --connection-string $CNC_STR_3

az storage container create \
  --name $BLB_STM \
  --public-access blob \
  --connection-string $CNC_STR_3

az storage container create \
  --name $BLB_BSH \
  --connection-string $CNC_STR_4

az storage container create \
  --name $BLB_STM \
  --public-access blob \
  --connection-string $CNC_STR_4

az storage container create \
  --name $BLB_BSH \
  --connection-string $CNC_STR_5

az storage container create \
  --name $BLB_STM \
  --public-access blob \
  --connection-string $CNC_STR_5

echo "Created Blob containers [$BLB_BSH,$BLB_STM]"
echo "  -storage accounts [$DPL_STR_NME_1,$DPL_STR_NME_2,$DPL_STR_NME_3,$DPL_STR_NME_4,$DPL_STR_NME_5]"

az network lb create \
  --location $RGN \
  --name $LB_PAS_NME \
  --resource-group $RSC_GRP_NME \
  --backend-pool-name $LB_PAS_PL_NME \
  --frontend-ip-name $LB_PAS_FE_IP \
  --public-ip-address $LB_PAS_PB_IP \
  --public-ip-address-allocation Static \
  --sku Standard

az network lb probe create \
  --lb-name $LB_PAS_NME \
  --name $LB_PAS_PRB_NME \
  --resource-group $RSC_GRP_NME \
  --protocol Http \
  --path /health \
  --port 8080

az network lb rule create \
  --lb-name $LB_PAS_NME \
  --name $LB_PAS_RLE_NME_HTTP \
  --resource-group $RSC_GRP_NME \
  --protocol Tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --backend-pool-name $LB_PAS_PL_NME \
  --frontend-ip-name $LB_PAS_FE_IP \
  --probe-name $LB_PAS_PRB_NME

az network lb rule create \
  --lb-name $LB_PAS_NME \
  --name $LB_PAS_RLE_NME_HTTPS \
  --resource-group $RSC_GRP_NME \
  --protocol Tcp \
  --frontend-port 443 \
  --backend-port 443 \
  --backend-pool-name $LB_PAS_PL_NME \
  --frontend-ip-name $LB_PAS_FE_IP \
  --probe-name $LB_PAS_PRB_NME

echo "Created and configured Load Balancer: $LB_PAS_NME"

az storage blob copy start \
  --source-uri $OM_URL \
  --connection-string $CNC_STR \
  --destination-container $BLB_OM \
  --destination-blob $OM_NME

echo "Creating Ops Manager VM..."

az network public-ip create \
  --name $OM_PUB_IP_NME \
  --resource-group $RSC_GRP_NME \
  --location $RGN \
  --allocation-method Static \
  > ./omip-output.json

OM_PUB_IP=$(cat omip-output.json | jq -r .publicIp.ipAddress)

az network nic create \
  --location $RGN \
  --vnet-name $VNT_NME \
  --subnet $SN_INF_NME \
  --network-security-group $NSG_NME_OM \
  --private-ip-address $OM_PRI_IP \
  --public-ip-address $OM_PUB_IP_NME \
  --resource-group $RSC_GRP_NME \
  --name $OM_NIC

echo "Created NIC for Ops Manager: $OM_PUB_IP"

ssh-keygen -t rsa -f $OM_KEY -C ubuntu

echo "Created ssh key for opsman: $OM_KEY"

STATUS=$(az storage blob show --name $OM_NME --container-name $BLB_OM --connection-string $CNC_STR | jq -r .properties.copy.status)

while [ "$STATUS" != "success" ]
do
  echo "  Ops Manager upload status: $STATUS"
  sleep 10s
  STATUS=$(az storage blob show --name $OM_NME --container-name $BLB_OM --connection-string $CNC_STR | jq -r .properties.copy.status)
done

echo "Completed Ops Manager upload: $STATUS"

az image create \
  --location $RGN \
  --resource-group $RSC_GRP_NME \
  --name $OM_IMG \
  --source https://$STR_NME.blob.core.windows.net/$BLB_OM/$OM_NME \
  --os-type Linux

echo "Created Ops Manager Image"

az vm create \
  --name $OM_VM \
  --resource-group $RSC_GRP_NME \
  --location $RGN \
  --nics $OM_NIC \
  --image $OM_IMG \
  --os-disk-size-gb $OM_DSK_SZE \
  --os-disk-name $OM_DSK_NME \
  --admin-username $OM_KEY \
  --size Standard_DS2_v2 \
  --storage-sku Standard_LRS \
  --ssh-key-value ./$OM_KEY.pub

echo "Created Ops Manager VM"

echo ""
echo "******************************************* INF. COMPLETED **********************************************"
echo "****************************** Azure Infrastructure for PCF has completed. ******************************"
echo -n "********************************* Continue configuration for PAS (Y/n)? *********************************"
read UINPUT

if [ -z "$UINPUT" ]; then
    ./test.sh
fi

echo ""
echo "********************************************** COMPLETED ************************************************"
echo "*********************************************************************************************************"
echo ""
echo ""

exit 0
