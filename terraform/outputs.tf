output "public_ip" {
  description = "Public IP address of the VM"
  value       = oci_core_instance.app.public_ip
}

output "ssh_command" {
  description = "SSH into the VM"
  value       = "ssh ubuntu@${oci_core_instance.app.public_ip}"
}

output "deploy_command" {
  description = "Deploy latest code to the VM"
  value       = "./scripts/deploy.sh ubuntu@${oci_core_instance.app.public_ip}"
}

output "cloud_init_log" {
  description = "View cloud-init bootstrap log"
  value       = "ssh ubuntu@${oci_core_instance.app.public_ip} 'sudo cat /var/log/cloud-init-output.log'"
}

output "app_url" {
  description = "Application URL"
  value       = var.domain != "" ? "https://${var.domain}" : "http://${oci_core_instance.app.public_ip}"
}
