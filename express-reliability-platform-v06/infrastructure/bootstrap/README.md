# Bootstrap Remote State (S3 + DynamoDB)

## Usage

1. Edit `variables.tf` to set your bucket and table names.
2. Initialize and apply:
   ```sh
   terraform init
   terraform apply -auto-approve
   ```
3. Use the outputs to configure remote state in all other environments.

## Best Practices
- Use unique bucket/table names per environment (e.g., fintech, hospital)
- Enable versioning and encryption (already set)
- Prevent destroy to protect state
- Use separate AWS accounts for regulated environments
