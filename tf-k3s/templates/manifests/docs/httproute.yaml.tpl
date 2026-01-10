apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: docs-route
  namespace: default
spec:
  parentRefs:
  - name: docs-gateway
  hostnames:
  - "${domain_name}"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: docs
      port: 80
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: docs-tls
  namespace: default
spec:
  secretName: docs-tls
  issuerRef:
    name: cloudflare-issuer
    kind: ClusterIssuer
  commonName: "${domain_name}"
  dnsNames:
  - "${domain_name}"
