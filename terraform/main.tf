provider "aws" {
  profile = var.profile_name
  region = var.region
}
data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = var.ecs_cluster_name
}

resource "random_string" "random_string" {
  length = 8
  special = false
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-polynote-${random_string.random_string.result}"
  assume_role_policy = <<ASSUME_ROLE_POLICY
{
"Version": "2012-10-17",
"Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
ASSUME_ROLE_POLICY
}

data "aws_iam_policy" "amazon_ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "policy_role_attachment" {
  role = aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.aws_iam_policy.amazon_ecs_task_execution_role_policy.arn
}


resource "aws_cloudwatch_log_group" "polynote_ecs_log_group" {
  name = "/aws/ecs/polynote-${random_string.random_string.result}"
}

resource "random_string" "password" {
  length = 24
  special = false
}

resource "aws_ecs_task_definition" "polynote_task_definition" {
  family = "polynote-${random_string.random_string.result}"
  requires_compatibilities = [
    "FARGATE"]
  network_mode = "awsvpc"
  cpu = var.cpu
  memory = var.memory
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = <<TASK_DEFINITION
  [
    {
        "essential": true,
        "image": "registry.hub.docker.com/sschrijver/polynote-basic-config:latest",
        "name": "polynote",
        "portMappings": [
            {
                "containerPort": 8192,
                "hostPort": 8192
            }
        ],
        "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                  "awslogs-region": "${var.region}",
                  "awslogs-group": "${aws_cloudwatch_log_group.polynote_ecs_log_group.name}",
                  "awslogs-stream-prefix": "polynote-${random_string.random_string.result}"
            }
        }
    },
    {
        "essential": true,
        "image": "registry.hub.docker.com/sschrijver/polynote-nginx:latest",
        "name": "nginx",
        "dependsOn": [
            {
                "containerName": "polynote",
                "condition": "START"
            }
        ],
        "portMappings": [
            {
                "containerPort": 8080,
                "hostPort": 8080
            }
        ],
        "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                  "awslogs-region": "${var.region}",
                  "awslogs-group": "${aws_cloudwatch_log_group.polynote_ecs_log_group.name}",
                  "awslogs-stream-prefix": "nginx-${random_string.random_string.result}"
            }
        },
        "environment": [
            {
                "name": "SERVER_NAME",
                "value": "127.0.0.1"
            },
            {
                "name": "PORT",
                "value": "8080"
            },
            {
                "name": "BASIC_AUTH_USERNAME",
                "value": "polynote"
            },
            {
                "name": "BASIC_AUTH_PASSWORD",
                "value": "${random_string.password.result}"
            },
            {
                "name": "PROXY_PASS",
                "value": "http://127.0.0.1:8192"
            }
        ]
    }
  ]
  TASK_DEFINITION
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_lb" "lb" {
  arn = var.loadbalancer_arn
}

data "aws_lb_listener" "lb_listener" {
  load_balancer_arn = var.loadbalancer_arn
  port = 443
}


resource "aws_lb_target_group" "polynote_target_group" {
  name = "polynote-${random_string.random_string.result}"
  port = 80
  protocol = "HTTP"
  vpc_id = data.aws_vpc.vpc.id
  target_type = "ip"
  health_check {
    matcher = "200,302,401"
  }
}

  resource "aws_security_group" "polynote_security_group" {
    name = "polynote_${random_string.random_string.result}"
    vpc_id = data.aws_vpc.vpc.id

    ingress {
      description = "Incoming 8080"
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      security_groups = data.aws_lb.lb.security_groups
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = [
        "0.0.0.0/0"]
    }

    tags = {
      Name = "polynote_${random_string.random_string.result}"
    }
  }

resource "aws_ecs_service" "polynote_service" {
  name = "polynote-${random_string.random_string.result}"
  cluster = data.aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.polynote_task_definition.id
  desired_count = 1
  launch_type = "FARGATE"

  network_configuration {
    subnets = var.fargate_subnets
    security_groups = [
      aws_security_group.polynote_security_group.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.polynote_target_group.arn
    container_name = "nginx"
    container_port = 8080
  }
  depends_on = [
    aws_lb_target_group.polynote_target_group]
}



resource "aws_lb_listener_rule" "polynote_lb_listener_rule" {
  listener_arn = data.aws_lb_listener.lb_listener.arn
  priority = null

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.polynote_target_group.arn
  }

  condition {
    host_header {
      values = [
        "polynote-${random_string.random_string.result}.${var.domain}"]
    }
  }

  depends_on = [
    aws_lb_target_group.polynote_target_group]
}

resource "aws_route53_record" "polynote_cname" {
  zone_id = var.hosted_zone_id
  name = "polynote-${random_string.random_string.result}.${var.domain}"
  type = "CNAME"
  records = [
    data.aws_lb.lb.dns_name]
  ttl = 300
}

output "url" {
  value = "https://${aws_route53_record.polynote_cname.name}"
}

output "username" {
  value = "polynote"
}

output "password" {
  value = random_string.password.result
}
