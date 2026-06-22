# Contributing

## Scenario structure

Every scenario lives in its own folder under `scenarios/` and is fully self-contained. It can be deployed, reset, and removed without relying on any root-level configuration:

```
scenarios/my-scenario/
├── README.md               # Scenario description, overview, and script documentation
├── kustomization.yaml      # Standalone Kustomize entry point
├── quickstart.yaml         # ConsoleQuickStart custom resource
└── scripts/
    ├── prepare.sh          # Create prerequisites — may call component scripts
    ├── deploy.sh           # Apply the ConsoleQuickStart to the cluster
    ├── reset.sh            # Remove task-created resources for a clean re-run
    └── cleanup.sh          # Remove everything, including the ConsoleQuickStart
```

A scenario must not depend on another scenario's `prepare.sh` or any shared cluster state.
A scenario **may** call component scripts (see [Component structure](#component-structure) below).

## Environment setup

Before testing on a live cluster, set up the environment layer:

```bash
cp environment/env.sh.example environment/env.sh
# edit environment/env.sh with your cluster details

cp environment/credentials/pull-secret.json.example \
   environment/credentials/pull-secret.json
# fill in real pull secret values

make env-check   # validate before touching the cluster
make env-apply   # push credentials to the cluster
```

**Security rules:**
- Never commit `environment/env.sh` or any file in `environment/credentials/` that does not end in `.example`
- Never add real credentials to `*.example` files
- If you accidentally stage a credential file, remove it with `git reset HEAD <file>` immediately

See [environment/README.md](environment/README.md) for full documentation.

## Component structure

Components are reusable cluster assets shared across multiple scenarios. Each
component lives in its own folder under `components/`:

```
components/my-component/
├── README.md               # What the component installs, what it creates, usage from a scenario
├── kustomization.yaml      # Kustomize entry point (if using manifest files)
├── *.yaml                  # Manifest files (namespace, subscription, etc.)
└── scripts/
    ├── deploy.sh           # Install the component — must be idempotent
    ├── reset.sh            # Remove runtime state; keep the component installed
    ├── update.sh           # Re-apply / upgrade to the latest definition
    └── cleanup.sh          # Remove everything — must use --ignore-not-found
```

A component must not depend on another component's scripts or on a scenario's state.

See [components/README.md](components/README.md) for the full authoring guide and
naming conventions.

## Adding a component

1. Copy the template: `cp -r components/_template components/my-component`
2. Add manifest files and wire them into `kustomization.yaml`
3. Implement the four scripts following the contract in [components/README.md](components/README.md)
4. Fill in `README.md` with the component description, resource table, and usage instructions
5. Validate: `make validate`
6. Test the full lifecycle on a live cluster:

   ```bash
   make component-deploy  COMPONENT=components/my-component
   make component-reset   COMPONENT=components/my-component
   make component-update  COMPONENT=components/my-component
   make component-cleanup COMPONENT=components/my-component
   # Run cleanup a second time to confirm idempotency:
   make component-cleanup COMPONENT=components/my-component
   ```

7. Open a pull request

## Adding a scenario

1. Copy the template: `cp -r scenarios/_template scenarios/my-scenario`
2. Edit `quickstart.yaml` following the [authoring guide](scenarios/README.md)
3. Update `QS_NAME` in `scripts/deploy.sh` to match `metadata.name` in `quickstart.yaml`
4. Fill in `README.md` with the scenario overview and script documentation
5. Implement `scripts/prepare.sh`, `scripts/deploy.sh`, `scripts/reset.sh`, and `scripts/cleanup.sh`
6. Validate the YAML: `make validate`
7. Test end-to-end on a live cluster (see testing requirements below)
8. Open a pull request

## Testing requirements

Every scenario must be tested on a live OpenShift cluster before merging.

**Scripts:**

- `make prepare SCENARIO=scenarios/my-scenario` — completes without errors on a clean cluster
- `make deploy  SCENARIO=scenarios/my-scenario` — applies the resource and verifies it exists
- Walk through every task in the console from start to finish
- `make reset   SCENARIO=scenarios/my-scenario` — returns the cluster to the pre-task state
- Walk through all tasks again to confirm reset worked
- `make cleanup SCENARIO=scenarios/my-scenario` — removes all resources; running it twice must not error

**Quick start content:**

- Confirm "Check your work" prompts and pass/fail messages are accurate
- Confirm the conclusion screen appears after the final task
- If `accessReviewResources` is used, test with a user who lacks the required permissions to confirm the quick start is hidden

**Standalone deployment:**

Verify the scenario deploys without any root-level configuration:

```bash
oc apply -k scenarios/my-scenario/
oc get consolequickstart <name>
```

## Resource name stability

**Never rename `metadata.name` on an existing quick start.**

The name is the cluster-wide identity of the resource. Renaming causes a duplicate because the old resource is not automatically removed. If a rename is unavoidable, explicitly delete the old resource first and document the step clearly in the PR description.

## Pull request expectations

- One scenario or component per PR unless the items are tightly related
- Include a brief description of what the scenario teaches (or what the component installs) and why it is useful
- Note any `metadata.name` changes to existing quick starts (see resource name stability above)
- CI validation must pass before merging

## Style guide

Follow the authoring guide in [scenarios/README.md](scenarios/README.md) and the upstream [OpenShift quick start writing guidelines](https://openshift.github.io/openshift-origin-design/conventions/documentation/quick-starts.html).
