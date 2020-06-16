provider "aws" {
  region = "ap-south-1"
  profile = "jubincc"
}


resource "aws_security_group" "jubinsecuritygroup" {
  name        = "jubinsecuritygroup"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jubinsecuritygroup"
  }
}

resource "tls_private_key" "myprivatekey" 
{   
 algorithm   = "RSA" 
}    

resource "aws_key_pair" "mykey" {  
 key_name   = "Jubinkey"   
 public_key = tls_private_key.myprivatekey.public_key_openssh 
}

resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name   = "Jubinkey"
  security_groups = [ "jubinsecuritygroup" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key ="${tls_private_key.myprivatekey.private_key_pem}"
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "jubincctask1_os1"
  }

}



resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "jubincctask1_ebs1"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}


output "myos_ip" {
  value = aws_instance.web.public_ip
}



resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/pc/Downloads/Jubinkeytask1.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Jubin-Sharma/multicloud.git /var/www/html/"
    ]
  }
}



resource "null_resource" "gitdownload" {
 

  /*provisioner "local-exec" {
    command = "del -y C:/Users/pc/Desktop/tera/local/GithubDownloads/*"
  }*/

  provisioner "local-exec" {
    command = "git clone https://github.com/Jubin-Sharma/multicloud.git C:/Users/pc/Desktop/tera/local/GithubDownloads"
  }


}


resource "aws_s3_bucket" "mys3bucket" {
  bucket = "jubinbucket"
  acl    = "public-read"

  tags = {
    Name = "Jubin task bucket"
  }
}

resource "aws_s3_bucket_object" "gitupload" {

depends_on = [
    null_resource.gitdownload,
  ]
  
  bucket = "${aws_s3_bucket.mys3bucket.bucket}"
  key    = "images.jpg"
  acl    = "public-read"
  source = "C:/Users/pc/Desktop/tera/local/GithubDownloads/modi.jpg"
 
}

locals {
  s3_origin_id = "S3-${aws_s3_bucket.mys3bucket.bucket}"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.mys3bucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

  }

  enabled             = true
 
 restrictions {
    geo_restriction {
      restriction_type = "none"
      
    }
  }  

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
 
 
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

 viewer_certificate {
    cloudfront_default_certificate = true
  }



}

resource "null_resource" "nu"{

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/pc/Downloads/Jubinkeytask1.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
    "sudo su << EOF",
    "echo \"<img src = 'http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.gitupload.key}'>\"  >>  /var/www/html/index.php",
    "EOF"    

]
  }

}


resource "null_resource" "nulllocal1"  {

depends_on = [
    null_resource.nullremote3,
  ]

	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.web.public_ip}"
  	}
}


