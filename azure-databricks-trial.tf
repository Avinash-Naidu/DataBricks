terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# No `provider "azurerm"` block: the engine injects provider.tf.json.
# No `variable` blocks: they would duplicate against variables.tf.json.
#
# UPGRADE TEST PROCEDURE
#   1. Upload and run as-is            -> creates a trial workspace
#   2. Change local.sku to "premium"
#   3. Re-run as a CHILD of job 1      -> create_statefile_from_parentjob
#                                         seeds terraform.tfstate, so the plan
#                                         shows an update, not a create
#   Expect `~ sku` in the plan. If it shows `-/+`, azurerm is treating the
#   change as ForceNew and the workspace would be destroyed - stop there.

locals {
  # <<< THE ONE LINE TO CHANGE FOR THE UPGRADE TEST >>>
  sku = "trial" # trial -> premium (upgrade, in place)
  # Do NOT set this to "standard" from "premium": a downgrade is ForceNew
  # and destroys the workspace along with its notebooks and job definitions.

  location = "East US"
  prefix   = "terratest-dbx"

  tags = {
    environment = "QA"
    managed_by  = "terraform"
    purpose     = "engine-upgrade-test"
  }
}

# The auto-created managed resource group name must be unique in the subscription.
resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.prefix}-rg"
  location = local.location
  tags     = local.tags
}

resource "azurerm_databricks_workspace" "test" {
  name                = "${local.prefix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = local.sku

  # Azure creates and fully controls this RG - the compute VMs, disks and
  # storage land here, not in the RG above. It cannot be modified by hand.
  managed_resource_group_name = "${local.prefix}-managed-${random_string.suffix.result}"

  tags = local.tags
}

output "workspace_Name" {
  value = azurerm_databricks_workspace.test.name
}

output "workspace_Id" {
  value = azurerm_databricks_workspace.test.id
}

output "workspace_Url" {
  value = azurerm_databricks_workspace.test.workspace_url
}

output "current_Sku" {
  value = azurerm_databricks_workspace.test.sku
}

output "resource_Group" {
  value = azurerm_resource_group.rg.name
}

output "managed_Resource_Group_Id" {
  value = azurerm_databricks_workspace.test.managed_resource_group_id
}
