apiVersion: externaldns.k8s.io/v1alpha1
kind: DNSEndpoint
metadata:
  name: k3s-ingress-dns
  namespace: default
spec:
  endpoints:
  - dnsName: ${domain_name}
    recordTTL: 300
    recordType: A
    targets:
    - ${ingress_public_ip}
