# Cloudflare DNS records for lab-hcp

All records are DNS-only A records in the `lost-aurora.de` zone.

`api.hcp.lost-aurora.de` and `konnectivity.apps.hcp.lost-aurora.de` are managed by ExternalDNS in the management cluster. The ExternalDNS instance is limited to the `clusters-lab-hcp-lab-hcp` namespace and these two exact names; it uses `registry=noop` to adopt the existing Cloudflare A records without TXT ownership records. OAuth, Ignition, and guest apps records are intentionally kept static for now.

| Name | Address | Purpose |
| --- | --- | --- |
| `api.hcp.lost-aurora.de` | ExternalDNS-managed LoadBalancer IP | Hosted cluster Kubernetes API |
| `oauth-openshift.apps.hcp.lost-aurora.de` | `172.16.3.3` | Hosted cluster OAuth through the management router |
| `ignition.apps.hcp.lost-aurora.de` | `172.16.3.4` | Hosted cluster Ignition through the management router |
| `konnectivity.apps.hcp.lost-aurora.de` | ExternalDNS-managed LoadBalancer IP | Hosted cluster Konnectivity |
| `*.apps.hcp.lost-aurora.de` | `172.16.3.6` | Public guest apps and console through the `vlan12` guest ingress controller |
| `console-openshift-console.apps.hcp.lost-aurora.de` | `172.16.3.6` | Explicit console record, kept alongside the wildcard |
| `*.apps.lab-hcp.hcp.lost-aurora.de` | `172.16.3.7` | HCP-created default ingress controller health and canary routes |

## OPNsense private-domain exceptions

These are not Cloudflare HCP records. They are local Unbound private-domain exceptions on OPNsense so DNS rebind protection does not strip private A-record answers for VLAN12 clients:

| Domain | Purpose |
| --- | --- |
| `hcp.lost-aurora.de` | HCP private VIP records such as `api.hcp.lost-aurora.de` and app wildcard records |
| `shift.lost-aurora.de` | Management/hub OpenShift API name `api.shift.lost-aurora.de`, which resolves through Cloudflare to `172.16.1.197` |

The `api.shift.lost-aurora.de` record itself remains a normal Cloudflare A record. OPNsense does not override the host; it only allows this domain to return private addresses to VLAN12 clients.
