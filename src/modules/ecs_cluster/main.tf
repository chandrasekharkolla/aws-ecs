resource "aws_cloudwatch_log_group" "cloudwatch" {
  name_prefix = var.cloudwatch_group_name
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  configuration {
    execute_command_configuration {
      # kms_key_id = aws_kms_key.example.arn
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.cloudwatch.name
      }
    }
  }
}

resource "aws_alb_target_group" "target_group" {
  name        = var.lb_target_group_name
  target_type = "ip"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 6
    matcher             = "200-299"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
  }
}

# resource "aws_lb_target_group_attachment" "target_group_attachment" {
#   target_group_arn = aws_alb_target_group.target_group.arn
#   target_id        = null
# }

resource "aws_ecs_service" "ecs_service" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 3
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_alb_target_group.target_group.arn
    container_name   = "first"
    container_port   = 8080
  }

  network_configuration {
    security_groups = [aws_security_group.my_security_group.id]
    subnets         = var.private_subnets
  }
}

resource "aws_iam_policy_attachment" "ecs_role" {
  name       = "policy-attachment-to-ecs-role"
  roles      = [aws_iam_role.ecs_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_role" "ecs_role" {
  name = "ecs-task-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "my_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["ecr:*"]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family = var.task_definition_name

  # container_definitions    = templatefile("${path.module}/templates/service.json", local.template_vars)
  container_definitions = <<DEFINITION
[
  {
    "name": "first",
    "image": "${var.image_uri}",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${var.task_definition_name}",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
DEFINITION

  task_role_arn            = var.taskRoleArn
  execution_role_arn       = var.ecs_executionRoleArn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  tags = merge(
    var.ecs_task_tags,
    {
      "TaskDefinition_Name" = "${var.task_definition_name}-TaskDefinition"
    }
  )
}

resource "aws_security_group" "my_security_group" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    # TLS (change to whatever ports you need)
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.alb.id
  port              = "80"
  protocol          = "HTTP"
  # ssl_policy        = "ELBSecurityPolicy-2016-08"
  # certificate_arn   = module.acm_certificate[each.key].arn

  default_action {
    target_group_arn = aws_alb_target_group.target_group.id
    type             = "forward"
  }
}

resource "aws_alb_listener" "https_listener" {
  load_balancer_arn = aws_alb.alb.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    target_group_arn = aws_alb_target_group.target_group.id
    type             = "forward"
  }
}

resource "aws_alb_listener_certificate" "https" {
  for_each = aws_acm_certificate.certs

  listener_arn    = aws_alb_listener.https_listener.arn
  certificate_arn = each.value.arn
}

resource "aws_alb" "alb" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.my_security_group.id}"]
  subnets            = var.public_subnets
  name               = var.lb_name
}

resource "aws_route53_record" "route" {

  zone_id = data.aws_route53_zone.net_hosted_zone.zone_id
  name    = "first"
  type    = "CNAME"
  ttl     = 300

  records = [aws_alb.alb.dns_name]
}

resource "aws_route53_record" "test" {

  zone_id = data.aws_route53_zone.net_hosted_zone.zone_id
  name    = "test"
  type    = "CNAME"
  ttl     = 300

  records = [aws_alb.alb.dns_name]
}

data "aws_route53_zone" "net_hosted_zone" {
  name         = var.net_hosted_zone_name
  private_zone = false
}

data "aws_route53_zone" "click_hosted_zone" {
  name         = var.click_hosted_zone_name
  private_zone = false
}

resource "aws_acm_certificate" "cert" {
  domain_name = var.cert_domain_name
  # subject_alternative_names = var.subject_alternative_names
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "certs" {
  for_each = toset(var.cert_domain_names)

  domain_name = each.key
  # subject_alternative_names = var.subject_alternative_names
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_dnss" {
  for_each = aws_acm_certificate.certs

  allow_overwrite = true
  name            = tolist(each.value.domain_validation_options)[0].resource_record_name
  records         = [tolist(each.value.domain_validation_options)[0].resource_record_value]
  type            = tolist(each.value.domain_validation_options)[0].resource_record_type
  zone_id         = data.aws_route53_zone.net_hosted_zone.zone_id
  ttl             = 60
}

resource "aws_route53_record" "cert_dns" {
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_type
  zone_id         = data.aws_route53_zone.net_hosted_zone.zone_id
  ttl             = 60
}

resource "aws_route53_record" "click_domain" {
  zone_id = data.aws_route53_zone.click_hosted_zone.zone_id
  name    = var.click_hosted_zone_name
  type    = "A"

  alias {
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate_validation" "certs_validate" {
  for_each = aws_acm_certificate.certs

  certificate_arn         = each.value.arn
  validation_record_fqdns = [aws_route53_record.cert_dnss[each.key].fqdn]
}

resource "aws_acm_certificate_validation" "cert_validate" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_dns.fqdn]
}

resource "aws_acm_certificate" "click" {
  domain_name       = "moonlightorg.click"
  validation_method = "DNS"
}

resource "aws_route53_record" "click_validation" {
  name    = tolist(aws_acm_certificate.click.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.click.domain_validation_options)[0].resource_record_type
  zone_id = data.aws_route53_zone.click_hosted_zone.id
  records = [tolist(aws_acm_certificate.click.domain_validation_options)[0].resource_record_value]

  ttl = 60
}

resource "aws_acm_certificate_validation" "example_validate" {
  certificate_arn         = aws_acm_certificate.click.arn
  validation_record_fqdns = [aws_route53_record.click_validation.fqdn]
}

resource "aws_alb_listener_certificate" "click" {
  listener_arn    = aws_alb_listener.https_listener.arn
  certificate_arn = aws_acm_certificate.click.arn
}

# resource "aws_alb_listener_rule" "listener_rule" {
#   listener_arn = aws_alb_listener.https_listener.arn

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.target_group[0].arn
#   }

#   condition {
#     path_pattern {
#       values = ["${var.service_path}/*"]
#     }
#   }
# }

resource "random_string" "random" {
  count   = 25
  length  = 10
  special = false
}

resource "aws_alb_listener_rule" "service" {
  listener_arn = aws_alb_listener.https_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.target_group.arn
  }

  # condition {
  #   host_header {
  #     values = var.alb_listener_rule_host_header_values
  #   }
  # }

  dynamic "condition" {
    for_each = toset([for random_str in random_string.random : random_str.result])
    content {
      path_pattern {
        values = [condition.value]
      }
    }
  }
}
