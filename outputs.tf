output "ip_addresses" {
  value = "${aws_instance.hosts.*.private_ip}"
}
