
# -----------------------------------------
# EKS Cluster IAM Role
# -----------------------------------------

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -----------------------------------------
# EKS Managed Node IAM Role
# -----------------------------------------

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name = "${var.project_name}-${var.environment}-eks-node-role"

  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEC2ContainerRegistryPullOnly",
    "AmazonEKS_CNI_Policy"
  ])

  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}

# -----------------------------------------
# EKS Cluster
# -----------------------------------------

resource "aws_eks_cluster" "this" {
  name     = "${var.project_name}-${var.environment}-eks"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = var.private_subnet_ids

    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidrs
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks"
    Environment = var.environment
  }
}


# -----------------------------------------
# EKS Admin Access Entry
# -----------------------------------------

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_principal_arn

  type = "STANDARD"
}

# -----------------------------------------
# EKS Admin Access Policy Association
# -----------------------------------------

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admin.principal_arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}


# -----------------------------------------
# EKS Managed Node Group
# -----------------------------------------

resource "aws_eks_node_group" "this" {
  cluster_name = aws_eks_cluster.this.name

  node_group_name = "${var.project_name}-${var.environment}-nodes"

  node_role_arn = aws_iam_role.node.arn

  subnet_ids = var.private_subnet_ids

  instance_types = var.node_instance_types

  ami_type      = "AL2023_x86_64_STANDARD"
  capacity_type = "ON_DEMAND"
  disk_size     = 20

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-nodes"
    Environment = var.environment
  }
}
