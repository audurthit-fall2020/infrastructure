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
        "instance_class"="db.t3.micro"
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