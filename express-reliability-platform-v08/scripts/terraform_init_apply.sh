#!/bin/bash
# Initialize and apply Terraform in a given directory
set -e
DIR=${1:-.}
cd "$DIR"
echo "Initializing Terraform in $DIR..."
terraform init
terraform apply -auto-approve
