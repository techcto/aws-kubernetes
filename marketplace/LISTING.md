# Kubernetes-UI: Web Dashboard for Kubernetes Clusters

## Short description

An open-source web dashboard for managing Kubernetes workloads and clusters,
with OIDC/Keycloak single sign-on, role-based access, and container-image or
Helm-chart deployment on Amazon EKS.

## Overview

Kubernetes-UI helps teams view and manage applications, troubleshoot workloads,
and administer Kubernetes resources through a browser. It continues the
Apache-licensed Kubernetes Dashboard codebase, preserving the original authors'
attribution while adding maintained release packaging and AWS integration.

The upstream Kubernetes Dashboard project was archived after its maintainers
reported a lack of active maintainers and contributors. The SpaceMade and
Solodev team is continuing development as Kubernetes-UI, with plans for ongoing
maintenance, security and dependency updates, and improvements for teams running
Kubernetes. Community contributions are welcome.

Deploy through either the container-image delivery option or the Helm chart
for Amazon EKS. CloudFormation Quick Starts support installing into an existing
EKS cluster or creating a new EKS environment. Subscribe through AWS Marketplace
and accept the terms before launching either deployment path. AWS infrastructure
charges are separate from the Marketplace software subscription.

## Highlights

- Manage workloads, services, configuration, storage, and cluster resources from
  a web interface.
- Connect OIDC/Keycloak authentication and Kubernetes role-based access for
  organization-managed access.
- Choose container images or a versioned Helm chart, with CloudFormation
  deployment instructions for existing and new Amazon EKS clusters.

## Links

- Product: <https://aws.amazon.com/marketplace/pp/prodview-7uaseskhg4mla>
- Quick Start and usage instructions: <https://github.com/techcto/aws-kubernetes/blob/master/marketplace/QUICKSTART.md>
- Application source: <https://github.com/techcto/kubernetes-ui>
- AWS deployment source and issues: <https://github.com/techcto/aws-kubernetes>
- Upstream archive notice: <https://github.com/kubernetes-retired/dashboard>
