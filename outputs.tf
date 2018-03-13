output "ip_addresses" {
  value = "${aws_instance.hosts.*.public_ip}"
}
