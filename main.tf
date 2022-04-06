terraform{
	required_providers{
		azurerm = {
			source = "hashicorp/azurerm"
			version = "~> 2.65"
		}
	}
	required_version = ">= 1.1"
}

provider "azurerm"{
	features{}
}

variable "prefix"{
	default = "Atividade1"
}

variable "usuario"{
	default = "Nicollas"
}

variable "senha"{
	default = "Senhatop123"
}

resource "azurerm_resource_group" "principal"{
	name = "${var.prefix}-recursos"
	location = "West US 2"
}

resource "azurerm_virtual_network" "principal"{
	name = "${var.prefix}-rede"
	address_space = ["10.0.0.0/16"]
	location = azurerm_resource_group.principal.location
	resource_group_name = azurerm_resource_group.principal.name
}

resource "azurerm_subnet" "interno"{
	name = "interno"
	resource_group_name = azurerm_resource_group.principal.name
	virtual_network_name = azurerm_virtual_network.principal.name
	address_prefixes = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "principal"{
	name = "${var.prefix}-ipPublico"
	location = azurerm_resource_group.principal.location
	resource_group_name = azurerm_resource_group.principal.name
	allocation_method = "Static"
}

resource "azurerm_network_interface" "principal"{
	name = "${var.prefix}-nic"
	location = azurerm_resource_group.principal.location
	resource_group_name = azurerm_resource_group.principal.name

	ip_configuration{
		name = "configuracaoPrincipal"
		subnet_id = azurerm_subnet.interno.id
		private_ip_address_allocation = "Dynamic"
		public_ip_address_id = azurerm_public_ip.principal.id
	}
}

resource "azurerm_network_security_group" "principal"{
	name = "${var.prefix}-nsg"
	location = azurerm_resource_group.principal.location
	resource_group_name = azurerm_resource_group.principal.name

	security_rule{
		name = "ssh"
		priority = 100
		direction = "Inbound"
		access = "Allow"
		protocol = "TCP"
		source_port_range = "*"
		destination_port_range = "22"
		source_address_prefix = "*"
		destination_address_prefix = "*"
	}
	security_rule{
		name = "apache"
		priority = 101
		direction = "Inbound"
		access = "Allow"
		protocol = "TCP"
		source_port_range = "*"
		destination_port_range = "80"
		source_address_prefix = "*"
		destination_address_prefix = "*"
	}
}

resource "azurerm_network_interface_security_group_association" "associacao"{
	network_interface_id = azurerm_network_interface.principal.id
	network_security_group_id = azurerm_network_security_group.principal.id
}

resource "azurerm_virtual_machine" "principal"{
	name = "${var.prefix}-vm"
	location = azurerm_resource_group.principal.location
	resource_group_name = azurerm_resource_group.principal.name
	network_interface_ids = [azurerm_network_interface.principal.id]
	vm_size = "Standard_D2s_v3"

	delete_os_disk_on_termination = true
	delete_data_disks_on_termination = true

	storage_image_reference{
		publisher = "Canonical"
		offer = "UbuntuServer"
		sku = "16.04-LTS"
		version = "latest"
	}

	storage_os_disk{
		name = "disco"
		caching = "ReadWrite"
		create_option = "FromImage"
		managed_disk_type = "Standard_LRS"
	}

	os_profile{
		computer_name = "${var.prefix}-vm"
		admin_username = "${var.usuario}"
		admin_password = "${var.senha}"
	}

	os_profile_linux_config{
		disable_password_authentication = false
	}
}

resource "null_resource" "subirApache"{
	provisioner "remote-exec"{
		connection{
			type = "ssh"
			user = "${var.usuario}"
			password = "${var.senha}"
			host = azurerm_public_ip.principal.ip_address
		}
		inline = [
			"sudo apt update -y",
			"sudo apt install -y apache2"
		]
	}
}

output "public_ip_address"{
	value = azurerm_public_ip.principal.ip_address
}