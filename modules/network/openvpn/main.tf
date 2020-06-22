locals {
  certs = concat(["server"], var.clients)
}

# CA  
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm         = "RSA"
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 8760
  allowed_uses = [
    "cert_signing"
  ]

  subject {
    common_name = "vpn.${var.domain}"
  }
}

# Clients
resource "tls_private_key" "cert" {
  for_each  = toset(local.certs)
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "cert" {
  for_each        = toset(local.certs)
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.cert[each.key].private_key_pem

  subject {
    common_name = "vpn.${var.domain}"
  }
}

resource "tls_locally_signed_cert" "cert" {
  for_each           = toset(local.certs)
  cert_request_pem   = tls_cert_request.cert[each.key].cert_request_pem
  set_subject_key_id = true
  ca_key_algorithm   = "RSA"
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760
  allowed_uses = [
    each.key == "server" ? "server_auth" : "client_auth"
  ]
}

resource "aws_acm_certificate" "this" {
  private_key       = tls_private_key.cert["server"].private_key_pem
  certificate_body  = tls_locally_signed_cert.cert["server"].cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem
}

resource "aws_cloudwatch_log_group" "openvpn" {
  name = "/openvpn/${var.cluster_name}"
}

resource "aws_cloudwatch_log_stream" "openvpn" {
  name           = "connection_logs"
  log_group_name = aws_cloudwatch_log_group.openvpn.name
}

resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = "${var.cluster_name}-clientvpn"
  server_certificate_arn = aws_acm_certificate.this.arn
  client_cidr_block      = "10.100.0.0/16"
  split_tunnel           = true
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.this.arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.openvpn.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.openvpn.name
  }
}

resource "aws_ec2_client_vpn_network_association" "this" {
  for_each               = toset(var.subnet_ids)
  client_vpn_endpoint_id = "${aws_ec2_client_vpn_endpoint.this.id}"
  subnet_id              = each.key
}

resource "local_file" "config" {
  for_each = toset(var.clients)
  content  = <<EOT
client
dev tun
proto ${aws_ec2_client_vpn_endpoint.this.transport_protocol}
remote ${replace(aws_ec2_client_vpn_endpoint.this.dns_name, "*", each.key)} 443
remote-random-hostname
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
verb 3
<ca>
${tls_self_signed_cert.ca.cert_pem}
</ca>
<cert>
${tls_locally_signed_cert.cert[each.key].cert_pem}
</cert>
<key>
${tls_private_key.cert[each.key].private_key_pem}
</key>
reneg-sec 0
EOT
  filename = "${each.key}.ovpn"
}