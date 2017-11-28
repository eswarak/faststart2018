#Variables
variable "aws_region" {
    description = "AWS Region to use"
    default     = "us-east-1"
}

#Availability Zones - Change it
variable "azs" {
   type        = "list"
   description = "List of availability zones that instance can be provisioned to"
   default     = [ "us-east-1a", "us-east-1b" ]
}

# AWS KeyName - Change it
variable "KeyPair_Name" {
   description  = "Desired name of the AWS key pair"
   default = "" 
}

variable "Public_SSHKey" {
   description  = "Public SSH Key"
   default = ""
}

# Amazon Linux - Change it
variable "aws_amis" {
   default = "ami-55ef662f"
}

#Security Group to use - Change it
variable "securitygroup" {
   description = "Name of the security group to associate with the instance"
   default     = "sg-a47df2d1"
}

#Instance Type
variable "instance_type" {
    description = "Type and size of the instance"
    default     = "t2.micro"
}

#Number of instances
variable "instance_count" {
   description = "No of Instances more than 2 in counts of 2"
   default     = "4"
}

#Subnets - Change it
variable "aws_subnet" {
    description = "Subnet for the ELB"
    default     = [ "subnet-9297fff7", "subnet-b69ff99c" ]
}

variable "ElasticLoadBalancer_Name" {
    description = "Elastic Load Balancer Name"
    default = "" 
}

provider "aws" {
    access_key = "AKIAIQJDPIN2DPPU5PGQ"
    secret_key = "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"
    region     = "${var.aws_region}"
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.KeyPair_Name}"
  public_key = "${var.Public_SSHKey}"
}


resource "aws_elb" "web" {
  name = "${var.ElasticLoadBalancer_Name}"

  # The same availability zone as our instance
  subnets         = ["${var.aws_subnet}"]
  security_groups = ["${var.securitygroup}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/index.html"
    interval            = 5
  }

  # The instance is registered automatically

  instances                   = ["${aws_instance.web.*.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}

resource "aws_lb_cookie_stickiness_policy" "default" {
  name                     = "lbpolicy"
  load_balancer            = "${aws_elb.web.id}"
  lb_port                  = 80
  cookie_expiration_period = 15
}

resource "aws_instance" "web" {
  instance_type     = "${var.instance_type}"
  count             = "${var.instance_count}"
  availability_zone = "${element(var.azs,count.index)}"

  # Lookup the correct AMI based on the region we specified

  ami = "${var.aws_amis}"

  # The name of our SSH keypair you've created and downloaded
  # from the AWS console.
  # https://console.aws.amazon.com/ec2/v2/home?region=us-west-2#KeyPairs:
  key_name = "${aws_key_pair.deployer.key_name}"

  vpc_security_group_ids = ["${var.securitygroup}"]

  user_data =  <<EOF
#!/bin/bash
yum update -y
yum install httpd -y
service httpd start
chkconfig httpd on
myIP=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
echo 'My IP ==>'$myIP
cat << EOFF > /var/www/html/index.html
<html>
<body>
<h1>Welcome to my Web Page</h1>
<hr/>
<p>MY IP:$myIP </p>
<hr/>
</body>
</html>
EOFF
EOF

  tags {
    Name = "instance-elb-${count.index}"
  }
}

output "loadbalancer" {
   value = "http://${aws_elb.web.dns_name}"
}
