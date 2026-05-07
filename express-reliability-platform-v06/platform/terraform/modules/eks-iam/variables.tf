variable "name_prefix" {
  type        = string
  description = "Prefix for IAM role names. IAM roles are global per account, so include env (e.g. reliability-v06-dev) to allow dev and prod to coexist."
}
