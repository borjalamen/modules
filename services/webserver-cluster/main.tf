locals {

  http_port    = 80
  tcp_protocol = "tcp"
  all_ips      = "0.0.0.0/0"
  any_port     = 0
  any_protocol = "-1"

}

resource "aws_launch_configuration" "borja-server" {
  image_id      = "ami-00874d747dde814fa"
  instance_type = "t2.micro"
  user_data     = <<-EOF
    #!/bin/bash
    echo "Hello Worlds" >> index.html
    echo "${data.terraform_remote_state.db.outputs.address}" >> index.html
    echo "${data.terraform_remote_state.db.outputs.port}" >> index.html
    nohup busybox httpd -f -p ${var.server_port} &
  EOF

  security_groups = [aws_security_group.instance.id]

  lifecycle {
    create_before_destroy = true

  }


}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = local.any_port
  to_port           = local.any_port
  protocol          = local.any_protocol
  cidr_blocks       = [local.all_ips]
  security_group_id = aws_security_group.allow_lb.id
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  from_port         = local.http_port
  to_port           = local.http_port
  protocol          = local.tcp_protocol
  cidr_blocks       = [local.all_ips]
  security_group_id = aws_security_group.allow_lb.id

}

resource "aws_security_group" "instance" {
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_autoscaling_group" "createasg" {
  launch_configuration = aws_launch_configuration.borja-server.name

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true

  }
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.asg.id]
}

data "aws_vpc" "default" {
  default = true

}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]

  }

}

resource "aws_lb" "lb-blm" {
  subnets            = data.aws_subnets.default.ids
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_lb.id]

}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.lb-blm.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }


}
resource "aws_lb_target_group" "asg" {
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

}
resource "aws_security_group" "allow_lb" {
  name = "allow_lb"
}

data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-1"
  }

}
