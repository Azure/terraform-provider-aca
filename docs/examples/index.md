---
title: Examples
description: "15 deployment-tested examples covering beginner to advanced ACA patterns"
breadcrumbs:
  - title: Home
    url: /
  - title: Examples
    url: /examples/
prev_page:
  title: Migration Guide
  url: /migration
---

<p class="lead">
All 16 examples have been deployed and validated on Azure. Each example is self-contained
with its own <code>main.tf</code>, <code>variables.tf</code>, <code>outputs.tf</code>, and <code>README.md</code>.
</p>

## Quick Deploy

```bash
cd examples/<example_name>
terraform init
terraform plan -var="subscription_id=YOUR_SUB_ID" -out=tfplan
terraform apply tfplan
```

## Beginner

<div class="example-grid">
  <a href="{{ '/examples/simple-app' | relative_url }}" class="example-card">
    <div class="example-name">Simple App</div>
    <div class="example-complexity">⭐ Beginner · 6 resources</div>
    <div class="example-desc">Minimal single container app with VNet, NSG, and external ingress. The "hello world" of ACA.</div>
  </a>
</div>

## Intermediate

<div class="example-grid">
  <a href="{{ '/examples/enterprise-app' | relative_url }}" class="example-card">
    <div class="example-name">Enterprise App</div>
    <div class="example-complexity">⭐⭐ Intermediate · 7 resources</div>
    <div class="example-desc">Production-grade app with mTLS, workload profiles (D4), App Insights, and managed identity.</div>
  </a>
  <a href="{{ '/examples/jobs' | relative_url }}" class="example-card">
    <div class="example-name">Jobs</div>
    <div class="example-complexity">⭐⭐ Intermediate · 4 resources</div>
    <div class="example-desc">CRON scheduled cleanup job and event-driven Azure Queue processor with retry policies.</div>
  </a>
  <a href="{{ '/examples/sticky-sessions' | relative_url }}" class="example-card">
    <div class="example-name">Sticky Sessions</div>
    <div class="example-complexity">⭐⭐ Intermediate · 5 resources</div>
    <div class="example-desc">Session affinity via AzAPI feature flags — the canonical AzAPI overlay pattern.</div>
  </a>
  <a href="{{ '/examples/custom-domains' | relative_url }}" class="example-card">
    <div class="example-name">Custom Domains</div>
    <div class="example-complexity">⭐⭐ Intermediate · 5 resources</div>
    <div class="example-desc">Conditional custom domain binding with managed certificates and App Insights.</div>
  </a>
  <a href="{{ '/examples/autoscaling' | relative_url }}" class="example-card">
    <div class="example-name">Autoscaling</div>
    <div class="example-complexity">⭐⭐ Intermediate · 5 resources</div>
    <div class="example-desc">HTTP and KEDA scale rules configured via AzAPI overlay for fine-grained autoscaling.</div>
  </a>
  <a href="{{ '/examples/blue-green' | relative_url }}" class="example-card">
    <div class="example-name">Blue/Green Deploy</div>
    <div class="example-complexity">⭐⭐ Intermediate · 5 resources</div>
    <div class="example-desc">Multi-revision mode with traffic splitting for zero-downtime blue/green deployments.</div>
  </a>
  <a href="{{ '/examples/cors-api' | relative_url }}" class="example-card">
    <div class="example-name">CORS API</div>
    <div class="example-complexity">⭐⭐ Intermediate · 6 resources</div>
    <div class="example-desc">Frontend + API architecture with Cross-Origin Resource Sharing policy via AzAPI overlay.</div>
  </a>
  <a href="{{ '/examples/init-containers' | relative_url }}" class="example-card">
    <div class="example-name">Init Containers</div>
    <div class="example-complexity">⭐⭐ Intermediate · 4 resources</div>
    <div class="example-desc">Init container pattern with shared EmptyDir volumes for pre-processing tasks.</div>
  </a>
</div>

## Advanced

<div class="example-grid">
  <a href="{{ '/examples/microservices' | relative_url }}" class="example-card">
    <div class="example-name">Microservices</div>
    <div class="example-complexity">⭐⭐⭐ Advanced · 7 resources</div>
    <div class="example-desc">Three-app Dapr service mesh with frontend, backend API, and worker — distributed tracing included.</div>
  </a>
  <a href="{{ '/examples/sessions' | relative_url }}" class="example-card">
    <div class="example-name">Dynamic Sessions</div>
    <div class="example-complexity">⭐⭐⭐ Advanced · 5 resources</div>
    <div class="example-desc">Dynamic session pools (PythonLTS) via AzAPI — full two-phase deploy pattern.</div>
  </a>
  <a href="{{ '/examples/storage' | relative_url }}" class="example-card">
    <div class="example-name">Storage Volumes</div>
    <div class="example-complexity">⭐⭐⭐ Advanced · 7 resources</div>
    <div class="example-desc">Azure Files SMB mounts (read-write + read-only) with sub-module composition and ordering.</div>
  </a>
  <a href="{{ '/examples/private-endpoint' | relative_url }}" class="example-card">
    <div class="example-name">Private Endpoint</div>
    <div class="example-complexity">⭐⭐⭐ Advanced · 10 resources</div>
    <div class="example-desc">VNet + internal load balancer + workload profiles + private endpoint + private DNS zone.</div>
  </a>
  <a href="{{ '/examples/additional-ports' | relative_url }}" class="example-card">
    <div class="example-name">Additional Ports</div>
    <div class="example-complexity">⭐⭐⭐ Advanced · 8 resources</div>
    <div class="example-desc">gRPC/TCP port mapping via AzAPI advanced ingress — requires VNet integration.</div>
  </a>
  <a href="{{ '/examples/java-spring' | relative_url }}" class="example-card">
    <div class="example-name">Java Spring</div>
    <div class="example-complexity">⭐⭐⭐ Advanced · 7 resources</div>
    <div class="example-desc">Spring Cloud Eureka + Config Server via AzAPI Java components with service bindings.</div>
  </a>
</div>
