variable "name" {}

variable "host_count" {
  default  = 1
  nullable = false
}

variable "ami" {}

variable "type" {}

variable "key_name" {}

variable "subnet_ids" {
  type = list(string)
}

variable "root_volume" {
  type = object({
    volume_type           = optional(string, "gp2")
    volume_size           = optional(number, 20)
    delete_on_termination = optional(bool, true)
  })
  default  = {}
  nullable = false
}

variable "source_dest_check" {
  default  = true
  nullable = false
}

variable "ebs_optimized" {
  default  = true
  nullable = false
}

variable "monitoring" {
  default  = false
  nullable = false
}

variable "instance_role" {
  type = object({
    assume_role_policy_statement = optional(list(any), [])
    policy_arns                  = optional(set(string))
  })
  default = null
}

variable "fixed_public_ip" {
  default  = false
  nullable = false
}

variable "volumes" {
  type = map(object({
    size        = number
    device_name = string
    tags        = optional(map(string), {})
  }))
  default  = {}
  nullable = false
}

variable "cloudinit_config" {
  type = object({
    gzip          = optional(bool)
    base64_encode = optional(bool, true)
    parts = map(object({
      filename     = optional(string)
      content      = string
      content_type = optional(string)
    }))
  })
  default = null
}

variable "security_group" {
  type = object({
    name = optional(string)
    vpc_id = string
    ingress_rules = optional(map(object({
      from_port                    = optional(number)
      to_port                      = optional(number)
      ip_protocol                  = optional(string, "tcp")
      cidr_ipv4                    = optional(string)
      cidr_ipv6                    = optional(string)
      prefix_list_id               = optional(string)
      referenced_security_group_id = optional(string)
    })), { self = { ip_protocol = -1, referenced_security_group_id = "self" } })
    egress_rules = optional(map(object({
      from_port                    = optional(number)
      to_port                      = optional(number)
      ip_protocol                  = optional(string, "tcp")
      cidr_ipv4                    = optional(string)
      cidr_ipv6                    = optional(string)
      prefix_list_id               = optional(string)
      referenced_security_group_id = optional(string)
    })), { all = { ip_protocol = -1, cidr_ipv4 = "0.0.0.0/0" } })
  })
  default = null
}

variable "vpc_security_group_ids" {
  type     = list(string)
  default  = []
  nullable = false
}

variable "tags" {
  default  = {}
  nullable = false
}

