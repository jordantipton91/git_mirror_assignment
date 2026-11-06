# Git Mirror on Kubernetes

A Git mirror that runs inside a local Kubernetes cluster and keeps a copy of an external repository.

## Why

Every CI build downloads a 5GB monorepo from an external host. That is slow. A mirror in the same network as the build servers lets builds clone from a nearby copy instead. Only the mirror talks to the external host, and it only fetches what changed.

## How it works

Terraform does the whole setup in one run:

1. Creates a local Kubernetes cluster with kind.
2. Builds the mirror image from `docker/` and loads it into the cluster.
3. Installs the Helm chart from `charts/git-mirror`.

The chart runs one pod with three containers that share a persistent volume:

| Container | Job |
| --- | --- |
| `clone` | Runs once at start. Makes a full mirror clone of the source repo if the volume is empty, then packs it with a bitmap index. |
| `sync` | Runs `git fetch --prune` every 30 seconds so new commits, branches, tags and deletions are copied. |
| `daemon` | Serves the mirror over the `git://` protocol on port 9418. Builds clone from here. |

A private source repo needs a read only token. Terraform passes it to Helm, which stores it in a Kubernetes Secret. Git reads it through a small askpass script, so the token never appears in the clone URL or the mirror's Git config.

The Service is a NodePort, and kind maps it to `localhost:9418` on your machine.

## Large repo tuning

A 5GB repo cloned by many builds at once needs a few things beyond a plain mirror:

* After the first clone, `git gc` writes a bitmap index and a commit graph. With a bitmap, the server can work out what to send for a full clone quickly instead of walking every object each time.
* Every `git fetch` also runs Git's auto maintenance, so new packs from later fetches get merged back in over time.
* `git daemon` serves 32 clones at once by default. The chart raises this to 64 with `maxConnections`.
* The disk is 20Gi so it fits the repo, the temporary copy made during the first clone, and growth.
* The `sync` container, which also runs the first clone and packing, can use up to 4Gi of memory. The `daemon` container can use up to 2Gi.

These numbers are starting points. Real values should come from load testing with the real repo and build traffic.

## Requirements

Tested on Ubuntu 24.04 in WSL2 with these versions:

| Tool | Version |
| --- | --- |
| Docker | 29.1 |
| kind | 0.29 |
| Terraform | 1.12 |
| kubectl | 1.33 |
| Git | 2.43 |

Install guides:

* Docker: https://docs.docker.com/engine/install/
* kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
* Terraform: https://developer.hashicorp.com/terraform/install
* kubectl: https://kubernetes.io/docs/tasks/tools/

Helm itself does not need to be installed. Terraform uses its own Helm provider.

This repo is private, so ask the owner for access before you start.

## Setup

1. Clone this repo and go to the `terraform` folder.

   ```
   git clone https://github.com/jordantipton91/git_mirror_assignment.git
   cd git_mirror_assignment/terraform
   ```

2. Create your settings file from the example.

   ```
   cp terraform.tfvars.example terraform.tfvars
   ```

   Set `source_repo_url` to the repo you want to mirror. For a private repo, set `source_repo_token` to a GitHub fine grained token with Contents: Read only on that repo. For a public repo, remove the token line. Git ignores this file, so the token is never committed.

3. Deploy.

   ```
   terraform init
   terraform apply
   ```

   This takes about two minutes. When it finishes it prints the clone URLs.

4. Check that the pod is running.

   ```
   export KUBECONFIG=$(terraform output -raw kubeconfig)
   kubectl -n git-mirror get pods
   ```

   The pod should show `2/2 Running`.

## Using the mirror

From your machine:

```
git clone git://localhost:9418/repo.git
```

From a pod inside the cluster, such as a build agent:

```
git clone git://git-mirror.git-mirror.svc.cluster.local:9418/repo.git
```

The mirror is read only. Builds clone from it and push to the external repo as usual.

## Seeing the mirroring work

1. Note the latest commit in the mirror.

   ```
   git ls-remote git://localhost:9418/repo.git HEAD
   ```

2. Push a new commit to the external repo.

3. Wait up to 30 seconds and run the same command again. It now shows the new commit.

New branches, tags, deleted branches and tags, and force pushes are mirrored the same way. To compare everything at once:

```
git ls-remote https://github.com/jordantipton91/git_mirror_assignment.git
git ls-remote git://localhost:9418/repo.git
```

Both lists should match.

You can also watch each sync in the logs:

```
kubectl -n git-mirror logs deploy/git-mirror -c sync -f
```

Each line shows the time and the commit the mirror is on, for example `2026-11-06T23:06:16Z synced bc2ab60`.

## Settings

These can be set in `terraform.tfvars`.

| Variable | Default | Meaning |
| --- | --- | --- |
| `source_repo_url` | none | HTTPS URL of the repo to mirror |
| `source_repo_token` | empty | Read only token for a private repo |
| `sync_interval_seconds` | 30 | Time between fetches |
| `host_port` | 9418 | Port on your machine that reaches the mirror |
| `cluster_name` | git-mirror | Name of the kind cluster |
| `namespace` | git-mirror | Namespace for the mirror |
| `node_image` | kindest/node:v1.33.1 | kind node image, which sets the Kubernetes version |
| `image_name` | git-mirror | Name of the mirror image |
| `image_tag` | 0.1.0 | Tag of the mirror image. Change it when the Dockerfile changes |

Chart settings such as disk size, memory and `maxConnections` are in `charts/git-mirror/values.yaml`.

## Health checks

* The `daemon` container is ready only once the mirror exists, so no build gets an empty repo.
* The `sync` container writes a timestamp after each good fetch. If there is no good fetch for 10 minutes, its liveness check starts failing, and after 3 failed checks one minute apart Kubernetes restarts it. This catches a fetch that hangs forever. If GitHub itself is down, the restart does not help, but the `daemon` keeps serving the last good copy, so builds keep working.
* The first clone is retried up to 5 times if the network drops.

## Troubleshooting

* Pod stuck in `Init`: run `kubectl -n git-mirror logs deploy/git-mirror -c clone`. An auth error means the token is wrong, expired, or has no access to the repo.
* `sync failed` in the sync logs: same checks as above, then check the network from the cluster.
* `terraform apply` fails on the port: something else uses port 9418 on your machine. Set `host_port` to another port.

## Clean up

```
terraform destroy
```

This deletes the cluster and everything in it.

## Limits and next steps

This setup is built to run on one machine. Before using it for the real CI fleet, I would change these:

* One pod. There is one replica on a ReadWriteOnce disk, so a restart or node loss stops clones for a short time. Next step: a StatefulSet with two or three replicas, each with its own disk and its own sync loop, behind the same Service.
* No auth on `git://`. Any pod in the cluster can clone the mirror, even though the source repo is private. Next step: a NetworkPolicy that only lets build agents in, or serve Git over HTTPS with auth.
* Polling. A change can take up to 30 seconds to show up. Next step: a GitHub webhook that triggers a fetch right away, with polling kept as a backup.
* Local Terraform state. The state file sits on one machine, has no locking, and holds the token in plain text. Next step: a remote backend with locking, such as S3 with `use_lockfile`, and the token read from a secret manager.
* Image loaded into kind. The image is built and loaded by Terraform, which only works with kind. Next step: build it in CI and push it to a registry with a version tag per change.
* GitHub pull request refs. A mirror clone of a GitHub repo also copies every `refs/pull/*` ref. On a busy repo that adds a lot of refs. Next step: fetch only branches and tags if builds do not need them.

## Project layout

```
docker/Dockerfile        mirror image with git and git daemon
charts/git-mirror/       Helm chart for the mirror
terraform/               cluster, image load and Helm release
```
