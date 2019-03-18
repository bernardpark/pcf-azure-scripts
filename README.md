# Setting up PCF Reference Architecture on Azure using CLI

This repository contains a rudimentary shell script to implement PCF on GCP Reference Architecture, as well as tearing it down. It is not meant for production use, but rather a learning experience.

## Getting Started

Clone this repository to an environment of your choice.

```bash
git clone https://github.com/bernardpark/pcf-azure-scripts.git
```

## Prerequisites

### Authenticate Azure Account

Prepare your environment by authorizing your GCP Account

```bash
az cloud set CLOUD-NAME
az login
```

For CLOUD-NAME...
+ Azure: AzureCloud
+ Azure China: AzureChinaCloud. If logging in to AzureChinaCloud fails with a CERT_UNTRUSTED, use the latest version of node, 4.x or later. For more information about this error, see Failed to login AzureChinaCloud in the Azure/azure-xplat-cli GitHub repository.
+ Azure Government Cloud: AzureUSGovernment.
+ Azure Germany: AzureGermanCloud.

### TODO

TODO

## Resources

* [Installing PCF on Azure](https://docs.pivotal.io/pivotalcf/2-4/customizing/pcf_azure.html) - Pivotal's official guide


## Authors

* **Bernard Park** - [Github](https://github.com/bernardpark)

