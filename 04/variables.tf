variable "region"{
    type=string
    default="us-east-1"
}
variable "vpc_cidr"{
    type=string
    default="172.31.0.0/16"
}

variable "subnet_cidr"{
    type=list
    default=[
    "172.31.1.0/24",
    "172.31.2.0/24",
    "172.31.3.0/24"
    ]
}
variable "subnet_az" {
    type=list
    default=[
    "us-east-1a",
    "us-east-1b",
    "us-east-1c",
    ]
}
variable "ig_cidr"{
    type=string
    default="0.0.0.0/0"
}
variable "appSgPorts"{
    type=map
    default={
        "tls"=443,
        "app"=5000,
        "ssh"=22,
        "http"=80
    }
}
variable "appSgCidr"{
    type=string
    default="0.0.0.0/0"
}
variable "mysql_port"{
    type=number
    default=3306
}
variable "s3_webapp_bucket"{
    type=map
    default={
        "days"=30
        "storage_class"="STANDARD_IA"
    }
}
variable "rds_instance"{
    type=map
    default={
        "multi_az"=false
        "storage"=20
        "identifier"="csye6225-f20"
        "engine"="mysql"
        "engine_version"="5.7"
        "instance_class"="db.t2.micro"
        "dbname"="csye6225"
        "username"="csye6225fall2020"
        "password"="Test1234"
        "skip_final_snapshot"=true
    }
}
variable "ec2_instance"{
    type=map
    default={
        "ami"="ami-09d74e34010fb66a2"
        "delete_on_termination" =true
        "instance_type"="t2.micro"
        "volume_size"=20
        "volume_type"="gp2"
        "key_name"="csye6225-dev"
    }
}
variable "dynamoDB"{
    type=map
    default={
        "name"="csye6225"
        "hash_key"="id"
        "hash_key_type"="S"
    }
}
variable "AWSCodeDeployRole"{
    type=string
    default="arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}
variable "deploymentGroup"{
    type=map
    default={
        "deployment_group_name"="dev"
        "key1"="Name"
        "value1"="dev"
        "deployment_config_name"="CodeDeployDefault.AllAtOnce"
        "auto_rollback_events"="DEPLOYMENT_FAILURE"
    }
}
variable "ghactions"{
    type=string
    default="ghactions_deploy"
}
variable "codedeploy_app"{
    type=string
    default="csye6225-webapp"
}
variable "route53"{
    type=map
    default={
        "dev_zone_id"="Z05785683GYSFOVZG19DH"
        "prod_zone_id"="Z06917591F8BU19ZH0VI8"
        "name"="api"
        "type"="A"
    }
}
variable "cloudwatch_policy"{
    type=string
    default="arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
variable "launch_config"{
    type=map
    default={
        "name"="asg_launch_config"
        "instance_type"="t2.micro"
        "key_name"="csye6225-dev"
        "associate_public_ip_address"="true"
        "enable_monitoring"="false"
    }
}
variable "asg"{
    type=map
    default={
        "cooldown"=60
        "min"=3
        "max"=5
        "desired"=3
    }
}
variable "scaleup_policy"{
    type=map
    default={
      "name"="WebServerScaleUpPolicy"
      "AdjustmentType"= "ChangeInCapacity"
      "Cooldown"= "60",
      "ScalingAdjustment"= "1"
    }
}
variable "scaledown_policy"{
    type=map
    default={
      "name"="WebServerScaleDownPolicy"
      "AdjustmentType"= "ChangeInCapacity"
      "Cooldown"= "60",
      "ScalingAdjustment"= "-1"
    }
}
variable "high_alarm"{
    type=map
    default={
        "name"="CPUAlarmHigh"
        "alarmDescription"= "Scale-up if CPU > 5% for 4 minutes"
        "metricName"= "CPUUtilization"
        "namespace"= "AWS/EC2"
        "statistic"= "Average"
        "period"= 120
        "evaluationPeriods"= 2
        "threshold"= 5
        "comparisonOperator"= "GreaterThanThreshold"

    }
}
variable "low_alarm"{
    type=map
    default={
        "name"="CPUAlarmLow"
        "alarmDescription"= "Scale-down if CPU <3% for 4 minutes"
        "metricName"= "CPUUtilization"
        "namespace"= "AWS/EC2"
        "statistic"= "Average"
        "period"= 120
        "evaluationPeriods"= 2
        "threshold"= 3
        "comparisonOperator"= "LessThanThreshold"
    }
}
variable "alb"{
    type=map
    default={
        "load_balancer_type" = "application"
        "internal"  = false
    }
}
variable "tg"{
    type=map
    default={
        "port"=5000
        "protocol"="HTTP"
    }
}
variable "listener"{
    type=map
    default={
        "port"=80
        protocol="HTTP"
        
    }
}