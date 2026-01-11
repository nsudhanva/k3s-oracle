apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: oci-vault
spec:
  provider:
    oracle:
      vault: ${vault_ocid}
      region: ${oci_region}
      principalType: InstancePrincipal
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: regcred-sync
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: oci-vault
    kind: ClusterSecretStore
  target:
    name: regcred
    creationPolicy: Merge
    template:
      type: kubernetes.io/dockerconfigjson
      data:
        .dockerconfigjson: |
          {
            "auths": {
              "ghcr.io": {
                "username": "${git_username}",
                "password": "{{ .github_pat }}",
                "email": "${git_email}",
                "auth": "{{ printf "%s:%s" "${git_username}" .github_pat | b64enc }}"
              }
            }
          }
  data:
    - secretKey: github_pat
      remoteRef:
        key: github-pat
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: repo-creds-sync
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: oci-vault
    kind: ClusterSecretStore
  target:
    name: repo-creds
    creationPolicy: Merge
    template:
      metadata:
        labels:
          argocd.argoproj.io/secret-type: repository
      data:
        url: "${git_repo_url}"
        username: "${git_username}"
        password: "{{ .github_pat }}"
  data:
    - secretKey: github_pat
      remoteRef:
        key: github-pat
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: argocd-admin-password-sync
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: oci-vault
    kind: ClusterSecretStore
  target:
    name: argocd-initial-admin-secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: argocd-admin-password
