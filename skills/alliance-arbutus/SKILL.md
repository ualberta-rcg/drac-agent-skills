---
name: arbutus
description: Reference and gotchas for the Arbutus OpenStack cloud (endpoints on *.arbutus.alliancecan.ca) and the Terraform terraform-provider-openstack work against it. Use when provisioning or operating OpenStack resources on Arbutus (compute/nova, network/neutron, volume/cinder, image/glance, object/swift, share/manila), writing Terraform for this cloud, or working with its p/cb/cm flavors, the rbd1 volume type, application-credential and v3websso SSO auth, the Public-Network, or its per-project quotas.
Arbutus OpenStack
Arbutus is AllianceCan's OpenStack cloud (Horizon:
`https://arbutus.cloud.computecanada.ca`). `atmosphere` is the SSO identity
provider; projects live under the `default` domain (e.g. `def-jbaker`). It is
OpenStack-on-Kubernetes (the internal endpoints are
`*.openstack.svc.cluster.local` service names), v3 identity.
This skill records the cloud's actual shape (services, endpoints, flavors, volumes,
networks, images, quotas) and the non-obvious traps, especially for Terraform. It is
cloud-general — not tied to any single project on it.
Auth & credentials
No password auth — password login returns 401 (the cloud is SSO-gated). Two paths:
v3websso SSO for the interactive CLI, application credentials for automation and
Terraform.
Path A — v3websso SSO (interactive `openstack` CLI)
Download the RC file from Horizon: Project → API Access → Download OpenStack RC File
(the Identity API v3 option). As downloaded it is not usable: it still carries an
interactive password prompt (dead on this cloud) and domain vars that must go.
Add these lines:
`export OS_AUTH_TYPE=v3websso`, `export OS_IDENTITY_PROVIDER=atmosphere`,
`export OS_PROTOCOL=openid`, `export OS_PROJECT_DOMAIN_NAME=default`.
Remove `export OS_USER_DOMAIN_NAME="atmosphere"` (and its
`if [ -z "$OS_USER_DOMAIN_NAME" ]; then unset OS_USER_DOMAIN_NAME; fi` guard) and the
password-prompt block:
    ```
    echo "Please enter your OpenStack Password for project $OS_PROJECT_NAME as user $OS_USERNAME: "
    read -sr OS_PASSWORD_INPUT
    export OS_PASSWORD=$OS_PASSWORD_INPUT
    ```
The corrected file then holds `OS_AUTH_URL=https://identity.arbutus.alliancecan.ca/`,
`OS_PROJECT_ID` / `OS_PROJECT_NAME`, `OS_PROJECT_DOMAIN_ID`, `OS_USERNAME`,
`OS_REGION_NAME=RegionOne`, `OS_INTERFACE=public`, `OS_IDENTITY_API_VERSION=3` plus the
four SSO exports above. No secret in file or env — the first command opens a browser
for the OpenID login.
The CLI must run from a venv with the websso plugin installed:
    ```
    python3 -m venv openstack
    source openstack/bin/activate
    pip install python-openstackclient keystoneauth-websso python-manilaclient
    ```
Without `keystoneauth-websso` the `v3websso` auth type is unknown and every command
fails.
Path B — application credentials (automation, Terraform)
`OS_AUTH_TYPE=application_credential` with `OS_APPLICATION_CREDENTIAL_ID` +
`OS_APPLICATION_CREDENTIAL_SECRET`, sourced from an openrc. Never put the secret in a
repo.
Pre-scoped — never add a scope. Exporting `OS_PROJECT_NAME` /
`OS_USER_DOMAIN_NAME` alongside an app credential fails with
`Application credentials cannot request a scope (HTTP 401)`. The credential already
carries the project scope. (Exception: the Terraform provider and some CLI roles do
take `OS_PROJECT_NAME`/`OS_USER_DOMAIN_NAME`; that is the provider's own auth path,
not the app-credential token.)
Can't list Keystone. `openstack service list` / `openstack endpoint list` →
`403 identity:list_services` / `list_endpoints`. To get the service catalog, POST to
`<auth_url>/v3/auth/tokens` and read `token.catalog` from the response (the
`/v3/catalog` endpoint 404s).
The token is opaque (`gAAAA...`). `OS_AUTH_URL` is
`https://identity.arbutus.alliancecan.ca/` (append `/v3` for the auth API).
Terraform: the v3websso flow is CLI-only — for Terraform it's easier to just use
application credentials; the provider won't auth from a sourced websso RC file.
Service catalog (public endpoints + API version)
Service	Type	Public endpoint
nova	compute	`https://compute.arbutus.alliancecan.ca/v2.1`
neutron	network	`https://network.arbutus.alliancecan.ca` (v2)
glance	image	`https://image.arbutus.alliancecan.ca` (v2)
cinder	volume	`https://volume.arbutus.alliancecan.ca/v3/<project>`
keystone	identity	`https://identity.arbutus.alliancecan.ca/` (v3)
swift	object-store	`https://object-arbutus.alliancecan.ca/swift/v1/<project>`
heat	orchestration	`https://orchestration.arbutus.alliancecan.ca/v1/<project>`
heat-cfn	cloudformation	`https://cloudformation.arbutus.alliancecan.ca/v1`
manila	share	`https://share.arbutus.alliancecan.ca/v2` (v2)
placement	placement	`https://placement.arbutus.alliancecan.ca/`
All public endpoints are HTTPS on the `*.arbutus.alliancecan.ca` namespace (region
`RegionOne`). Compute is nova v2.1 (the OpenStack compute API version, not a K8s thing).
Flavors
Naming is `<family><vcpus>-<ram>gb[-<ephemeral-gb>]`. Three families, all with a 20 GB
root disk and `Is Public: False` (per-tenant, not shared):
`p` (persistent) — the top-of-line, no ephemeral disk, no swap (ephemeral 0,
swap 0). Only the 20 GB root. Sizes: `p1-1.5gb`, `p2-3gb`, `p4-4gb`, `p4-6gb`,
`p4-8gb`, `p8-8gb`, `p8-12gb`, `p8-16gb`, `p16-16gb`, `p16-24gb`, `p16-32gb`
(16 vCPU / 32 GB is the largest). Because there is no ephemeral disk, anything large
(container stores, model/data, etcd) must live on attached Cinder volumes.
`cm` — 20 GB root plus ephemeral disk: `cm1-7.5gb-35` … `cm32-240gb-1120`.
`cb` — 20 GB root plus larger ephemeral: `cb1-3.5gb-35` … `cb96-365gb-3350`.
The `p` family's lack of ephemeral is the defining sizing constraint: a node pulling
multi-GB images will fill the 20 GB root, so relocate the data to a Cinder volume
(`openstack_volume_attach` / block device) rather than relying on disk the flavor provides.
Volume types (Cinder)
Only two, both public:
`rbd1` — the real one (Ceph RBD). This is the one to use for everything.
`__DEFAULT__` — the cinder default (maps to rbd1).
`rbd1` volumes are block storage → ReadWriteOnce (two pods on two nodes can't share
a volume). There is no RWO/MRW class distinction by tier; if you create multiple
StorageClasses they differ only by reclaim policy, not performance. Volume-type quotas
(`volumes_rbd1`, `gigabytes_rbd1`) are `-1` (unlimited) in the sample project.
Availability zones
Three nova AZs: `compute`, `nova`, `persistent` (all `available`). The
`persistent` AZ is the one backing the `p` flavors / rbd1 storage. When scheduling to a
Cinder-backed AZ, the `availability_zone` must match a zone that has a Cinder backend
(`persistent` does; a compute-only zone may not).
Networks
External network: `Public-Network` (the only `--external` network), with three
public subnets (IPv4):
`Public-Network-subnet`: `134.87.8.0/22`
`Public-Network-subnet-2`: `134.87.12.0/24`
`Public-Network-subnet-3`: `206.12.96.0/21`
Floating IPs are allocated from these.
Router quota is 1 per project. You cannot create a second router — reuse the
project's existing external router (attach interfaces to it). Don't write Terraform that
provisions a fresh router; it will hit the quota.
Allowed address pairs with a CIDR work. A port `allowed_address_pairs` entry given as
a CIDR (e.g. `10.x.y.0/26`) with the port's own MAC lets that port use any address in the
range (used to publish secondary/VIP addresses). Verified working.
When reserving a range for LB VIPs, carve it out of the subnet `allocation_pool` so
instances can't consume those addresses.
Glance images (all `active`, x64, 2025-08/2026 releases)
`Ubuntu-22.04/24.04/25.04/26.04-Resolute`, `Debian-12/13`, `Rocky-8/9/10`,
`AlmaLinux-8/9/10`, `Fedora-42/44`, `FortiManager`, and `cirros`. Reference images by name
(`data.openstack_images_image_v2` with `most_recent = true` + `name`) rather than hardcoding
a UUID.
Project quotas (sample `def-jbaker` — confirm against your allocation)
cores 80, instances 20, ram 314572800 (≈300 GB), volumes 20 (rbd1 itself is
`-1`), snapshots 10, networks 10, ports 120, subnets 10, routers 1,
key-pairs 100, injected-files 10. Treat these as the hard ceiling when sizing a build; the
compute ask (cores+ram) is what to confirm before a large provisioning rather than after
boot.
Terraform against Arbutus (terraform-provider-openstack)
Provider is the community fork `terraform-provider-openstack/openstack` (e.g. v2.1.0),
pinned in `.terraform.lock.hcl`. `hashicorp/openstack` is not in this registry and
errors out pointing at the fork. Commit the lock file.
`config_drive = true` is effectively required on `openstack_compute_instance_v2`. The
metadata service (169.254.169.254) is not reliably reachable from project subnets; without
config drive, cloud-init falls back to `DataSourceNone` and applies neither the
`user_data` nor the SSH `key_pair` — the instance comes up with no key and no
provisioning, which is a long, confusing thing to debug.
Do not boot from a volume via `block_device`. It trips Nova's "boot sequence not
valid" on this cloud. Boot the instance from the image, then attach the volume with
`openstack_compute_volume_attach_v2` (a separate resource, ordered after the instance).
Match attached volumes by size in cloud-init, not by device name — attach order is not
guaranteed, so keep per-instance volume sizes distinct and have the cloud-init look them
up by size.
Port resources are `openstack_networking_port_v2` (the networking v2 port), not
`openstack_compute_port_v2`. Query state/plan for the right type when inspecting ports or
their `allowed_address_pairs`.
Do not create a second router (router quota 1, above). Reference the existing external
router (by name/ID) and attach the subnet to it.
State backend: local `terraform.tfstate` (gitignored) is the working setup; a managed
(e.g. GitLab) backend is aspirational — don't add a `backend` block unless asked.
Terraform auth comes from the `OS_*` env: a sourced RC file plus
`OS_AUTH_TYPE=application_credential` with the credential ID/secret (see Auth &
credentials — the v3websso CLI path won't work here). The provider does accept
`OS_PROJECT_NAME`/`OS_USER_DOMAIN_NAME` here even though the raw CLI app-credential
token rejects a scope — don't conflate the two auth paths.
openstack CLI quirks (these fail confusingly)
`openstack port show <p> --column allowed_address_pairs` → OK. `--column security_groups`
→ invalid (use `security_group_ids`).
`openstack port set --allowed-address-pair ...` → not supported by the CLI (do it in
Terraform, or via the Neutron API if you must).
`openstack security group rule list --secgroup <name>` → invalid (group is positional:
`openstack security group rule list <name>`).
`openstack project show <p> --column domain` → invalid (use `domain_id`).
`openstack subnet list --network <name>` → needs the network ID, not the name.
`openstack flavor list` / `image list` work; sort keys like `column:updated_at` are
rejected (use a real column + `--sort-ascending`).
