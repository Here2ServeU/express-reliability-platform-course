import boto3
import json

AWS_REGION = 'us-east-1'
CLUSTER_NAME = 'express-reliability-platform-v3-cluster'
SERVICES = ['node-api', 'flask-api', 'web-ui']
ACCOUNT_ID = boto3.client('sts').get_caller_identity()['Account']

ecs = boto3.client('ecs', region_name=AWS_REGION)

# Create ECS cluster
def create_cluster():
    ecs.create_cluster(clusterName=CLUSTER_NAME)
    print(f"ECS cluster created: {CLUSTER_NAME}")

# Register task definitions for each service
def register_task_definitions():
    for service in SERVICES:
        response = ecs.register_task_definition(
            family=service,
            networkMode='awsvpc',
            requiresCompatibilities=['FARGATE'],
            cpu='256',
            memory='512',
            containerDefinitions=[{
                'name': service,
                'image': f'{ACCOUNT_ID}.dkr.ecr.{AWS_REGION}.amazonaws.com/{service}:latest',
                'portMappings': [{
                    'containerPort': 3000 if service == 'node-api' else 5000 if service == 'flask-api' else 80,
                    'protocol': 'tcp'
                }],
                'essential': True
            }],
            executionRoleArn=f'arn:aws:iam::{ACCOUNT_ID}:role/ecsTaskExecutionRole'
        )
        print(f"Task definition registered for: {service}")

if __name__ == "__main__":
    create_cluster()
    register_task_definitions()
