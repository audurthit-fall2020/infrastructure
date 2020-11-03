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
    description = "TLS"
    from_port   = var.appSgPorts["tls"]
    to_port     = var.appSgPorts["tls"]
    protocol    = "tcp"
    cidr_blocks = [var.appSgCidr]
  }
  ingress {
    description = "application port"
    from_port   = var.appSgPorts["app"]
    to_port     = var.appSgPorts["app"]
    protocol    = "tcp"
    cidr_blocks = [var.appSgCidr]
  }
  ingress {
    description = "SSH"
    from_port   = var.appSgPorts["ssh"]
    to_port     = var.appSgPorts["ssh"]
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
  }
}
resource "aws_instance" "web" {
  ami                  = var.ami_id
  instance_type        = var.ec2_instance["instance_type"]
  key_name             = var.ec2_instance["key_name"]
  root_block_device {
    volume_size   = var.ec2_instance["volume_size"]
    delete_on_termination= var.ec2_instance["delete_on_termination"]
    volume_type   = var.ec2_instance["volume_type"]
  }
  vpc_security_group_ids = [aws_security_group.application.id]
  subnet_id              = aws_subnet.sb3.id
  user_data              = data.template_file.cloud_init.rendered
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  tags = {
    Name = "dev"
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
resource "aws_iam_role_policy_attachment" "ec2_s3_attachment" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.s3_iam_policy.arn
}
resource "aws_iam_role_policy_attachment" "ec2_s3_application" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.codedeploy_agent_policy_ec2.arn
}
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_instance_role.name
}
resource "aws_codedeploy_app" "codedeploy_app" {
  compute_platform = "Server"
  name             = var.codedeploy_app
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
resource "aws_iam_role_policy_attachment" "attach_servicerole_codedeploy" {
  role       = aws_iam_role.codedeploy_servicerole.name
  policy_arn = var.AWSCodeDeployRole
}
resource "aws_codedeploy_deployment_group" "deployment_group" {
  app_name  = aws_codedeploy_app.codedeploy_app.name
  deployment_group_name = var.deploymentGroup["deployment_group_name"]
  service_role_arn      = aws_iam_role.codedeploy_servicerole.arn
  ec2_tag_set {
    ec2_tag_filter {
      key   = var.deploymentGroup["key1"]
      type  = "KEY_AND_VALUE"
      value = var.deploymentGroup["value1"]
    }
  }
  deployment_config_name = var.deploymentGroup["deployment_config_name"] 
  auto_rollback_configuration {
    enabled = true
    events  = [var.deploymentGroup["auto_rollback_events"]]
  }
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
        "*"
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
resource "aws_route53_record" "ec2_record" {
  zone_id = var.profile=="dev"?var.route53["dev_zone_id"]:var.route53["prod_zone_id"]
  name    = var.route53["name"]
  type    = "A"
  ttl     = "60"
  records = [aws_instance.web.public_ip]
}