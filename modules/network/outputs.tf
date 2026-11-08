output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Map of public subnet IDs."
  value = {
    for key, subnet in aws_subnet.public :
    key => subnet.id
  }
}

output "private_subnet_ids" {
  description = "Map of private subnet IDs."
  value = {
    for key, subnet in aws_subnet.private :
    key => subnet.id
  }
}

output "internet_gateway_id" {
  description = "Internet Gateway ID."
  value       = aws_internet_gateway.this.id
}

output "public_route_table_id" {
  description = "Public route table ID."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private route table ID."
  value       = aws_route_table.private.id
}