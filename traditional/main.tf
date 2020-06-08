# variable "domain_name" {}


# Declare provider and region
provider "aws" {
  region = "us-east-2"
}

resource "aws_default_vpc" "default" {}

data "aws_subnet_ids" "default" {
  vpc_id = "${aws_default_vpc.default.id}"
}

data "aws_availability_zones" "all" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}

#data "aws_route53_zone" "zone" {
#  name = "${var.domain_name}."
#}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key" {
  key_name   = "learn-aws-traditional"
  public_key = "${tls_private_key.key.public_key_openssh}"
}

resource "aws_iam_role" "web-reg-iam-role" {
  assume_role_policy = "${file("iam/assumeRolePolicy.json")}"
}

resource "aws_iam_role_policy" "web-reg-role-policy" {
  role   = "${aws_iam_role.web-reg-iam-role.id}"
  policy = "${file("iam/web-regPolicy.json")}"
}

resource "aws_security_group" "in_22tcp" {
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "in_80tcp" {
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "in_5000tcp" {
  ingress {
    from_port        = 5000
    to_port          = 5000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "out_all" {
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "web-reg" {
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.key.key_name}"
  vpc_security_group_ids = ["${aws_security_group.in_22tcp.id}", "${aws_security_group.out_all.id}"]

  provisioner "file" {
    source      = "src/"
    destination = "/home/ubuntu"

    connection {
      host = self.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${tls_private_key.key.private_key_pem}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt-get install libpq-dev -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq",
      "sudo apt install -y python3-pip",
      "LC_ALL=C pip3 install flask flask-migrate flask-script flask-sqlalchemy appdirs packaging psycopg2 boto3",
      "sudo mv /home/ubuntu/web-reg.service /etc/systemd/system/web-reg.service",
      "sudo systemctl enable web-reg.service",
    ]

    connection {
      host = self.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${tls_private_key.key.private_key_pem}"
    }
  }
}

resource "aws_ami_from_instance" "web-reg" {
  name               = "web-reg-ServerAMI"
  source_instance_id = "${aws_instance.web-reg.id}"
}

resource "aws_iam_instance_profile" "web-reg" {
  role = "${aws_iam_role.web-reg-iam-role.name}"
}

resource "aws_launch_configuration" "web-reg" {
  name                 = "FortuneServerLaunchConfiguration"
  image_id             = "${aws_ami_from_instance.web-reg.id}"
  instance_type        = "t2.micro"
  security_groups      = ["${aws_security_group.in_5000tcp.id}", "${aws_security_group.out_all.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.web-reg.name}"
}

resource "aws_autoscaling_group" "web-reg" {
  min_size             = 2
  max_size             = 6
  launch_configuration = "${aws_launch_configuration.web-reg.name}"
  target_group_arns    = ["${aws_lb_target_group.web-reg.arn}"]
  availability_zones   = "${data.aws_availability_zones.all.names}"
}

resource "aws_lb" "web-reg" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.in_80tcp.id}", "${aws_security_group.out_all.id}"]
  subnets            = "${data.aws_subnet_ids.default.ids}"
}

resource "aws_lb_target_group" "web-reg" {
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${aws_default_vpc.default.id}"

  health_check {
    timeout  = 2
    interval = 5
    path     = "/get"
    matcher  = "200"
  }
}

resource "aws_lb_listener" "web-reg" {
  load_balancer_arn = "${aws_lb.web-reg.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.web-reg.arn}"
    type             = "forward"
  }
}

resource "aws_db_instance" "postgres" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "11.7"
  instance_class       = "db.t2.micro"
  name                 = "web-app-db-postgres"
  username             = "postgres"
  password             = "psqlPassword-01"
}
