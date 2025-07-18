apiVersion: v1
kind: Config
current-context: ${cluster_name}
clusters:
- cluster:
    certificate-authority-data: ${ca_certificate}
    server: ${endpoint}
  name: ${cluster_name}
contexts:
- context:
    cluster: ${cluster_name}
    user: ${cluster_name}
  name: ${cluster_name}
users:
- name: ${cluster_name}
  user:
    token: ${token}
