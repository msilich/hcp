#!/usr/bin/env bash
set -euo pipefail

MANAGEMENT_KUBECONFIG="${MANAGEMENT_KUBECONFIG:-/Users/Michael.Silich/git/hcp/kubeconfig-noingress-letsencrypt}"
GUEST_KUBECONFIG="${GUEST_KUBECONFIG:-/tmp/lab-hcp-admin.kubeconfig}"
GUEST_SERVER="${GUEST_SERVER:-https://api.hcp.lost-aurora.de:6443}"
SECRET_NAME="console-openshift-console-apps-hcp-lost-aurora-de-tls"

tls_crt="$(
  oc --kubeconfig "${MANAGEMENT_KUBECONFIG}" \
    -n clusters-lab-hcp get secret "${SECRET_NAME}" \
    -o jsonpath='{.data.tls\.crt}'
)"
tls_key="$(
  oc --kubeconfig "${MANAGEMENT_KUBECONFIG}" \
    -n clusters-lab-hcp get secret "${SECRET_NAME}" \
    -o jsonpath='{.data.tls\.key}'
)"

oc --kubeconfig "${GUEST_KUBECONFIG}" \
  --server="${GUEST_SERVER}" \
  --insecure-skip-tls-verify=true \
  apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: openshift-config
type: kubernetes.io/tls
data:
  tls.crt: ${tls_crt}
  tls.key: ${tls_key}
EOF
