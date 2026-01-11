apiVersion: externaldns.k8s.io/v1alpha1
kind: DNSEndpoint
metadata:
  name: k3s-ingress-dns
  namespace: external-dns
spec:
  endpoints:
  - dnsName: ${domain_name}
    recordTTL: 300
    recordType: A
    targets:
    - ${ingress_public_ip}
    providerSpecific:
    - name: external-dns.alpha.kubernetes.io/cloudflare-proxied
      value: "true"
  - dnsName: cd.${domain_name}
    recordTTL: 300
    recordType: A
    targets:
    - ${ingress_public_ip}
    providerSpecific:
    - name: external-dns.alpha.kubernetes.io/cloudflare-proxied
      value: "true"
