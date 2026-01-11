apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudflare-issuer
spec:
  acme:
    email: ${email}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: cloudflare-issuer-account-key
    solvers:
      - http01:
          gatewayHTTPRoute:
            parentRefs:
              - name: public-gateway
                namespace: envoy-gateway-system
                kind: Gateway
                group: gateway.networking.k8s.io
