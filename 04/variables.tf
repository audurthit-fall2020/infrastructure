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