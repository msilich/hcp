#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG_PATH=${KUBECONFIG:-/Users/Michael.Silich/git/hcp/kubeconfig-noingress-8}
NS=clusters-lab-hcp-lab-hcp

echo "HCP control-plane LoadBalancer Services:"
oc --kubeconfig "${KUBECONFIG_PATH}" -n "${NS}" get svc \
  kube-apiserver \
  konnectivity-server \
  -o custom-columns='NAME:.metadata.name,TYPE:.spec.type,HOSTNAME:.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname,EXTERNAL-IP:.status.loadBalancer.ingress[*].ip,LOADBALANCER-IP:.spec.loadBalancerIP,PORTS:.spec.ports[*].port,NODEPORTS:.spec.ports[*].nodePort'

echo
echo "Management router helper LoadBalancer Services:"
oc --kubeconfig "${KUBECONFIG_PATH}" -n openshift-ingress get svc \
  router-hcp-oauth-vlan12 \
  router-hcp-ignition-vlan12 \
  -o custom-columns='NAME:.metadata.name,TYPE:.spec.type,EXTERNAL-IP:.status.loadBalancer.ingress[*].ip,LOADBALANCER-IP:.spec.loadBalancerIP,PORTS:.spec.ports[*].port,NODEPORTS:.spec.ports[*].nodePort'

echo
echo "ExternalDNS status:"
oc --kubeconfig "${KUBECONFIG_PATH}" -n external-dns get deploy,pod -l app=external-dns-lab-hcp || true
