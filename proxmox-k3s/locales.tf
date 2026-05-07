locals {
  # ---- Cluster identity ----
  cluster_name = var.cluster.name
  cluster_id   = var.cluster.id != null ? var.cluster.id : random_id.cluster_id.hex

  # ---- Network prefix (/24 etc) ----
  network_prefix = split("/", var.network.cidr)[1]

  # ---- Master IP ----
  master_ip_raw  = var.master.ip_address != null ? var.master.ip_address : cidrhost(var.network.cidr, 60)
  master_ip      = local.master_ip_raw
  master_ip_cidr = "${local.master_ip_raw}/${local.network_prefix}"

  # ---- Worker IPs ----
  worker_ips_raw = [
    for i in range(var.workers.count) :
    cidrhost(var.network.cidr, var.workers.ip_start + i)
  ]
  worker_ips = local.worker_ips_raw
  worker_ips_cidr = [
    for ip in local.worker_ips_raw :
    "${ip}/${local.network_prefix}"
  ]

  # ---- Hostnames ----
  master_name = "lxa-${local.cluster_name}-master"

  worker_names = [
    for i in range(var.workers.count) :
    "lxa-${local.cluster_name}-worker-${i}-${random_id.worker_node_id[i].hex}"
  ]

  # ---- Extract last octets (WITHOUT CIDR part) ----
  master_octet = tonumber(split(".", local.master_ip_raw)[3])

  worker_octets = [
    for ip in local.worker_ips :
    tonumber(split(".", split("/", ip)[0])[3])
  ]

  # ---- VM IDs ----
  master_vmid = tonumber("${local.master_octet}${local.master_octet}")

  worker_vmids = [
    for octet in local.worker_octets :
    tonumber("${local.master_octet}${octet}")
  ]

  # ---- SSH user ----
  ssh_user = "lxa"

  # ---- Shared storage ----
  nfs_server = var.network.nfs.server
  nfs_path   = var.network.nfs.path

  # ---- K3s flags ----
  k3s_disable_flags = compact([
    var.k3s.features.traefik ? null : "--disable traefik",
    var.k3s.features.local_storage ? null : "--disable local-storage",
    var.k3s.features.metrics ? null : "--disable metrics-server",
  ])

  k3s_disable_args = join(" ", local.k3s_disable_flags)

  k3s_tls_san_args = join(" ", [
    for san in var.k3s.tls_san :
    "--tls-san ${san}"
  ])

  k3s_master_label_args = join(" ", [
    for l in var.master.labels :
    "--node-label ${l}"
  ])

  k3s_master_taint_args = join(" ", [
    for t in var.master.taints :
    "--node-taint ${t}"
  ])

  k3s_worker_label_args = join(" ", [
    for l in var.workers.labels :
    "--node-label ${l}"
  ])

  k3s_worker_taint_args = join(" ", [
    for t in var.workers.taints :
    "--node-taint ${t}"
  ])

  k3s_master_args = join(" ", compact([
    "--write-kubeconfig-mode 644",
    "--node-taint CriticalAddonsOnly=true:NoExecute",
    local.k3s_disable_args,
    local.k3s_tls_san_args,
    local.k3s_master_label_args,
    local.k3s_master_taint_args
  ]))

  k3s_worker_args = join(" ", compact([
    local.k3s_worker_label_args,
    local.k3s_worker_taint_args
  ]))

  k3s_extra_args = join(" ", var.k3s.extra_args)

}

output "cluster_name" {
  value = local.cluster_name
}
output "cluster_id" {
  value = local.cluster_id
}

output "master_ip" {
  value = local.master_ip
}

output "master_hostname" {
  value = local.master_name
}

output "worker_ips" {
  value = local.worker_ips
}

output "workers_hostname" {
  value = local.worker_names
}

output "k3s_disabled" {
  value = local.k3s_disable_args
}
output "k3s_tls_san_args" {
  value = local.k3s_tls_san_args
}
output "k3s_master_labels_args" {
  value = local.k3s_master_label_args
}
output "k3s_master_taints_args" {
  value = local.k3s_master_taint_args
}
output "k3s_workers_labels_args" {
  value = local.k3s_worker_label_args
}
output "k3s_workers_taints_args" {
  value = local.k3s_worker_taint_args
}
output "k3s_master_args" {
  value = local.k3s_master_args
}
output "k3s_worker_args" {
  value = local.k3s_worker_args
}


