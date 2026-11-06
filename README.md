# Git Mirror on Kubernetes

A Git mirror that runs inside a local Kubernetes cluster and keeps a copy of an external repository.

## Why

Every CI build downloads a 5GB monorepo from an external host. That is slow. A mirror in the same network as the build servers lets builds clone from a nearby copy instead.

Setup steps will be added as the project grows.
