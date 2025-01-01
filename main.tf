module "security_group" {
  source        = "app.terraform.io/ptonini-org/security-group/aws"
  version       = "~> 1.0.0"
  count         = length(var.security_group[*])
  name          = coalesce(var.security_group.name, "ec2-instance-${var.name}")
  vpc_id        = var.security_group.vpc_id
  ingress_rules = var.security_group.ingress_rules
  egress_rules  = var.security_group.egress_rules
}

module "role" {
  source  = "app.terraform.io/ptonini-org/iam-role/aws"
  version = "~> 1.0.0"
  count   = length(var.instance_role[*])
  name    = "ec2-instance-${var.name}"
  assume_role_policy_statement = concat(
    [{ effect = "Allow", principals = [{ type = "Service", identifiers = ["ec2.amazonaws.com"] }], actions = ["sts:AssumeRole"] }],
    var.instance_role.assume_role_policy_statement
  )
  policy_arns = var.instance_role.policy_arns
}

resource "aws_iam_instance_profile" "this" {
  count = length(var.instance_role[*])
  role  = module.role[0].this.name

  lifecycle {
    ignore_changes = [
      tags["business_unit"],
      tags["product"],
      tags["env"],
      tags_all
    ]
  }
}

data "cloudinit_config" "this" {
  count         = length(var.cloudinit_config[*])
  gzip          = var.cloudinit_config.gzip
  base64_encode = var.cloudinit_config.base64_encode

  dynamic "part" {
    for_each = var.cloudinit_config.parts
    content {
      filename     = coalesce(part.value.filename, part.key)
      content      = part.value.content
      content_type = part.value.content_type
    }
  }
}

resource "aws_instance" "this" {
  count                  = var.host_count
  ami                    = var.ami
  ebs_optimized          = var.ebs_optimized
  instance_type          = var.type
  monitoring             = var.monitoring
  key_name               = var.key_name
  subnet_id              = element(var.subnet_ids, (length(var.subnet_ids) + count.index) % length(var.subnet_ids))
  iam_instance_profile   = one(aws_iam_instance_profile.this[*].id)
  vpc_security_group_ids = concat(module.security_group[*].this.id, var.vpc_security_group_ids)
  source_dest_check      = var.source_dest_check
  user_data_base64       = one(data.cloudinit_config.this[*].rendered)

  root_block_device {
    volume_type           = var.root_volume.volume_type
    volume_size           = var.root_volume.volume_size
    delete_on_termination = var.root_volume.delete_on_termination
  }

  tags = merge({ Name = "${var.name}${format("%04.0f", count.index + 1)}" }, var.tags)

  lifecycle {
    ignore_changes = [
      root_block_device[0].tags,
      tags["business_unit"],
      tags["product"],
      tags["env"],
      tags_all,
    ]
  }
}

resource "aws_eip" "this" {
  count    = var.fixed_public_ip ? var.host_count : 0
  instance = aws_instance.this[count.index].id
  tags     = { Name = "ec2-instance-${var.name}${format("%04.0f", count.index + 1)}" }
  lifecycle {
    ignore_changes = [
      tags["business_unit"],
      tags["product"],
      tags["env"],
      tags_all,
    ]
  }
}



locals {
  volumes = { for vol in flatten([
    for i in range(var.host_count) : [
      for k, v in var.volumes : {
        key         = "${k}-${i}"
        name        = "ec2-instance-${var.name}${format("%04.0f", i + 1)}-${k}"
        host_index  = i
        device_name = v.device_name
        size        = v.size
        tags        = v.tags
      }
    ]
  ]) : vol.key => vol }
}

resource "aws_ebs_volume" "this" {
  for_each          = local.volumes
  availability_zone = aws_instance.this[each.value["host_index"]].availability_zone
  size              = each.value["size"]
  tags              = merge({ Name = each.value["name"] }, each.value["tags"])
  lifecycle {
    ignore_changes = [
      tags["business_unit"],
      tags["product"],
      tags["env"],
      tags_all,
    ]
  }
}

resource "aws_volume_attachment" "this" {
  for_each    = local.volumes
  device_name = each.value["device_name"]
  volume_id   = aws_ebs_volume.this[each.key].id
  instance_id = aws_instance.this[each.value["host_index"]].id
}