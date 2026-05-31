package kubernetes.admission

test_deny_root_containers {
    input := {
        "request": {
            "kind": {"kind": "Pod"},
            "object": {
                "metadata": {"name": "test-pod"},
                "spec": {
                    "containers": [{
                        "name": "test-container",
                        "image": "nginx:latest"
                    }]
                }
            }
        }
    }
    
    count(deny) > 0
}

test_allow_nonroot_containers {
    input := {
        "request": {
            "kind": {"kind": "Pod"},
            "object": {
                "metadata": {
                    "name": "test-pod",
                    "labels": {
                        "app": "test",
                        "app.kubernetes.io/name": "test"
                    }
                },
                "spec": {
                    "securityContext": {
                        "seccompProfile": {"type": "RuntimeDefault"}
                    },
                    "containers": [{
                        "name": "test-container",
                        "image": "123456789.dkr.ecr.us-east-1.amazonaws.com/test:v1.0.0",
                        "securityContext": {
                            "runAsNonRoot": true,
                            "readOnlyRootFilesystem": true,
                            "capabilities": {"drop": ["ALL"]}
                        },
                        "resources": {
                            "limits": {"cpu": "100m", "memory": "128Mi"}
                        },
                        "readinessProbe": {"httpGet": {"path": "/ready", "port": 8080}},
                        "livenessProbe": {"httpGet": {"path": "/health", "port": 8080}}
                    }]
                }
            },
            "namespace": "express-platform"
        }
    }
    
    count(deny) == 0
}
