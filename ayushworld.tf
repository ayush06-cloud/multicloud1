provider "aws" {
  profile = "myayush"
  region  = "ap-south-1"
}

resource "aws_security_group" "my_sg" {
  name        = "my-sg"

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

}

resource "aws_instance" "my_rhel8" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  key_name = "mykey"
  security_groups = ["my-sg"]

  connection {
     type     = "ssh"
     user     = "ec2-user"
     private_key = file("C:/Users/Lenovo/mykey.pem")
     host     = aws_instance.my_rhel8.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

}


resource "aws_ebs_volume" "my_ebs1" {
  availability_zone = aws_instance.my_rhel8.availability_zone
  size              = 1

}

resource "aws_volume_attachment" "attach_ebs1" {
  device_name = "/dev/sda2"
  volume_id   = "${aws_ebs_volume.my_ebs1.id}"
  instance_id = "${aws_instance.my_rhel8.id}"
  force_detach = true
depends_on = [
    aws_ebs_volume.my_ebs1,
    aws_instance.my_rhel8
  ]
}

resource "null_resource" "nullremote1"  {

depends_on = [
    aws_volume_attachment.attach_ebs1,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/lenovo/mykey.pem")
    host     = aws_instance.my_rhel8.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/ayush06-cloud/multicloud1.git /var/www/html/"
    ]
  }
}

resource "aws_s3_bucket" "My_terraformbucket" {
  bucket = "myaws-x-terraform-bucket"
  acl    = "public-read"
}

resource "aws_s3_bucket_object" "object1" {
  bucket = "myaws-x-terraform-bucket"
  key    = "terraform-x-aws.png"
  source = "C:/Users/Lenovo/Downloads/terraform-x-aws.png"
  etag = "${filemd5("C:/Users/Lenovo/Downloads/terraform-x-aws.png")}"
  acl = "public-read"
  content_type = "image/png"
  depends_on = [
      aws_s3_bucket.My_terraformbucket
  ]
}

locals {
  s3_origin_id = "S3-${aws_s3_bucket.My_terraformbucket.bucket}"
  image_url = "${aws_cloudfront_distribution.mycloudfront.domain_name}/${aws_s3_bucket_object.object1.key}"
      }


resource "aws_cloudfront_distribution" "mycloudfront" {
  
    origin {
    domain_name = "${aws_s3_bucket.My_terraformbucket.bucket_regional_domain_name}"
    origin_id   = "locals.s3_origin_id"
              
    custom_origin_config {
        http_port = 80
        https_port = 80
        origin_protocol_policy = "match-viewer"
        origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
         }
      }
 

 enabled = true
 is_ipv6_enabled = true


 default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "locals.s3_origin_id"

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

   restrictions {
      geo_restriction {
          restriction_type = "none"
     }
   }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
    
   connection {
      type     = "ssh"
      user     = "ec2-user"
      private_key = file("C:/Users/Lenovo/mykey.pem")
      host     = aws_instance.my_rhel8.public_ip
  
      }
  
   provisioner "remote-exec" {
      inline = [
         "sudo su << EOF",
         "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.object1.key}' width='800' height='500'>\" >> /var/www/html/ayush.html",
          "EOF"
      ]
    }  

}
