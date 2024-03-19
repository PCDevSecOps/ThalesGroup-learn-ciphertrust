terraform {

  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.10.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# This generates a random pet name that will be used to name your resource group.
resource "random_pet" "rg-name" {
  prefix = var.resource_group_name_prefix
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = random_pet.rg-name.id
  location = var.resource_group_location
  tags = {
    yor_trace = "7b8dd983-0000-4931-a5b3-ae442a24d192"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "ctm_network" {
  name                = "CTM_Vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    yor_trace = "35af55f8-c487-491f-ac60-7dae9bee7818"
  }
}

# Create subnet
resource "azurerm_subnet" "ctm_subnet" {
  name                 = "CTM_Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.ctm_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "ctm_public_ip" {
  name                = "CTM_PublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  tags = {
    yor_trace = "48e95fe5-9af4-42e4-acb6-55d2a42ce954"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "ctm_network_sg" {
  name                = "CTM_NetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "https"
    priority                   = 1011
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = {
    yor_trace = "6d50d478-ec1e-4bd9-afb5-405d08c7c0e8"
  }
}

# Create network interface
resource "azurerm_network_interface" "ctmnic" {
  name                = "ctmnic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ctm_nic_configuration"
    subnet_id                     = azurerm_subnet.ctm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ctm_public_ip.id
  }
  tags = {
    yor_trace = "47f41170-9c0a-4666-a846-b1840eae7a25"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "ctmnic_assoc_sg" {
  network_interface_id      = azurerm_network_interface.ctmnic.id
  network_security_group_id = azurerm_network_security_group.ctm_network_sg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "ctm_storage_account" {
  name                     = "diag${random_id.randomId.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = {
    yor_trace = "b0fcb9bd-443e-4ad0-ad8a-be6be2399597"
  }
}

# Create (and display) an SSH key
resource "tls_private_key" "ctm_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create virtual machine for CipherTrust Manager (CTM).
resource "azurerm_linux_virtual_machine" "ctm_vm" {
  name                  = "CipherTrustManager_VM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.ctmnic.id]
  size                  = "Standard_D2s_v3"

  os_disk {
    name                 = "CTM_OS_Disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "thalesdiscplusainc1596561677238"
    offer     = "cm_k170v"
    sku       = "ciphertrust_manager"
    version   = "latest"
  }

  plan {
    name      = "ciphertrust_manager"
    product   = "cm_k170v"
    publisher = "thalesdiscplusainc1596561677238"
  }

  computer_name                   = "serverVM"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ctm_ssh_key.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.ctm_storage_account.primary_blob_endpoint
  }
  tags = {
    yor_trace = "9afbfe97-bb89-4e39-b280-c13707da34c7"
  }
}


