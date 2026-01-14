output "active_instance_id" {
  value = aws_instance.wg[0].id
}

output "standby_instance_id" {
  value = aws_instance.wg[1].id
}

output "active_eni_id" {
  value = aws_instance.wg[0].primary_network_interface_id
}

output "standby_eni_id" {
  value = aws_instance.wg[1].primary_network_interface_id
}

output "eip_public_ip" {
  value = aws_eip.wg.public_ip
}

output "eip_allocation_id" {
  value = aws_eip.wg.allocation_id
}

output "wireguard_port" { 
  value = var.wireguard_port 
}