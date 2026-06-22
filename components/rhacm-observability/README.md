# Component: rhacm-observability

Enables the RHACM **MultiCluster Observability** service, which deploys a
Thanos-based metrics stack on the hub and automatically rolls out a
lightweight collector add-on to every managed cluster.

Object storage is provided by **ODF/NooBaa** via an `ObjectBucketClaim`.

## Architecture

```
Hub cluster
└── open-cluster-management-observability
    ├── ObjectBucketClaim  →  NooBaa bucket  (long-term metrics)
    ├── thanos-object-storage Secret         (built from OBC credentials)
    ├── MultiClusterObservability CR
    │   ├── Thanos Compactor
    │   ├── Thanos Query / Query-Frontend
    │   ├── Thanos Receive
    │   ├── Thanos Ruler
    │   ├── Thanos Store
    │   ├── Alertmanager
    │   └── Grafana
    └── Observability add-on (auto-deployed to each managed cluster)
```

## Prerequisites

| Requirement | Check |
|---|---|
| RHACM `MultiClusterHub` in `Running` state | `oc get multiclusterhub -n open-cluster-management` |
| ODF/NooBaa in `Ready` state | `oc get noobaa noobaa -n openshift-storage` |
| StorageClass `ocs-external-storagecluster-ceph-rbd-immediate` exists | `oc get storageclass` |

## Deployment

```bash
make component-deploy COMPONENT=components/rhacm-observability
# or
bash components/rhacm-observability/scripts/deploy.sh
```

### What deploy.sh does

| Phase | Action |
|---|---|
| 1 | Verify RHACM + NooBaa are ready |
| 2 | Create `open-cluster-management-observability` namespace and OBC |
| 3 | Wait for OBC to become `Bound` |
| 4 | Extract bucket name, endpoint, access key, secret key from OBC |
| 5 | Copy RHACM pull-secret into the observability namespace |
| 6 | Create `thanos-object-storage` Secret from OBC credentials |
| 7 | Apply `MultiClusterObservability` CR |
| 8 | Wait up to 10 min for the stack to become `Ready` |

## Lifecycle scripts

| Script | Action |
|---|---|
| `deploy.sh` | Full install (idempotent) |
| `reset.sh` | Delete MCO CR + thanos secret, re-deploy (bucket data preserved) |
| `update.sh` | Re-apply MCO CR after editing `multiclusterobservability.yaml` |
| `cleanup.sh` | Delete everything including the OBC bucket and all metrics data |

## Directory layout

```
components/rhacm-observability/
├── namespace.yaml                    # open-cluster-management-observability
├── obc.yaml                          # ObjectBucketClaim → NooBaa bucket
├── multiclusterobservability.yaml    # MCO CR (applied by deploy.sh)
├── kustomization.yaml                # namespace + OBC only
├── scripts/
│   ├── deploy.sh
│   ├── reset.sh
│   ├── update.sh
│   └── cleanup.sh
└── README.md
```

## Grafana access

After the stack is Ready, the Grafana URL is available at:

```bash
oc get route grafana -n open-cluster-management-observability \
  -o jsonpath='https://{.spec.host}'
```

Log in with your OpenShift credentials. The default dashboards show
fleet-wide CPU, memory, network, and storage metrics.

## Storage configuration

The `MultiClusterObservability` CR uses two storage tiers:

| Tier | Storage | Purpose |
|---|---|---|
| Block (PVC) | `ocs-external-storagecluster-ceph-rbd-immediate` | Thanos stateful sets (local cache) |
| Object (S3) | ODF/NooBaa OBC | Long-term metrics and downsampled data |

The OBC endpoint is the NooBaa internal S3 service
(`s3.openshift-storage.svc:443`) with TLS and `insecure_skip_verify: true`
for the self-signed NooBaa certificate.

## Customizing the MCO CR

Edit `multiclusterobservability.yaml` and run `update.sh`:

```bash
# Example: set smaller instance size for lab environments
spec:
  instanceSize: minimal

# Example: change retention
spec:
  storageConfig:
    statefulSetSize: 10Gi
```

See the [RHACM observability docs](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.16/html/observability/)
for all available `MultiClusterObservability` spec fields.
