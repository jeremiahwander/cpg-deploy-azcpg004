# Deployment instructions for CPG infrastructure on Azure

The following instructions are intended for the deplpoyment of Sample Metadata Server, Analysis Runner, and associated datsets (TODO links).

## Pre-requisites

Optionally, you may want to perform the following deployment steps from within a VM in Azure in the same region. [These instructions](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/quick-create-portal) can help you do that.

### Pre-existing Hail Batch on Azure deployment

Following the instructions [here](https://github.com/hail-is/hail/tree/main/infra/azure), deploy Hail Batch in your Azure subscription.

Collect the following information about your Hail Batch deployment

- the domain associated with your Hail Batch deployment (e.g., azhailtest0.net)
- the [resource group](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#what-is-a-resource-group) in which your Hail Batch instance is deployed
- the hail-internal cluster name for your instance (typically `vdc`)
- the Azure region in which your Hail Batch instance is deployed

### Update and install base utilities

```bash
sudo apt-get update
sudo apt-get install jq
```

### Install Azure CLI

Install the Azure CLI following the instructions [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt). For our test VM, running Ubuntu 20.04, this is done as follows:

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Verify the installation was successful

```bash
az --version
```

The output of this command should begin with something like

```text
azure-cli                         2.37.0

core                              2.37.0
telemetry                          1.0.6

Dependencies:
msal                            1.18.0b1
azure-mgmt-resource             21.1.0b1
```

### Install Terraform

Install the Terraform utility following the instructions [here](https://www.terraform.io/downloads).

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get install terraform
```

Verify installation was successful

```bash
terraform -v
```

The output of this command should look something like

```text
Terraform v1.2.3
on linux_amd64
```

### Assign RBAC roles

In order to deploy the CPG infrastructure you will need both tenant-level roles and subscription-level roles granted for your identity. Though the following roles are a little broader than is strictly necessary, make sure you have the `Global Administrator` AAD role and the `Owner` role for the subscription in which you intend to deploy resources.

See the following links for how to [AAD roles](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-users-assign-role-azure-portal) and [subscription roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal-subscription-admin) using Azure Portal.

## Infrastructure deployment

### Clone cpg-deploy repository

Clone the repository that contains the terraform configuration to deploy the CPG infrastructure.

```bash
cd ~
mkdir repos && cd repos
git clone https://github.com/gregsmi/cpg-deploy
cd cpg-deploy/azure
```

Note: subsequent steps assume your current working directory is the `azure` subdirectory in the cpg-deploy repo.

### Get deployment details

Obtain tenant and subscription GUIDs.

```bash
az login --use-device-code
az account show -s <deployment subscription>
```

The value associated with `homeTenantID` is your tenant GUID.
The value associated with `id` is your subscription GUID.

Note: some users can use `az login` to access multiple tenants, in this case use `az login --use-device-code -t <your tenant>` to login. In this case you should also verify the UPN of your identity either through Azure portal or by searching for your guest identity in `az ad user list`.

### Populate configuration files

Infrastructure deployment is configured with a few text files contained within this repository.

First, populate `deployment.env`

1. `cp example.env deployment.env`
1. replace the template values in `deployment.env` with appropriate values for your deployment
   1. `AAD_TENANT` - the tenant GUID identified above.
   1. `AZURE_SUBSCRIPTION` - the subscription GUID identified above.
   1. `DEPLOYMENT_NAME` - a string identifier for your deployment. This will serve as a root for the naming of multiple Azure resources. It should be unique across Azure and contain between 8 and 16 lowercase alphabetical or numeric characters.
   1. `AZURE_REGION` - the Azure region in which to deploy resources (e.g., "australiaeast" or "eastus"). Run `az account list-locations -otable` for full list of Azure regions. This should be the same region in which your Hail Batch cluster is already deployed.

Next, populate `config/config.json`. This is a json object that contains configuration information about administrators and datasets for your deployment.

1. `administrators` is a list of strings that designate deployment administrators (TODO: detail on permissions). Administrators should be designated by listing the User Principal Name (UPN) associated with the user's identity in Azure Active Directory.
   - To obtain the UPN for the user currently logged in via `az login` execute `az ad signed-in-user show --query "userPrincipalName"`
   - To obtain a list of UPNs for all users in the tenant execute `az ad user list --query "[].userPrincipalName"` (This can produce many results if your tenant is large).
1. The `hail` JSON object contains configuration for the previously deployed Hail Batch cluster listed as a prerequisite. `domain`, `resource_group`, and `cluster_name` should be the same details you previously collected about your Hail Batch deployment.

Lastly, in the `config` subdirectory you will create one or more dataset-specific JSON files following the format outlined in `dataset.json.example`. Note that dataset infrastructure can easily be added later via subsequent calls of `terraform apply`.

1. `name` should be a lowercase, alphabetic string between 8 and 16 characters. It is not required to be unique across Azure, but should be unique within your infrastructure deployment.
1. `project_id` should be a lowercase alphabetic / numeric string between 8 and 16 characters. It should be unique across Azure and will be used as a root for deployed resources specific to this dataset.
1. `region` should match the region specified in `deployment.env`
1. `access_accounts` will be a list of UPNs for users who should be granted different access levels. AAD group names are also allowed, but will be expanded to their membership list at the time of deployment and will not update with subsequent additions to the group.
1. `allowed_repos` is a list of github repositories from which code can be run against the data in this dataset.

### Terraform deployment

1. Initialize Terraform using the `terraform_init.sh` shell script. This script performs a number of operations
   - Ensures that you are logged into the correct Azure tenant (and attempts to log you in if not)
   - Creates a resource group, storage account, and container within that account to hold terraform state
   - Initializes Terraform using the newly created storage account and container to contain backend state
   - Creates a file `terraform.tfvars` that contains deployment-specific variables

   ```bash
   chmod u+x terraform_init.sh
   ./terraform_init.sh -c
   ```

2. Apply the terraform configuration

   ```bash
   terraform apply
   ```

   enter 'yes' when prompted to proceed with deployment.

