terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}
variable "ami_id"{}
variable "account_id"{}
variable "profile"{}
resource "aws_vpc" "vpc"{
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "vpc ${timestamp()}"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "igw ${timestamp()}"
  }
}
resource "aws_subnet" "sb1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.subnet_cidr[0]
  availability_zone = var.subnet_az[0] 
  map_public_ip_on_launch = true
  tags = {
    Name = "sb1 ${timestamp()}"
  }
}
resource "aws_subnet" "sb2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.subnet_cidr[1]
  availability_zone = var.subnet_az[1] 
  map_public_ip_on_launch = true
    tags = {
    Name = "sb2 ${timestamp()}"
  }
}
resource "aws_subnet" "sb3" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.subnet_cidr[2]
  availability_zone = var.subnet_az[2] 
  map_public_ip_on_launch = true
    tags = {
    Name = "sb3 ${timestamp()}"
  }
}
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = var.ig_cidr
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "rt ${timestamp()}"
  }
}
resource "aws_route_table_association" "rt_sb1" {
  subnet_id      = aws_subnet.sb1.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_route_table_association" "rt_sb2" {
  subnet_id      = aws_subnet.sb2.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_route_table_association" "rt_sb3" {
  subnet_id      = aws_subnet.sb3.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_security_group" "application" {
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "application port"
    from_port   = var.appSgPorts["app"]
    to_port     = var.appSgPorts["app"]
    protocol    = "tcp"
    security_groups=[
      aws_security_group.lb_sg.id
    ]
  }
  ingress {
    description = "SSH"
    from_port   = var.appSgPorts["ssh"]
    to_port     = var.appSgPorts["ssh"]
    protocol    = "tcp"
    cidr_blocks = [var.appSgCidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application"
  }
}
resource "aws_security_group" "database" {
  description = "MySQL on RDS"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "TLS"
    from_port   = var.mysql_port
    to_port     = var.mysql_port
    protocol    = "tcp"
    security_groups=[
      aws_security_group.application.id
    ]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application"
  }
}
resource "aws_s3_bucket" "bucket" {
  bucket = "webapp.trivedh.audurthi"
  force_destroy=true
  lifecycle_rule {
    enabled=true
    transition {
      days=var.s3_webapp_bucket["days"]
      storage_class=var.s3_webapp_bucket["storage_class"]
    }
    noncurrent_version_transition {
      days=var.s3_webapp_bucket["days"]
      storage_class=var.s3_webapp_bucket["storage_class"]
    }
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm= "AES256"
      }
    }
  }
  versioning {
    enabled = true
  }
}
resource "aws_db_subnet_group" "db_subnet_grp" {
  subnet_ids = [aws_subnet.sb1.id, aws_subnet.sb2.id]

  tags = {
    Name = "My DB subnet group"
  }
}
resource "aws_db_instance" "rds" {
  multi_az             = var.rds_instance["multi_az"]
  identifier           = var.rds_instance["identifier"]
  allocated_storage    = var.rds_instance["storage"]
  engine               = var.rds_instance["engine"]
  engine_version       = var.rds_instance["engine_version"]
  instance_class       = var.rds_instance["instance_class"]
  name                 = var.rds_instance["dbname"]
  username             = var.rds_instance["username"]
  password             = var.rds_instance["password"]
  db_subnet_group_name = aws_db_subnet_group.db_subnet_grp.id
  vpc_security_group_ids = [aws_security_group.database.id]
  skip_final_snapshot  = var.rds_instance["skip_final_snapshot"]
}
data "template_file" "cloud_init" {
  template = file("${path.module}/cloudconfig.yml")
  vars = {
    rds_hostname = aws_db_instance.rds.address
    topic        = aws_sns_topic.sns_topic.arn
    region       = var.region
  }
}
resource "aws_dynamodb_table" "dynamoDB"{
  name       = var.dynamoDB["name"]
  hash_key   = var.dynamoDB["hash_key"]
  write_capacity = 2
  read_capacity  = 2
  attribute {
    name = var.dynamoDB["hash_key"]
    type = var.dynamoDB["hash_key_type"]
  }
}
resource "aws_iam_policy" "s3_iam_policy" {
  name        = "WebAppS3"
  description = "S3 IAM policy for application access"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
              "s3:DeleteObject",
              "s3:DeleteObjectVersion",
              "s3:GetObject",
              "s3:GetObjectVersion",
              "s3:PutObject"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::webapp.trivedh.audurthi",
                "arn:aws:s3:::webapp.trivedh.audurthi/*"
            ]
        }
    ]
}
EOF
}
resource "aws_iam_policy" "codedeploy_agent_policy_ec2" {
  name        = "CodeDeploy-EC2-S3"
  description = "EC2 policy to read from s3 buckets to download latest application revision"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
              "s3:List*",
              "s3:Get*"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::codedeploy.${var.profile=="dev"?"dev":"prod"}.trivedhaudurthi.me",
                "arn:aws:s3:::codedeploy.${var.profile=="dev"?"dev":"prod"}.trivedhaudurthi.me/*"
            ]
        }
    ]
}
EOF
}
resource "aws_iam_role" "ec2_instance_role" {
  name = "EC2-CSYE6225"
  assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Effect": "Allow"
        }
      ]
    }
EOF
}
resource "aws_iam_policy" "ec2_sns_policy" {
  name        = "ec2_sns_policy"
  path        = "/"
  description = "Enables EC2 to publish message to sns"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1606518220661",
      "Action": [
        "sns:Publish"
      ],
      "Effect": "Allow",
      "Resource": "${aws_sns_topic.sns_topic.arn}"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "ec2_s3_attachment" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.s3_iam_policy.arn
}
resource "aws_iam_role_policy_attachment" "ec2_s3_application" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.codedeploy_agent_policy_ec2.arn
}
resource "aws_iam_role_policy_attachment" "ec2_sns_attachment" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.ec2_sns_policy.arn
}
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_instance_role.name
}
resource "aws_codedeploy_app" "codedeploy_app" {
  compute_platform = "Server"
  name             = var.codedeploy_app
}
resource "aws_codedeploy_app" "codedeploy_lambda" {
  compute_platform = "Lambda"
  name             = var.codedeploy_lambda
}
resource "aws_iam_role" "codedeploy_servicerole" {
   name = "CodeDeployServiceRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
resource "aws_iam_role" "codedeploy_servicerole_lambda" {
   name = "CodeDeployServiceRoleLambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "attach_servicerole_codedeploy" {
  role       = aws_iam_role.codedeploy_servicerole.name
  policy_arn = var.AWSCodeDeployRole
}
resource "aws_iam_policy" "codedeploy_lambda_policy" {
  name        = "codedeploy_lambda_policy"
  description = "Provides codedeploy permissions to deploy Lambda"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "cloudwatch:DescribeAlarms",
                "lambda:UpdateAlias",
                "lambda:GetAlias",
                "lambda:GetProvisionedConcurrencyConfig"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::codedeploy.${var.profile=="dev"?"dev":"prod"}.trivedhaudurthi.me",
                "arn:aws:s3:::codedeploy.${var.profile=="dev"?"dev":"prod"}.trivedhaudurthi.me/*"
            ],
            "Effect":"Allow"
        },
        {
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": "arn:aws:lambda:*:*:function:CodeDeployHook_*",
            "Effect": "Allow"
        }
    ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "attach_servicerole_lambda_codedeploy" {
  role       = aws_iam_role.codedeploy_servicerole_lambda.name
  policy_arn = aws_iam_policy.codedeploy_lambda_policy.arn
}
resource "aws_codedeploy_deployment_group" "deployment_group" {
  app_name  = aws_codedeploy_app.codedeploy_app.name
  deployment_group_name = var.deploymentGroup["deployment_group_name"]
  service_role_arn      = aws_iam_role.codedeploy_servicerole.arn
  autoscaling_groups    = [aws_autoscaling_group.asg.name]
  deployment_config_name = var.deploymentGroup["deployment_config_name"]
  load_balancer_info {
    target_group_info { 
      name= aws_lb_target_group.alb_tg.name
      }
  } 
  auto_rollback_configuration {
    enabled = true
    events  = [var.deploymentGroup["auto_rollback_events"]]
  }
}
resource "aws_codedeploy_deployment_group" "deployment_group_lambda" {
  app_name  = aws_codedeploy_app.codedeploy_lambda.name
  deployment_group_name = var.deploymentGroupLambda["deployment_group_name"]
  service_role_arn      = aws_iam_role.codedeploy_servicerole_lambda.arn
  deployment_config_name = var.deploymentGroupLambda["deployment_config_name"]
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }
}
resource "aws_iam_role" "lambda_exec_role" {
  name = "iam_for_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "Provieds lambda funtion permission to get access SES,DynamoDB and Cloudwatch"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
          {
          "Effect": "Allow",
          "Action": [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
          ],
          "Resource": [
            "arn:aws:logs:us-east-1:488753017811:*",
            "arn:aws:logs:us-east-1:488753017811:log-group:/aws/lambda/${var.lambda["function_name"]}:*"
          ]
      },
      {
      "Sid": "Stmt1606502279390",
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:DescribeLimits",
        "dynamodb:GetItem",
        "dynamodb:GetRecords",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:UpdateItem"
      ],
      "Effect": "Allow",
      "Resource":"${aws_dynamodb_table.dynamoDB.arn}"
    },
    {
      "Sid": "Stmt1606509728742",
      "Action": [
        "ses:SendEmail",
        "ses:SendRawEmail",
        "ses:SendTemplatedEmail"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:ses:${var.region}:${var.account_id}:identity/${var.profile}.trivedhaudurthi.me"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "attach_lambda_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}
resource "aws_lambda_function" "lambda" {
  filename = var.lambda["filename"]
  function_name = var.lambda["function_name"]
  handler = var.lambda["handler"]
  role    = aws_iam_role.lambda_exec_role.arn
  runtime = var.lambda["runtime"]
  timeout = var.lambda["timeout"]
  reserved_concurrent_executions = var.lambda["reserved_concurrent_executions"]
  publish = var.lambda["publish"]
  source_code_hash = filebase64sha256(var.lambda["filename"])
  environment {
    variables = {
      "table" = aws_dynamodb_table.dynamoDB.id,
      "account"= var.profile
    }
  }
}

resource "aws_lambda_alias" "lambda_alias" {
  name = var.lambda_alias["name"]
  description = var.lambda_alias["description"]
  function_name = aws_lambda_function.lambda.arn
  function_version = aws_lambda_function.lambda.version
}
resource "aws_sns_topic" "sns_topic" {
  name = var.sns_topic["name"]
}
data "aws_iam_policy_document" "sns_access_policy" {
  policy_id = "__default_policy_ID"
  statement {
    sid = "__default_statement_ID"
    actions = [ "SNS:GetTopicAttributes",
        "SNS:SetTopicAttributes",
        "SNS:AddPermission",
        "SNS:RemovePermission",
        "SNS:DeleteTopic",
        "SNS:Subscribe",
        "SNS:ListSubscriptionsByTopic",
        "SNS:Publish",
        "SNS:Receive" ]
    effect = "Allow"
    principals {
       type = "AWS"
       identifiers = [ "*" ]
    }
    resources = [ "arn:aws:sns:${var.region}:${var.account_id}:${var.sns_topic["name"]}" ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        var.account_id,
      ]
    }
  }
}
resource "aws_sns_topic_policy" "attach_sns_access_policy" {
  arn = aws_sns_topic.sns_topic.arn
  policy = data.aws_iam_policy_document.sns_access_policy.json
}
resource "aws_sns_topic_subscription" "sns_lambda_sub" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.lambda.arn}:${var.lambda_alias["name"]}"
}
resource "aws_lambda_permission" "lambda_sns_res_stmt" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda["function_name"]
  qualifier     = aws_lambda_alias.lambda_alias.name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_topic.arn
}
resource "aws_iam_user_policy" "gh_upload_to_s3" {
  name        = "GH-Upload-To-S3"
  user        = var.ghactions

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::codedeploy.${var.profile=="dev"?"dev":"prod"}.trivedhaudurthi.me",
                "arn:aws:s3:::codedeploy.${var.profile=="dev"?"dev":"prod"}.trivedhaudurthi.me/*"
            ]
        }
    ]
}
EOF
}
resource "aws_iam_user_policy" "gh_upload_to_s3_lambda" {
  name        = "GH-Upload-To-S3_Lambda"
  user        = var.ghactions_lambda

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::codedeploy.${var.profile=="dev"?"dev":"prod"}.trivedhaudurthi.me",
                "arn:aws:s3:::codedeploy.${var.profile=="dev"?"dev":"prod"}.trivedhaudurthi.me/*"
            ]
        }
    ]
}
EOF
}
resource "aws_iam_user_policy" "gh_code_deploy" {
  name        = "GH-Code-Deploy"
  user        = var.ghactions

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${var.account_id}:application:${var.codedeploy_app}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentgroup:${var.codedeploy_app}/${var.deploymentGroup["deployment_group_name"]}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeploymentConfig"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentconfig:CodeDeployDefault.OneAtATime",
        "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentconfig:CodeDeployDefault.HalfAtATime",
        "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
      ]
    }
  ]
}
EOF
}
resource "aws_iam_user_policy" "gh_code_deploy_lambda" {
  name        = "GH-Code-Deploy_Lambda"
  user        = var.ghactions_lambda

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${var.account_id}:application:${var.codedeploy_lambda}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentgroup:${var.codedeploy_lambda}/${var.deploymentGroupLambda["deployment_group_name"]}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeploymentConfig"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentconfig:CodeDeployDefault.LambdaAllAtOnce"
      ]
    },
    {
      "Action": [
        "lambda:GetAlias",
        "lambda:GetFunction",
        "lambda:PublishVersion",
        "lambda:UpdateAlias",
        "lambda:UpdateFunctionCode"
      ],
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.lambda.arn}"
    }
  ]
}
EOF
}
resource "aws_route53_record" "ec2_record" {
  zone_id = var.profile=="dev"?var.route53["dev_zone_id"]:var.route53["prod_zone_id"]
  name    = var.route53["name"]
  type    = var.route53["type"]
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_application" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = var.cloudwatch_policy
}
resource "aws_launch_configuration" "lc_conf" {
  name          = var.launch_config["name"]
  image_id      = var.ami_id
  instance_type = var.launch_config["instance_type"]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  key_name     = var.launch_config["key_name"]
  security_groups= [aws_security_group.application.id]
  # enable_monitoring = var.launch_config["enable_monitoring"]
  user_data              = data.template_file.cloud_init.rendered
  associate_public_ip_address = var.launch_config["associate_public_ip_address"] 
}
resource "aws_autoscaling_group" "asg" {
  max_size                  = var.asg["max"]
  min_size                  = var.asg["min"]
  desired_capacity          = var.asg["desired"]
  launch_configuration      = aws_launch_configuration.lc_conf.name
  vpc_zone_identifier       = [aws_subnet.sb1.id, aws_subnet.sb2.id,aws_subnet.sb3.id]
  target_group_arns         = [aws_lb_target_group.alb_tg.arn]
  tag {
    key                 = "name"
    value               = "dev"
    propagate_at_launch = true
  }
}
resource "aws_autoscaling_policy" "scaleup_policy" {
  name                   = var.scaleup_policy["name"]
  scaling_adjustment     = var.scaleup_policy["ScalingAdjustment"]
  adjustment_type        = var.scaleup_policy["AdjustmentType"]
  cooldown               = var.scaleup_policy["Cooldown"]
  autoscaling_group_name = aws_autoscaling_group.asg.name
}
resource "aws_autoscaling_policy" "scaledown_policy" {
  name                   = var.scaledown_policy["name"]
  scaling_adjustment     = var.scaledown_policy["ScalingAdjustment"]
  adjustment_type        = var.scaledown_policy["AdjustmentType"]
  cooldown               = var.scaledown_policy["Cooldown"]
  autoscaling_group_name = aws_autoscaling_group.asg.name
}
resource "aws_cloudwatch_metric_alarm" "high_alarm" {
  alarm_name          = var.high_alarm["name"]
  comparison_operator = var.high_alarm["comparisonOperator"]
  evaluation_periods  = var.high_alarm["evaluationPeriods"]
  metric_name         = var.high_alarm["metricName"]
  namespace           = var.high_alarm["namespace"]
  period              = var.high_alarm["period"]
  statistic           = var.high_alarm["statistic"]
  threshold           = var.high_alarm["threshold"]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  alarm_description = var.high_alarm["alarmDescription"]
  alarm_actions     = [aws_autoscaling_policy.scaleup_policy.arn]
}
resource "aws_cloudwatch_metric_alarm" "low_alarm" {
  alarm_name          = var.low_alarm["name"]
  comparison_operator = var.low_alarm["comparisonOperator"]
  evaluation_periods  = var.low_alarm["evaluationPeriods"]
  metric_name         = var.low_alarm["metricName"]
  namespace           = var.low_alarm["namespace"]
  period              = var.low_alarm["period"]
  statistic           = var.low_alarm["statistic"]
  threshold           = var.low_alarm["threshold"]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  alarm_description = var.low_alarm["alarmDescription"]
  alarm_actions     = [aws_autoscaling_policy.scaledown_policy.arn]
}
resource "aws_lb" "alb" {
  internal           = var.alb["internal"]
  load_balancer_type = var.alb["load_balancer_type"]
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.sb1.id,aws_subnet.sb2.id,aws_subnet.sb3.id]
}
resource "aws_security_group" "lb_sg" {
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "TLS"
    from_port   = var.appSgPorts["tls"]
    to_port     = var.appSgPorts["tls"]
    protocol    = "tcp"
    cidr_blocks = [var.appSgCidr]
  }
  ingress {
    description = "Http"
    from_port   = var.appSgPorts["http"]
    to_port     = var.appSgPorts["http"]
    protocol    = "tcp"
    cidr_blocks = [var.appSgCidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "loadBalancerSg"
  }
}
resource "aws_lb_target_group" "alb_tg" {
  port     = var.tg["port"]
  protocol = var.tg["protocol"]
  vpc_id   = aws_vpc.vpc.id
  health_check {
    path = "/v1/health"
    matcher=200
  }
}
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = var.listener["port"]
  protocol          = var.listener["protocol"]
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}