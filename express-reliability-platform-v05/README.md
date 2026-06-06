# Express Reliability Platform V5: Kubernetes Self-Healing on EKS

## Version Purpose

Version 5 moves the platform from ECS to Kubernetes on Amazon EKS. Kubernetes watches the containers,
restarts failed pods, and scales deployments with the Horizontal Pod Autoscaler.

## Goal

Use Terraform to provision an EKS cluster. Deploy the three services as Kubernetes Deployments with
liveness and readiness probes. Configure HPAs. Validate self-healing by deleting a pod and watching
Kubernetes replace it within 30 seconds.

## Project Structure

```text
express-reliability-platform-v05/
├── apps/
│   ├── flask-api/
│   ├── node-api/
│   └── web-ui/
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── flask-api/
│   ├── node-api/
│   ├── web-ui/
│   └── ingress.yaml
├── scripts/
│   ├── build_push_images.sh
│   ├── tf_deploy.sh
│   └── cleanup_v5.sh
└── README.md
```

## Run Steps

Provision the cluster and push images:

```sh
./scripts/tf_deploy.sh
./scripts/build_push_images.sh
```

Apply Kubernetes manifests:

```sh
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/flask-api
kubectl apply -f k8s/node-api
kubectl apply -f k8s/web-ui
kubectl apply -f k8s/ingress.yaml
```

Test self-healing:

```sh
kubectl get pods -n reliability
kubectl delete pod -n reliability -l app=flask-api
kubectl get pods -n reliability -w
```

## Validation Checklist

- [ ] EKS nodes are Ready.
- [ ] All service pods are Running.
- [ ] Liveness and readiness probes are configured.
- [ ] Deleted pods are replaced automatically.
- [ ] HPAs exist and can scale under load.
- [ ] The ALB ingress routes traffic to the web UI.
