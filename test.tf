terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 3.0"
        }
    }
}

provider "aws" {
    region = "us-east-1"
}
provider "aws" {
  alias  = "oregon"
  region = "us-west-2"
}



resource "aws_security_group" "EC2SecurityGroup" {
    description = "test"
    name = "test"
    tags = {
        
    }
    vpc_id = "${aws_vpc.EC2VPC.id}"
    ingress {
        cidr_blocks = [
            "0.0.0.0/0"
        ]
        from_port = 0
        protocol = "-1"
        to_port = 0
    }
    egress {
        cidr_blocks = [
            "0.0.0.0/0"
        ]
        from_port = 0
        protocol = "-1"
        to_port = 0
    }
}
resource "null_resource" "previous" {}

resource "aws_vpc" "EC2VPC" {
    cidr_block = "192.168.0.0/24"
    enable_dns_support = true
    enable_dns_hostnames = true
    instance_tenancy = "default"
    tags = {
        Name = "Test"
    }
}

resource "aws_subnet" "EC2Subnet" {
    availability_zone = "us-east-1a"
    cidr_block = "${aws_vpc.EC2VPC.cidr_block}"
    vpc_id = "${aws_vpc.EC2VPC.id}"
    map_public_ip_on_launch = false
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.EC2Subnet.id
  route_table_id = aws_route_table.EC2RouteTable.id
}
resource "aws_vpc_endpoint" "EC2VPCEndpoint" {
    vpc_endpoint_type = "Interface"
    vpc_id = "${aws_vpc.EC2VPC.id}"
    service_name = "com.amazonaws.us-east-1.ssm"
    policy = <<EOF
{
  "Statement": [
    {
      "Action": "*", 
      "Effect": "Allow", 
      "Principal": "*", 
      "Resource": "*"
    }
  ]
}
EOF
    subnet_ids = [
        "${aws_subnet.EC2Subnet.id}"
    ]
    private_dns_enabled = true
    security_group_ids = [
        "${aws_security_group.EC2SecurityGroup.id}"
    ]
}

resource "aws_vpc_endpoint" "EC2VPCEndpoint2" {
    vpc_endpoint_type = "Interface"
    vpc_id = "${aws_vpc.EC2VPC.id}"
    service_name = "com.amazonaws.us-east-1.ssmmessages"
    policy = <<EOF
{
  "Statement": [
    {
      "Action": "*", 
      "Effect": "Allow", 
      "Principal": "*", 
      "Resource": "*"
    }
  ]
}
EOF
    subnet_ids = [
        "${aws_subnet.EC2Subnet.id}"
    ]
    private_dns_enabled = true
    security_group_ids = [
        "${aws_security_group.EC2SecurityGroup.id}"
    ]
}

resource "aws_vpc_endpoint" "EC2VPCEndpoint3" {
    vpc_endpoint_type = "Gateway"
    vpc_id = "${aws_vpc.EC2VPC.id}"
    service_name = "com.amazonaws.us-east-1.s3"
    policy = "{\"Version\":\"2008-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"*\",\"Resource\":\"*\"}]}"
    route_table_ids = [
        "${aws_route_table.EC2RouteTable.id}"
    ]
    private_dns_enabled = false
}

resource "aws_route_table" "EC2RouteTable" {
    vpc_id = "${aws_vpc.EC2VPC.id}"
    tags = {
        
    }
}
resource "aws_iam_instance_profile" "IAMInstanceProfile" {
    path = "/"
    name = "${aws_iam_role.IAMRole.name}"
    role = "${aws_iam_role.IAMRole.name}"
}

resource "aws_iam_role" "IAMRole" {
    path = "/"
    name = "ec2_role"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    managed_policy_arns = [aws_iam_policy.IAMManagedPolicy.arn]
}
resource "aws_iam_policy" "IAMManagedPolicy" {
    name = "ec2-role"
    policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeAssociation",
                "ssm:GetDeployablePatchSnapshotForInstance",
                "ssm:GetDocument",
                "ssm:DescribeDocument",
                "ssm:GetManifest",
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:ListAssociations",
                "ssm:ListInstanceAssociations",
                "ssm:PutInventory",
                "ssm:PutComplianceItems",
                "ssm:PutConfigurePackageResult",
                "ssm:UpdateAssociationStatus",
                "ssm:UpdateInstanceAssociationStatus",
                "ssm:UpdateInstanceInformation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2messages:AcknowledgeMessage",
                "ec2messages:DeleteMessage",
                "ec2messages:FailMessage",
                "ec2messages:GetEndpoint",
                "ec2messages:GetMessages",
                "ec2messages:SendReply"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:*",
                "s3-object-lambda:*"
            ],
            "Resource": "*"
        },
       ]
    })
}
resource "aws_s3_bucket" "my_s3_bucket" {
  bucket_prefix = "test-"
  provider = aws.oregon

  tags = {
    Name        = "test"
  }
}
resource "aws_instance" "EC2Instance" {
    ami = "ami-0cff7528ff583bf9a"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    tenancy = "default"
    subnet_id = "${aws_subnet.EC2Subnet.id}"
    ebs_optimized = false
    user_data = <<EOF
    #!/bin/bash
    sleep 20
    sudo systemctl stop amazon-ssm-agent
    sudo systemctl start amazon-ssm-agent
    EOF
    depends_on = [
        aws_vpc_endpoint.EC2VPCEndpoint,
        aws_vpc_endpoint.EC2VPCEndpoint2,
        aws_vpc_endpoint.EC2VPCEndpoint3,
        time_sleep.wait_60_seconds

  ]
    vpc_security_group_ids = [
        "${aws_security_group.EC2SecurityGroup.id}"
    ]
    source_dest_check = true
    root_block_device {
        volume_size = 8
        volume_type = "gp2"
        delete_on_termination = true
        }
   iam_instance_profile = "${aws_iam_instance_profile.IAMInstanceProfile.name}"
    tags = {
        Name = "Test"
    }
}
resource "time_sleep" "wait_60_seconds" {
  depends_on = [null_resource.previous, 
        aws_vpc_endpoint.EC2VPCEndpoint,
        aws_vpc_endpoint.EC2VPCEndpoint2,
        aws_vpc_endpoint.EC2VPCEndpoint3]

  create_duration = "60s"
}