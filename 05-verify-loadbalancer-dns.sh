#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG_PATH=${KUBECONFIG:-/Users/Michael.Silich/git/hcp/kubeconfig-noingress-letsencrypt}
NS=clusters-lab-hcp-lab-hcp

echo "HCP control-plane LoadBalancer Services:"
oc --kubeconfig "${KUBECONFIG_PATH}" -n "${NS}" get svc \
  kube-apiserver \
  konnectivity-server \
  -o custom-columns='NAME:.metadata.name,TYPE:.spec.type,HOSTNAME:.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname,EXTERNAL-IP:.status.loadBalancer.ingress[*].ip,LOADBALANCER-IP:.spec.loadBalancerIP,PORTS:.spec.ports[*].port,NODEPORTS:.spec.ports[*].nodePort'

echo
echo "Dedicated HCP route IngressController:"
oc --kubeconfig "${KUBECONFIG_PATH}" -n openshift-ingress-operator get ingresscontroller hcp-routes \
  -o custom-columns='NAME:.metadata.name,AVAILABLE:.status.conditions[?(@.type=="Available")].status,PROGRESSING:.status.conditions[?(@.type=="Progressing")].status,DEGRADED:.status.conditions[?(@.type=="Degraded")].status,SELECTOR:.status.selector'

echo
echo "Route helper LoadBalancer Services:"
oc --kubeconfig "${KUBECONFIG_PATH}" -n openshift-ingress get svc \
  router-hcp-oauth-vlan12 \
  router-hcp-ignition-vlan12 \
  -o custom-columns='NAME:.metadata.name,TYPE:.spec.type,EXTERNAL-IP:.status.loadBalancer.ingress[*].ip,LOADBALANCER-IP:.spec.loadBalancerIP,SELECTOR:.spec.selector.ingresscontroller\.operator\.openshift\.io/deployment-ingresscontroller,PORTS:.spec.ports[*].port,NODEPORTS:.spec.ports[*].nodePort'

echo
echo "ExternalDNS status:"
oc --kubeconfig "${KUBECONFIG_PATH}" -n external-dns get deploy,pod -l app=external-dns-lab-hcp || true
