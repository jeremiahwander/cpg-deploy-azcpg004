terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.9.0"
    }
    # Using azuread provider to create Apps/SPs requires Application 
    # Administrator role or Application.ReadWrite.All API perms
    azuread = {
      source  = "hashicorp/azuread"
      version = "=2.18.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "=2.11.0"
    }
  }
}

# Use Azure blob store to manage Terraform state - fill in 
# required fields via -backend-config on terraform init.
terraform {
  backend "azurerm" {}
}

provider "azuread" {
}

provider "azurerm" {
  features {}
}
