# AWS
variable "AWS_REGION" {}

variable "ecr" {
  type = object({
    repositories = list(string)
  })
  description = "ECR repositories to create. List of repository names."
}

# PROJECT
variable "PROJECT_CUSTOMER" {}
variable "PROJECT_ENV" {}
variable "PROJECT_PRENAME" {}

variable "vpc" {
  type = object({
    id = string

    default_security_group = object({
      id = string
    })

    subnets = object({
      public   = list(string)
      private  = list(string)
      database = list(string)
    })

    cidr_blocks = object({
      public   = list(string)
      private  = list(string)
      database = list(string)
    })
  })
}

variable "msk" {
  type = object({
    create = bool
    new = object({
      instance_type          = string
      number_of_broker_nodes = number
      volume_size            = number
      storage_autoscaling = object({
        enabled                     = bool
        min_capacity                = number
        max_volume_size_gb          = number
        target_utilization_percent = number
      })
    })
    existing = object({
      bootstrap_brokers = string
      arn               = optional(string)
    })
  })
}

variable "keyspace" {
  type = object({
    create = bool
    new = object({
      name = string
    })
    existing = object({
      name = string
    })
  })

}
variable "eks" {
  type = object({
    create = bool
    new = object({
      node_groups = list(object({
        instance_type = string
        desired_size  = number
        max_size      = number
        min_size      = number
      }))
    })
    existing = object({
      name              = string
      lb_controller_arn = string
      openid_connect = object({
        issuer = string
        arn    = string
      })
    })
  })
}

variable "ec2" {
  type = object({
    ami = string
    instances = map(object({
      instance_type = string
      subnet_index  = number
      volume_size   = number
      volume_type   = string
      subnet_type   = string
      public        = bool
    }))
  })
}

variable "api_gateway" {
  type = object({
    authenticate_uri = string
    geolocation_uri  = string
  })
}

variable "pod_identity" {
  type = object({
    enabled = bool
  })
}
