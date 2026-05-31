package kubernetes.admission

# Deny containers running as root
deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not container.securityContext.runAsNonRoot
    msg := sprintf("Container %v must run as non-root user", [container.name])
}

# Deny privileged containers
deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    container.securityContext.privileged
    msg := sprintf("Container %v is privileged, which is not allowed", [container.name])
}

# Require resource limits
deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not container.resources.limits.cpu
    msg := sprintf("Container %v must have CPU limits defined", [container.name])
}

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not container.resources.limits.memory
    msg := sprintf("Container %v must have memory limits defined", [container.name])
}

# Deny containers without readiness probes
deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not container.readinessProbe
    msg := sprintf("Container %v must have a readiness probe", [container.name])
}

# Deny containers without liveness probes
deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not container.livenessProbe
    msg := sprintf("Container %v must have a liveness probe", [container.name])
}

# Require specific image registries (ECR only for production)
deny[msg] {
    input.request.kind.kind == "Pod"
    input.request.namespace == "express-platform"
    container := input.request.object.spec.containers[_]
    not startswith(container.image, "AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com")
    msg := sprintf("Container %v must use approved ECR registry", [container.name])
}

# Deny latest tag in production
deny[msg] {
    input.request.kind.kind == "Pod"
    input.request.namespace == "express-platform"
    container := input.request.object.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf("Container %v cannot use 'latest' tag in production", [container.name])
}

# Require labels
deny[msg] {
    input.request.kind.kind == "Pod"
    not input.request.object.metadata.labels.app
    msg := "Pod must have 'app' label"
}

deny[msg] {
    input.request.kind.kind == "Pod"
    not input.request.object.metadata.labels["app.kubernetes.io/name"]
    msg := "Pod must have 'app.kubernetes.io/name' label"
}

# Deny access to host network
deny[msg] {
    input.request.kind.kind == "Pod"
    input.request.object.spec.hostNetwork
    msg := "Pods cannot use host network"
}

# Deny access to host PID
deny[msg] {
    input.request.kind.kind == "Pod"
    input.request.object.spec.hostPID
    msg := "Pods cannot use host PID namespace"
}

# Require seccomp profile
deny[msg] {
    input.request.kind.kind == "Pod"
    not input.request.object.spec.securityContext.seccompProfile
    msg := "Pod must define a seccomp profile"
}

# Deny capabilities
deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    container.securityContext.capabilities.add[_] != "NET_BIND_SERVICE"
    msg := sprintf("Container %v has disallowed capabilities", [container.name])
}

# Require read-only root filesystem
deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not container.securityContext.readOnlyRootFilesystem
    msg := sprintf("Container %v must have read-only root filesystem", [container.name])
}
