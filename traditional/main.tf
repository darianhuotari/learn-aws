# Prompt for domain name
variable "domain_name" {}


# Declare provider and region
provider "aws" {
  region = "us-east-2"
}

# Declare US-East-1; required for CloudFront certificate
provider "aws" {
  region = "us-east-1"
  alias  = "use1"
}

# Use default account VPC
resource "aws_default_vpc" "default" {}

# Use default subnets
data "aws_subnet_ids" "default" {
  vpc_id = "${aws_default_vpc.default.id}"
}

# Use all availability zones for region
data "aws_availability_zones" "all" {}

# Define base AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical Owner ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}

# Declare DNS zone to use
data "aws_route53_zone" "zone" {
  name = "${var.domain_name}."
}

# Create private key for terraform use. Will only exist in terraform state.
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create public key for terraform use
resource "aws_key_pair" "key" {
  key_name   = "FOTD-Key2"
  public_key = "${tls_private_key.key.public_key_openssh}"
}

# Allows EC2 instances to assume IAM roles
resource "aws_iam_role" "web-reg-iam-role" {
  assume_role_policy = "${file("iam/assumeRolePolicy.json")}"
}

# Creates Role Policy
resource "aws_iam_role_policy" "web-reg-role-policy" {
  role   = "${aws_iam_role.web-reg-iam-role.id}"
  policy = "${file("iam/web-regPolicy.json")}"
}

# Create security group and allow SSH from anywhere
resource "aws_security_group" "in_22tcp" {
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Create security group and allow HTTP from anywhere
resource "aws_security_group" "in_80tcp" {
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Create security group and allow TCP 5000 from anywhere
resource "aws_security_group" "in_5000tcp" {
  ingress {
    from_port        = 5000
    to_port          = 5000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Create security group and allow PostgreSQL 5432 from anywhere
resource "aws_security_group" "in_5432tcp" {
  ingress {
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Create security group and allow all outbound traffic
resource "aws_security_group" "out_all" {
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Create postgres RDS instance and assign security groups
resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "11.7"
  instance_class         = "db.t2.micro"
  name                   = "postgres"
  username               = "postgres"
  password               = "psqlPassword-01"
  skip_final_snapshot    = true
  vpc_security_group_ids = ["${aws_security_group.in_5432tcp.id}", "${aws_security_group.out_all.id}"]
}

# Create CNAME pointing to RDS instance DNS address
resource "aws_route53_record" "demodb1" {
  allow_overwrite = true
  zone_id         = "${data.aws_route53_zone.zone.zone_id}"
  name            = "demodb1.hoot-cloud.com"
  type            = "CNAME"
  ttl             = "300"
  records         = ["${aws_db_instance.postgres.address}"]
}

# Build base EC2 instance and perform base provisioning tasks
resource "aws_instance" "web-reg" {
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.key.key_name}"
  vpc_security_group_ids = ["${aws_security_group.in_22tcp.id}", "${aws_security_group.out_all.id}"]

  # Move files from src/ to /home/ubuntu folder on base EC2 instance
  provisioner "file" {
    source      = "src/"
    destination = "/home/ubuntu"

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${tls_private_key.key.private_key_pem}"
    }
  }

  # Perform shell commands to prepare and enable Flask application
  provisioner "remote-exec" {
    inline = [
      "/usr/bin/cloud-init status --wait",
      "sudo apt update",
      "sudo apt-get install libpq-dev -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq",
      "sudo apt install -y python3-pip --allow-unauthenticated",
      "LC_ALL=C pip3 install flask flask-migrate flask-script flask-sqlalchemy appdirs packaging psycopg2 boto3",
      "sudo mv /home/ubuntu/web-reg.service /etc/systemd/system/web-reg.service",
      "sudo systemctl enable web-reg.service",
    ]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${tls_private_key.key.private_key_pem}"
    }
  }
}

# Create custom AMI from base EC2 instance
resource "aws_ami_from_instance" "web-reg" {
  name               = "web-reg-ServerAMI"
  source_instance_id = "${aws_instance.web-reg.id}"
}

# Create instance profile and assign IAM role
resource "aws_iam_instance_profile" "web-reg" {
  role = "${aws_iam_role.web-reg-iam-role.name}"
}

# Create launch config for custom AMI
resource "aws_launch_configuration" "web-reg" {
  name                 = "Web-reg-LC"
  image_id             = "${aws_ami_from_instance.web-reg.id}"
  instance_type        = "t2.micro"
  security_groups      = ["${aws_security_group.in_5000tcp.id}", "${aws_security_group.out_all.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.web-reg.name}"
}

# Create autoscaling group using custom launch config
resource "aws_autoscaling_group" "web-reg" {
  min_size             = 2
  max_size             = 6
  launch_configuration = "${aws_launch_configuration.web-reg.name}"
  target_group_arns    = ["${aws_lb_target_group.web-reg.arn}"]
  availability_zones   = "${data.aws_availability_zones.all.names}"
}

# Create application load balancer and assign security groups
resource "aws_lb" "web-reg" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.in_80tcp.id}", "${aws_security_group.out_all.id}"]
  subnets            = "${data.aws_subnet_ids.default.ids}"
}

# Create target group for application load balancer and define health checks
resource "aws_lb_target_group" "web-reg" {
  port     = 5000
  protocol = "HTTP"
  vpc_id   = "${aws_default_vpc.default.id}"

  health_check {
    timeout  = 2
    interval = 5
    path     = "/get"
    matcher  = "200"
  }
}

# Create listener for load balancer, translates inbound HTTP 80 to HTTP 5000
resource "aws_lb_listener" "web-reg" {
  load_balancer_arn = "${aws_lb.web-reg.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.web-reg.arn}"
    type             = "forward"
  }
}

# Create Cloudfront instance and use domain name as alias (Needed for Route53)
resource "aws_cloudfront_distribution" "www" {
  aliases         = ["www.traditional.${var.domain_name}"]
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    target_origin_id       = "${aws_lb.web-reg.id}"
    viewer_protocol_policy = "redirect-to-https"
  }

  enabled = true

  # Use cheapest price class
  price_class = "PriceClass_100"

  # Set origin / source for CloudFront to cache data 
  origin {
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

    domain_name = "${aws_lb.web-reg.dns_name}"
    origin_id   = "${aws_lb.web-reg.id}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Use Terraform-created certificate
  viewer_certificate {
    acm_certificate_arn = "${aws_acm_certificate_validation.cert.certificate_arn}"
    ssl_support_method  = "sni-only"
  }
}

# Create wildcard ACM certificate in East US 1; required by CloudFront
resource "aws_acm_certificate" "cert" {
  provider          = aws.use1
  domain_name       = "*.traditional.${var.domain_name}"
  validation_method = "DNS"
}

# Automate ACM cert validation via DNS
resource "aws_route53_record" "cert_validation" {
  allow_overwrite = true
  name            = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type            = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id         = "${data.aws_route53_zone.zone.id}"
  records         = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl             = 60
}

# Validate wildcard ACM certificate in East US 1; required by CloudFront
resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.use1
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}

# Create alias for www.traditional.domainname to point to Cloudfront DNS address
resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.zone.zone_id}"
  name    = "www.traditional"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.www.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.www.hosted_zone_id}"
    evaluate_target_health = false
  }
}

# Create postgres RDS instance and assign security groups
resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "11.7"
  instance_class         = "db.t2.micro"
  name                   = "postgres"
  username               = "postgres"
  password               = "psqlPassword-01"
  skip_final_snapshot    = true
  vpc_security_group_ids = ["${aws_security_group.in_5432tcp.id}", "${aws_security_group.out_all.id}"]
}

# Create CNAME pointing to RDS instance DNS address
resource "aws_route53_record" "demodb1" {
  allow_overwrite = true
  zone_id         = "${data.aws_route53_zone.zone.zone_id}"
  name            = "demodb1.hoot-cloud.com"
  type            = "CNAME"
  ttl             = "300"
  records         = ["${aws_db_instance.postgres.address}"]
}

# Output the terraform private key to allow manual SSH access to EC2 instances
# This is useful when you need to troubleshoot flask problems directly on EC2
output "private_key_pem" {
  value = "${tls_private_key.key.private_key_pem}"
}
