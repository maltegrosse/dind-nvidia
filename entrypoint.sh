#!/bin/sh
cgroup_path="/sys/fs/cgroup/"
new_group_path="$cgroup_path"DIND
echo "setting cgroups"
mkdir -p $new_group_path
if [ -z "${KUBERNETES_SERVICE_HOST}" ]; then
  echo "non-k8s"
  if [ -z "${CPU_MAX}" ] || [ -z "${MEMORY_MAX}"]; then
    echo "env variable missing, skip setting resources"
  else
    echo "$CPU_MAX" > "$new_group_path"/cpu.max
    echo "$MEMORY_MAX" > "$new_group_path"/memory.max
  fi
else
  echo "k8s"
  cgroup_k8s_path=$(cat /proc/self/cgroup | cut -d: -f3)
  full_path="$cgroup_path$cgroup_k8s_path"
  echo $(cat "$full_path"/cpu.max)> "$new_group_path"/cpu.max
  echo $(cat "$full_path"/memory.max)> "$new_group_path"/memory.max
fi
. ./dockerd-entrypoint.sh