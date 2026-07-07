# HCP lab-hcp with MetalLB-only VLAN12 access

This folder is the current rebuild and operating plan for `lab-hcp`. The hosted cluster worker, hosted API, guest ingress, and related control-plane entry points live on VLAN12 behind OPNsense.

It intentionally does not use the previous management-node `socat`/`nft` VIP proxy and does not add guest-node hairpin DNAT rules.

## Current lab state

| Area | Current value |
| --- | --- |
| OPNsense WAN | `igb2`, UniFi 48-port switch port 21, `172.16.1.181/24`, VIP `172.16.1.183/32` |
| OPNsense HCP LAN | `igb0.12` / `igb0_vlan12`, UniFi 48-port switch port 19, `172.16.3.1/24` |
| OPNsense spare port | `igb1`, UniFi 48-port switch port 23, disabled/no IP |
| HCP VLAN | VLAN ID `12`, network `172.16.3.0/24`, gateway/DNS `172.16.3.1` |
| Default network | `172.16.1.0/24`; must stay available independently of the HCP lab |
| Management cluster kubeconfig | `/Users/Michael.Silich/git/hcp/kubeconfig-noingress-letsencrypt` |
| Hosted cluster kubeconfig | Extract from `clusters-lab-hcp/lab-hcp-admin-kubeconfig` |
| Hosted worker | `lab-hcp` node pool replica 1, static guest IP `172.16.3.20` |

OPNsense is the gateway, DHCP/DNS point, and firewall boundary for VLAN12. HCP traffic from `172.16.3.0/24` to the normal/default network is blocked by default and logged, with only explicit exceptions listed below.

## OPNsense DNS and firewall

DNS for VLAN12 is intentionally resolved through OPNsense at `172.16.3.1`.

Unbound private-domain configuration on OPNsense:

| Domain | Reason |
| --- | --- |
| `hcp.lost-aurora.de` | Allow private HCP VIP answers such as `172.16.3.2-172.16.3.7` without DNS rebind filtering. |
| `shift.lost-aurora.de` | Allow the Cloudflare answer `api.shift.lost-aurora.de -> 172.16.1.197` for ACM/HCP agents that use the management/hub API from their hub kubeconfig. |

There should be no per-host Unbound override for `api.shift.lost-aurora.de`; the name is resolved from Cloudflare, and OPNsense only marks the domain as allowed to return private addresses.

Logged firewall policy on `igb0_vlan12`:

| Source | Destination | Port | Action | Reason |
| --- | --- | --- | --- | --- |
| `172.16.3.0/24` | `172.16.1.140` | TCP `443` | allow, log | Harbor image mirror/proxy cache |
| `172.16.3.0/24` | `172.16.1.197` | TCP `6443` | allow, log | Management/hub OpenShift API for ACM/HCP agents |
| `172.16.3.0/24` | `172.16.1.0/24` | any | block, log | Prove HCP/default-network isolation |
| `172.16.3.0/24` | any non-default-net destination | routed by later LAN allow rules | HCP outbound traffic |

The `172.16.3.0/24 -> 172.16.1.0/24` block is expected to catch test traffic such as SSH to default-network hosts. For example, blocked `172.16.3.20 -> 172.16.1.197:22` means the isolation rule is working.

## Target addresses

| Service | DNS name | VLAN12 IP | Port |
| --- | --- | --- | --- |
| Kubernetes API | `api.hcp.lost-aurora.de` | `172.16.3.2` | `6443` |
| OAuth Route via dedicated HCP router | `oauth-openshift.apps.hcp.lost-aurora.de` | `172.16.3.3` | `443` |
| Ignition Route via dedicated HCP router | `ignition.apps.hcp.lost-aurora.de` | `172.16.3.4` | `443` |
| Konnectivity | `konnectivity.apps.hcp.lost-aurora.de` | `172.16.3.5` | `8091` |
| Guest apps wildcard | `*.apps.hcp.lost-aurora.de` | `172.16.3.6` | `80/443` |
| Guest default wildcard for HCP-created router health | `*.apps.lab-hcp.hcp.lost-aurora.de` | `172.16.3.7` | `80/443` |
| Worker VM | `lab-hcp` node pool replica 1 | `172.16.3.20` | static guest IP |

For access from the Default network (`172.16.1.0/24`) through the UniFi gateway, UniFi needs a static route for `172.16.3.0/24` via the OPNsense Default-network address, and OPNsense needs SNAT on VLAN12 for Default-network clients reaching the HCP VIPs. In this lab that SNAT covers `172.16.3.2/31`, `172.16.3.4/31`, and `172.16.3.6/31`, so API, OAuth, Ignition, Konnectivity, and guest ingress replies return through OPNsense.

## LoadBalancer IPs and DNS

The `HostedCluster` API supports `servicePublishingStrategy.type: LoadBalancer`, but its `loadBalancer` object only supports `hostname`; it does not pin `loadBalancerIP`.

This setup does not run a service-patching enforcer. Instead:

- `01-management-metallb-vlan12.yaml` makes the HCP MetalLB pool `172.16.3.2-172.16.3.5` eligible for automatic allocation.
- `00-management-vlan12-network.yaml` owns those management-side VIPs as `/32` addresses on `br-hcp`: `172.16.3.3` and `172.16.3.4` on `shiftnode1`, `172.16.3.2` and `172.16.3.5` on `shiftnode2`.
- The HCP-generated `kube-apiserver` and `konnectivity-server` Services carry `external-dns.alpha.kubernetes.io/hostname` annotations from their HostedCluster service publishing config.
- `04-external-dns-cloudflare.yaml` runs ExternalDNS against the `lost-aurora.de` Cloudflare zone, only the `clusters-lab-hcp-lab-hcp` namespace, and only the two HCP LoadBalancer hostnames, then keeps Cloudflare A records in sync with the currently assigned LoadBalancer IPs. It uses `registry=noop` because these records already exist and the instance is tightly scoped by namespace, annotation, and regex filters.

NodePorts on those HCP-generated LoadBalancer Services are acceptable in this lab because OPNsense is the enforced boundary. Default-network access from VLAN12 remains blocked and logged by the firewall.

API and Konnectivity use `servicePublishingStrategy.type: LoadBalancer`. OAuth and Ignition must stay `Route` in this Hypershift release: the controller rejects OAuth with `invalid publishing strategy for OAuth service: LoadBalancer` and Ignition with `unknown service strategy type for ignition service: LoadBalancer`.

`02-management-hcp-routes-ingresscontroller-vlan12.yaml` creates a dedicated management-cluster `hcp-routes` IngressController. It only watches the HCP control-plane namespace `clusters-lab-hcp-lab-hcp` and is placed on the node that owns the HCP route VIPs. `02a-management-router-oauth-vlan12.yaml` and `02b-management-router-ignition-vlan12.yaml` then expose that dedicated router on `172.16.3.3` and `172.16.3.4`.

For customer environments with fully separated networks, this is the important bit: the helper Services must select `ingresscontroller.operator.openshift.io/deployment-ingresscontroller: hcp-routes`, not `default`. The `hcp-routes` router pods must run on nodes that have a real interface in the HCP/tenant network, for example `bond1.225`, and the route VIPs must be advertised or bound on that same network.

The HCP API endpoint is reachable at `https://api.hcp.lost-aurora.de:6443`, but Hypershift rejects using the APIServer LoadBalancer hostname in `spec.configuration.apiServer.servingCerts.namedCertificates`. Use the hosted-cluster kubeconfig, which carries the cluster CA, for `oc` access. Plain `curl` without that CA will report an unknown issuer; `curl -k https://api.hcp.lost-aurora.de:6443/readyz` should return `ok`.

## Image mirrors

The management cluster uses cluster-wide `ImageDigestMirrorSet` and `ImageTagMirrorSet`
objects from `manifests/harbor-mirror-sets/00-harbor-proxy-cache-mirror-sets.yaml`
to prefer Harbor proxy-cache projects for the common upstream registries.

The global `openshift-config/pull-secret` must contain credentials for
`harbor.lost-aurora.de:18443` before relying on those MirrorSets. The hosted
cluster pull secret `clusters-lab-hcp/lab-hcp-pull-secret` must contain the same
Harbor registry credentials so KubeVirt-rendered hosted workers can pull through
the cache as well.

The management cluster's global `ImageDigestMirrorSet` and `ImageTagMirrorSet` objects are not automatically inherited by hosted cluster workers. The `HostedCluster` in `02-hostedcluster-lb-only.yaml` therefore sets `spec.imageContentSources` directly so Hypershift renders the Harbor proxy-cache mirror configuration into each node pool payload.

## Apply order

Run all commands against the management cluster:

```bash
export KUBECONFIG=/Users/Michael.Silich/git/hcp/kubeconfig-noingress-letsencrypt
cd /Users/Michael.Silich/git/hcp

oc apply -f manifests/hcp-lab-hcp-metallb-only/00-management-vlan12-network.yaml
oc apply -f manifests/hcp-lab-hcp-metallb-only/00a-management-ovn-routing-via-host.yaml
oc apply -f manifests/hcp-lab-hcp-metallb-only/01-management-metallb-vlan12.yaml
oc apply -f manifests/harbor-mirror-sets/00-harbor-proxy-cache-mirror-sets.yaml
oc apply -f manifests/hcp-lab-hcp-metallb-only/02-management-hcp-routes-ingresscontroller-vlan12.yaml
oc apply -f manifests/hcp-lab-hcp-metallb-only/02a-management-router-oauth-vlan12.yaml
oc apply -f manifests/hcp-lab-hcp-metallb-only/02b-management-router-ignition-vlan12.yaml
oc apply -f manifests/hcp-lab-hcp-metallb-only/02-hostedcluster-lb-only.yaml

oc create namespace external-dns --dry-run=client -o yaml | oc apply -f -

oc -n cert-manager get secret cloudflare-api-token-secret -o json \
  | jq 'del(.metadata.namespace,.metadata.creationTimestamp,.metadata.resourceVersion,.metadata.uid,.metadata.managedFields,.metadata.ownerReferences) | .metadata.namespace="external-dns"' \
  | oc apply -f -

oc apply -f manifests/hcp-lab-hcp-metallb-only/04a-cert-manager-cloudflare-clusterissuer.yaml
oc apply -f manifests/hcp-lab-hcp-metallb-only/04-external-dns-cloudflare.yaml
oc apply -f manifests/hcp-lab-hcp-metallb-only/03-nodepool-lvms-vlan12.yaml
```

The order intentionally applies the dedicated HCP route router, route helper LoadBalancers, HostedCluster, and ExternalDNS before the node pool. That way, DNS can follow the HCP API and Konnectivity LoadBalancer IPs before worker VMs need API or Konnectivity. OAuth and Ignition are reachable through the fixed `router-hcp-oauth-vlan12` and `router-hcp-ignition-vlan12` LoadBalancers.

Management-node forwarding is handled by `ipForwarding: Global` in `00a-management-ovn-routing-via-host.yaml`, so no MachineConfig is required for `net.ipv4.ip_forward`.

## HCP CLI base render command

The HCP CLI can render the base KubeVirt HostedCluster and NodePool, but it does not expose all service-publishing details needed here. Use this as the reproducible base command, then apply the checked-in YAML overrides in this folder:

```bash
hcp create cluster kubevirt \
  --name lab-hcp \
  --namespace clusters-lab-hcp \
  --base-domain hcp.lost-aurora.de \
  --base-domain-prefix none \
  --kas-dns-name api.hcp.lost-aurora.de \
  --machine-cidr 172.16.3.0/24 \
  --cluster-cidr 10.132.0.0/14 \
  --service-cidr 172.31.0.0/16 \
  --release-image quay.io/openshift-release-dev/ocp-release@sha256:27c93d3b308e9c3694dd7e448d71f61e4e3c033ad8905031736bd1912c1f41fc \
  --pull-secret ./pull-secret.json \
  --control-plane-availability-policy SingleReplica \
  --infra-availability-policy SingleReplica \
  --etcd-storage-class lvms-vg1 \
  --etcd-storage-size 8Gi \
  --node-pool-replicas 0 \
  --render > lab-hcp-rendered.yaml
```

After rendering, keep the `HostedCluster` service list from `02-hostedcluster-lb-only.yaml`, not the default Route/NodePort mix from the CLI.

## Verification

```bash
./manifests/hcp-lab-hcp-metallb-only/05-verify-loadbalancer-dns.sh
```

Expected result:

- HCP API and Konnectivity Services are `type: LoadBalancer`.
- API and Konnectivity have Cloudflare-managed DNS records through ExternalDNS.
- `hcp-routes` is `Available=True`.
- OAuth and Ignition reach the dedicated HCP router through `router-hcp-oauth-vlan12` and `router-hcp-ignition-vlan12`.

After the worker node is `Ready`, apply the guest-cluster ingress pieces against the hosted cluster:

```bash
oc -n clusters-lab-hcp get secret lab-hcp-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/lab-hcp-admin.kubeconfig

oc --kubeconfig /tmp/lab-hcp-admin.kubeconfig --server=https://api.hcp.lost-aurora.de:6443 --insecure-skip-tls-verify=true apply -f manifests/hcp-lab-hcp-metallb-only/07-guest-metallb-operator.yaml
oc --kubeconfig /tmp/lab-hcp-admin.kubeconfig --server=https://api.hcp.lost-aurora.de:6443 --insecure-skip-tls-verify=true wait -n metallb --for=jsonpath='{.status.phase}'=Succeeded csv -l operators.coreos.com/metallb-operator.metallb --timeout=10m
oc --kubeconfig /tmp/lab-hcp-admin.kubeconfig --server=https://api.hcp.lost-aurora.de:6443 --insecure-skip-tls-verify=true apply -f manifests/hcp-lab-hcp-metallb-only/08-guest-metallb-instance.yaml
oc --kubeconfig /tmp/lab-hcp-admin.kubeconfig --server=https://api.hcp.lost-aurora.de:6443 --insecure-skip-tls-verify=true apply -f manifests/hcp-lab-hcp-metallb-only/09-guest-apps-ingress-vlan12.yaml
oc apply -f manifests/hcp-lab-hcp-metallb-only/11-management-console-certificate.yaml
oc apply -f manifests/hcp-lab-hcp-metallb-only/11a-management-oauth-serving-certificate.yaml
./manifests/hcp-lab-hcp-metallb-only/12-sync-console-certificate-to-guest.sh
oc --kubeconfig /tmp/lab-hcp-admin.kubeconfig --server=https://api.hcp.lost-aurora.de:6443 --insecure-skip-tls-verify=true apply -f manifests/hcp-lab-hcp-metallb-only/10-guest-console-custom-route.yaml
oc -n clusters-lab-hcp patch hostedcluster lab-hcp --type=merge -p '{"spec":{"configuration":{"apiServer":{"servingCerts":{"namedCertificates":[{"names":["oauth-openshift.apps.hcp.lost-aurora.de"],"servingCertificate":{"name":"lab-hcp-oauth-serving-certificate-tls"}}]}}}}}'
```

The additional `vlan12` ingress controller uses the supported `NodePortService` strategy, while the user-managed `router-vlan12-public` Service publishes `apps.hcp.lost-aurora.de` through MetalLB IP `172.16.3.6` without LoadBalancer NodePorts. The default HCP-created ingress controller remains managed by Hypershift and keeps its immutable `NodePortService` strategy, but `router-default-vlan12` also exposes it on `172.16.3.7` so its canary checks remain healthy. Public console and app traffic should use `router-vlan12-public`.

In the management control-plane namespace, KubeVirt may create tenant service mirror objects with generated names for guest `LoadBalancer` Services. The live guest Services `router-vlan12-public` and `router-default-vlan12` are the authoritative objects for `172.16.3.6` and `172.16.3.7`; the `05-verify-loadbalancer-dns.sh` check intentionally focuses on the HCP control-plane LoadBalancers, the OAuth/Ignition router helpers, and ExternalDNS.

## Quick live checks

Management side:

```bash
export KUBECONFIG=/Users/Michael.Silich/git/hcp/kubeconfig-noingress-letsencrypt

oc -n clusters-lab-hcp-lab-hcp get svc kube-apiserver konnectivity-server
oc -n openshift-ingress-operator get ingresscontroller hcp-routes
oc -n openshift-ingress get svc router-hcp-oauth-vlan12 router-hcp-ignition-vlan12
./manifests/hcp-lab-hcp-metallb-only/05-verify-loadbalancer-dns.sh
```

Hosted side:

```bash
oc --kubeconfig /tmp/lab-hcp-admin-current/kubeconfig get nodes -o wide
oc --kubeconfig /tmp/lab-hcp-admin-current/kubeconfig -n openshift-ingress get svc router-vlan12-public router-default-vlan12
oc --kubeconfig /tmp/lab-hcp-admin-current/kubeconfig -n open-cluster-management-agent-addon get deploy governance-policy-framework klusterlet-addon-workmgr managed-serviceaccount-addon-agent
curl -k https://api.hcp.lost-aurora.de:6443/readyz
curl https://oauth-openshift.apps.hcp.lost-aurora.de
curl https://console-openshift-console.apps.hcp.lost-aurora.de
```

Expected current results:

- hosted worker is `Ready` on `172.16.3.20`
- `kube-apiserver` is `LoadBalancer` on `api.hcp.lost-aurora.de:6443`
- `hcp-routes` is `Available=True` with selector `ingresscontroller.operator.openshift.io/deployment-ingresscontroller=hcp-routes`
- `router-hcp-oauth-vlan12` is `LoadBalancer` on `172.16.3.3:443` and selects `hcp-routes`
- `router-hcp-ignition-vlan12` is `LoadBalancer` on `172.16.3.4:443` and selects `hcp-routes`
- `konnectivity-server` is `LoadBalancer` on `konnectivity.apps.hcp.lost-aurora.de:8091`
- `router-vlan12-public` is `LoadBalancer` on `172.16.3.6:80/443`
- `router-default-vlan12` is `LoadBalancer` on `172.16.3.7:80/443`
- `curl -k https://api.hcp.lost-aurora.de:6443/readyz` returns `ok`
- `curl https://oauth-openshift.apps.hcp.lost-aurora.de` reaches `172.16.3.3` with a trusted certificate and returns HTTP `403` for anonymous `/`
- `curl https://console-openshift-console.apps.hcp.lost-aurora.de` reaches `172.16.3.6` with a trusted certificate and returns the OpenShift console HTML
- ACM add-ons that need the hub API are `1/1`, including `governance-policy-framework`
