variable "aws-region" {
    default = "ap-southeast-2"
}

variable "cidr-block" {
    default = "12.12.0.0/16"
}

variable "ami" {
    default = "ami-03f0544597f43a91d"
}

variable instance-type {
    default = "t3.micro"
}
