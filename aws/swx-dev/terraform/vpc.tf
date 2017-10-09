/******************************************************************************
 *
 * vpc.tf - IAM profile, security groups, and instances
 *
 ******************************************************************************/

provider "aws" {
  region = "${var.aws_region}"
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
}

resource "aws_vpc" "vpc" {

    cidr_block = "${var.vpc_network_cidr}"
    enable_dns_support = "true"
    enable_dns_hostnames = "true"
    assign_generated_ipv6_cidr_block = true

    tags {
        Name = "vpc-${var.Project}-${var.Lifecycle}"
        Project = "${var.Project}"
        Lifecycle = "${var.Lifecycle}"
    }
}

resource "aws_subnet" "instances" {
  count = "${var.vpc_subnet_count}"
  
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${cidrsubnet(var.vpc_network_cidr, var.vpc_subnet_network_bits, (count.index+1) * 2)}"
  availability_zone = "${element(split(",",lookup(var.aws_availability_zones, var.aws_region)), count.index % length(split(",",lookup(var.aws_availability_zones, var.aws_region))))}"

  map_public_ip_on_launch = true
  ipv6_cidr_block = "${cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, (count.index+1) * 2)}" /* Even numbered /64 networks are for instances eth0 */
  assign_ipv6_address_on_creation = true

  tags {
    Name = "subnet${count.index}-${var.Project}-${var.Lifecycle}-instances"
    Project = "${var.Project}"
    Lifecycle = "${var.Lifecycle}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "igw-${var.Project}-${var.Lifecycle}"
    Project = "${var.Project}"
    Lifecycle = "${var.Lifecycle}"
  }
}

resource "aws_route_table" "default" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags {
    Name = "route-${var.Project}-${var.Lifecycle}-default"
    Project = "${var.Project}"
    Lifecycle = "${var.Lifecycle}"
  }
}

resource "aws_route_table_association" "default" {
  count = "${var.vpc_subnet_count}"
  
  subnet_id = "${element(aws_subnet.instances.*.id, count.index)}"
  route_table_id = "${aws_route_table.default.id}"
}

resource "aws_security_group" "sg" {
  name = "${var.Project}-${var.Lifecycle}"
  description = "Security Group for ${var.Project}-${var.Lifecycle}"
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
      Name = "sg-${var.Project}-${var.Lifecycle}"
      Project = "${var.Project}"
      Lifecycle = "${var.Lifecycle}"
  }
}

resource "aws_security_group_rule" "sg_ingress_ssh" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = "${aws_security_group.sg.id}"
}

resource "aws_security_group_rule" "sg_ingress_http" {
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = "${aws_security_group.sg.id}"
}

resource "aws_security_group_rule" "sg_ingress_https" {
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = "${aws_security_group.sg.id}"
}

resource "aws_security_group_rule" "sg_ingress_dokkusetup" {
    type = "ingress"
    from_port = 2000
    to_port = 2000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = "${aws_security_group.sg.id}"
}

resource "aws_security_group_rule" "sg_ingress_docker" {
    type = "ingress"
    from_port = 2376
    to_port = 2376
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = "${aws_security_group.sg.id}"

}
resource "aws_security_group_rule" "sg_ingress_orient" {
    type = "ingress"
    from_port = 9999
    to_port = 9999
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = "${aws_security_group.sg.id}"
}


resource "aws_security_group_rule" "sg_ingress_all_icmp" {
    type = "ingress"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]

    security_group_id = "${aws_security_group.sg.id}"
}

resource "aws_security_group_rule" "sg_ingress_all_icmpv6" {
    type = "ingress"
    from_port = -1
    to_port = -1
    protocol = "icmpv6"
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = "${aws_security_group.sg.id}"
}

resource "aws_security_group_rule" "sg_ingress_nifi" {
    type = "ingress"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = "${aws_security_group.sg.id}"
}

resource "aws_security_group_rule" "sg_ingress_all_internal" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    security_group_id = "${aws_security_group.sg.id}"
    source_security_group_id = "${aws_security_group.sg.id}"
}

resource "aws_security_group_rule" "sg_egress_all_out" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_group_id = "${aws_security_group.sg.id}"
}

resource "aws_iam_role" "iam_role" {
    name = "${var.Project}-${var.Lifecycle}-instance_role"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "iam_policy" {
    name = "${var.Project}-${var.Lifecycle}-instance_policy"
    path = "/"
    description = "Platform IAM Policy"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
     {
       "Effect": "Allow",
       "Action": [
         "iam:ListInstanceProfiles"
       ],
       "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "iam_policy_attachment" {
    name = "${var.Project}-${var.Lifecycle}-policy_attach"
    roles = ["${aws_iam_role.iam_role.name}"]
    policy_arn = "${aws_iam_policy.iam_policy.arn}"
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
    name = "${var.Project}-${var.Lifecycle}-instance_profile"
    role = "${aws_iam_role.iam_role.name}"
}

resource "aws_key_pair" "ssh_key" {
  key_name = "${var.Project}-${var.Lifecycle}" 
  public_key = "${file("${var.ssh_key_path}.pub")}"
}

resource "aws_ebs_volume" "home" {
  count = "${var.aws_instance_count}"

  availability_zone = "${element(split(",",lookup(var.aws_availability_zones, var.aws_region)), count.index % length(split(",",lookup(var.aws_availability_zones, var.aws_region))))}"

  size = "${var.ebs_home_volume_size}"
  type = "gp2"

  encrypted = true

  tags {
    Name = "${var.Project}-${var.Lifecycle}-${count.index}"
  }
}

resource "aws_ebs_volume" "docker" {
  count = "${var.aws_instance_count}"

  availability_zone = "${element(split(",",lookup(var.aws_availability_zones, var.aws_region)), count.index % length(split(",",lookup(var.aws_availability_zones, var.aws_region))))}"

  size = "${var.ebs_docker_volume_size}"
  type = "gp2"

  encrypted = true

  tags {
    Name = "${var.Project}-${var.Lifecycle}-${count.index}"
  }
}

resource "aws_instance" "instance" {
  count = "${var.aws_instance_count}"
    
  availability_zone = "${element(split(",",lookup(var.aws_availability_zones, var.aws_region)), count.index % length(split(",",lookup(var.aws_availability_zones, var.aws_region))))}"
  
  instance_type = "${var.aws_instance_type}"
  ami = "${lookup(var.ami, "${var.aws_region}-${var.linux_distro_name}-${var.linux_distro_version}")}"
  
  iam_instance_profile = "${aws_iam_instance_profile.iam_instance_profile.id}"
  vpc_security_group_ids = [ "${aws_security_group.sg.id}" ]
  subnet_id = "${element(aws_subnet.instances.*.id, count.index)}"
  associate_public_ip_address = "true"
  ipv6_address_count = 1
  
  key_name = "${aws_key_pair.ssh_key.key_name}"

  connection {
    user = "ubuntu"
    key_file = "${var.ssh_key_path}"
  }

  tags {
    Name = "${var.Project}-${var.Lifecycle}-${count.index}"
    Project = "${var.Project}"
    Lifecycle = "${var.Lifecycle}"
  }
    
  root_block_device {
    volume_type = "gp2"
    delete_on_termination = true
    volume_size = "${var.ebs_root_volume_size}"
  }

  volume_tags {
    Name = "${var.Project}-${var.Lifecycle}-${count.index}"
  }
  user_data = "${file("../user-env.sh")}"
}

resource "aws_volume_attachment" "instance-home" {
  count = "${var.aws_instance_count}"
  device_name = "xvdh"
  instance_id = "${element(aws_instance.instance.*.id, count.index)}"
  volume_id = "${element(aws_ebs_volume.home.*.id, count.index)}"
  force_detach = true
}

resource "aws_volume_attachment" "instance-docker" {
  count = "${var.aws_instance_count}"
  device_name = "xvdi"
  instance_id = "${element(aws_instance.instance.*.id, count.index)}"
  volume_id = "${element(aws_ebs_volume.docker.*.id, count.index)}"
  force_detach = true
}

/*
 data "aws_acm_certificate" "orient" {
  domain   = "orient.${var.dns_zone}"
  statuses = ["ISSUED"]
}
*/

/*
# Create the private key for the registration (not the certificate)
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

# Set up a registration using a private key from tls_private_key
resource "acme_registration" "reg" {
  server_url      = "https://acme-staging.api.letsencrypt.org/directory"
  # server_url      = "https://acme-v01.api.letsencrypt.org/directory"
  account_key_pem = "${tls_private_key.private_key.private_key_pem}"
  email_address   = "ian@devwerx.org"
}

# Create a certificate
resource "acme_certificate" "certificate" {
  server_url                = "https://acme-staging.api.letsencrypt.org/directory"
  # server_url               = "https://acme-v01.api.letsencrypt.org/directory"
  account_key_pem           = "${tls_private_key.private_key.private_key_pem}"
  common_name               = "${var.Project}-${var.Lifecycle}.${var.dns_zone}"
  subject_alternative_names = [
    "orient.${var.Project}-${var.Lifecycle}.${var.dns_zone}",
    "nifi.${var.Project}-${var.Lifecycle}.${var.dns_zone}"
  ]
  # Require OCSP stapling in the TLS cert
  must_staple = true

  dns_challenge {
    provider = "route53"
  }

  registration_url = "${acme_registration.reg.id}"
}
*/

/*
resource "aws_iam_server_certificate" "service_cert" {
  name = "${var.Project}-${var.Environment}-services-wildcard-cert"
  certificate_chain = "${file("secrets/vatrp.net/wildcard_ssl.ca.pem")}"
  certificate_body = "${file("secrets/vatrp.net/wildcard_ssl.pem")}"
  private_key = "${file("secrets/vatrp.net/wildcard_ssl.key.pem")}"
}

resource "aws_security_group" "_sg_pub_to_elb" {
  name = "${var.Project}-${var.Environment}-pub_to_elb"
  description = "Security Group for ingress traffic from external networks to ELB"
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
      Name = "sg-${var.Project}-${var.Environment}-elb"
      Project = "${var.Project}"
      Environment = "${var.Environment}"
  }
}

resource "aws_security_group_rule" "elb_https_in" {
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

    security_group_id = "${aws_security_group._sg_pub_to_elb.id}"
}

resource "aws_security_group_rule" "elb_internal_docker_in" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    security_group_id = "${aws_security_group._sg_pub_to_elb.id}"
    source_security_group_id = "${aws_security_group.sg_docker.id}"
}

resource "aws_security_group_rule" "elb_service_all_out" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]

    security_group_id = "${aws_security_group._sg_pub_to_elb.id}"
}

resource "aws_elb" "config_service" {
  name = "${var.Project}-${var.Environment}-elb-rue"
  depends_on = ["aws_iam_server_certificate.service_cert"]
  cross_zone_load_balancing = true

  listener {
    instance_port = 8000
    instance_protocol = "http"
    lb_port = 443
    lb_protocol = "https"
    ssl_certificate_id = "${aws_iam_server_certificate.service_cert.arn}"
  }

  security_groups = ["${aws_security_group._sg_pub_to_elb.id}"]

  instances = ["${aws_instance.docker_server.0.id}"]
  subnets = ["${aws_subnet.subnet.0.id}"]
  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 30

  tags {
      Name = "sg-${var.Project}-${var.Environment}-elb-rue"
      Project = "${var.Project}"
      Environment = "${var.Environment}"
  }
}

output "elb_config_service_dns_name" {
  value = "${aws_elb.config_service.dns_name}"
}
*/


data "aws_route53_zone" "selected" {
  name         = "${var.dns_zone}"
  private_zone = false
}

/* Define a project-environment-instance.zone A record */
resource "aws_route53_record" "instance" {
  count = "${var.aws_instance_count}"
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "${var.Project}-${var.Lifecycle}-${count.index}.${var.dns_zone}"
  type    = "A"
  ttl     = "300"
  records = ["${element(aws_instance.instance.*.public_ip, count.index)}"]
}

/* Define a project-environment.zone round-robin of A records */
resource "aws_route53_record" "project-name" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "${var.Project}-${var.Lifecycle}.${var.dns_zone}"
  type    = "A"
  ttl     = "300"
  records = ["${join(",", aws_instance.instance.*.public_ip)}"]
}

/* Define a project-environment.zone wildcard of round-robin A records */
resource "aws_route53_record" "wildcard-project-name" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "*.${var.Project}-${var.Lifecycle}.${var.dns_zone}"
  type    = "A"
  ttl     = "300"
  records = ["${join(",", aws_instance.instance.*.public_ip)}"]
}

output "hostname_list" {
  value = "${join(",", aws_instance.instance.*.tags.Name)}"
}

output "ec2_ids" {
  value = "${join(",", aws_instance.instance.*.id)}"
}

output "ec2_ipv4" {
  value = "${join(",", aws_instance.instance.*.public_ip)}"
}

output "ec2_ipv6" {
  value = "${join(",", aws_instance.instance.*.ipv6_addresses)}"
}

output "fqdns" {
  value = "${join(",", aws_route53_record.instance.*.fqdn)}"
}

