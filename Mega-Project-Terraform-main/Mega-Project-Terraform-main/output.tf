output "cluster_id" {
  value = aws_eks_cluster.bankapp.id
}

output "node_group_id" {
  value = aws_eks_node_group.bankapp.id
}

output "vpc_id" {
  value = aws_vpc.bankapp_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.bankapp_subnet[*].id
}
