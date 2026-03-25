#!/bin/bash
export PATH=$PATH:/home/ubuntu/.local/bin

echo "========== 5G MANO Stack Health Check =========="
echo "  Time: $(date)"
echo ""

# --- Infrastructure ---
echo "=== INFRASTRUCTURE ==="

echo ""
echo "[1/10] Docker containers (Kafka/Confluent)..."
DOCKER_COUNT=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l)
if [ "$DOCKER_COUNT" -gt 0 ]; then
  echo "  OK ($DOCKER_COUNT containers running)"
  docker ps --format "  {{.Names}}\t{{.Status}}" 2>/dev/null | column -t -s $'\t'
else
  echo "  FAIL: No Docker containers running"
fi

echo ""
echo "[2/10] Kubernetes pods..."
echo "  STATUS SUMMARY:"
microk8s kubectl get pods --no-headers 2>/dev/null | awk '{s[$3]++} END {for(k in s) printf "    %-20s %d\n", k, s[k]}'
echo ""
echo "  DETAILS:"
microk8s kubectl get pods --no-headers 2>/dev/null | awk '{
  status=$3; ready=$2;
  icon="OK"; if(status!="Running") icon="!!";
  printf "  [%s] %-60s %-20s %s\n", icon, $1, status, ready
}'

echo ""
echo "[3/10] Kubernetes services (NodePorts)..."
microk8s kubectl get svc --no-headers 2>/dev/null | awk '{printf "  %-30s %-15s %s\n", $1, $2, $5}'

echo ""
echo "[4/10] Persistent Volumes..."
microk8s kubectl get pv --no-headers 2>/dev/null | awk '{printf "  %-40s %-10s %-10s %s\n", $1, $2, $5, $6}'

# --- APIs ---
echo ""
echo "=== API ENDPOINTS ==="

echo ""
echo "[5/10] free5gmano API (port 30088)..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:30088/swagger/)
if [ "$STATUS" = "200" ]; then echo "  OK (HTTP $STATUS)"; else echo "  FAIL (HTTP $STATUS)"; fi

echo ""
echo "[6/10] kube5gnfvo API (port 30888)..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:30888/swagger/v1/nsd/)
if [ "$STATUS" = "200" ]; then echo "  OK (HTTP $STATUS)"; else echo "  FAIL (HTTP $STATUS)"; fi

echo ""
echo "[7/10] Kafka (port 9092)..."
timeout 3 bash -c 'echo > /dev/tcp/localhost/9092' 2>/dev/null && echo "  OK" || echo "  NOT RUNNING"

# --- MANO Data ---
echo ""
echo "=== MANO STATE ==="

echo ""
echo "[8/10] Registered plugins..."
cd ~/work/free5gmano-cli 2>/dev/null
nmctl get plugin 2>/dev/null || echo "  FAIL: nmctl not working"

echo ""
echo "[9/10] NSSTs (Network Slice Subnet Templates)..."
nmctl get nsst 2>/dev/null || echo "  FAIL"

echo ""
echo "[10/10] kube5gnfvo resources..."
echo "  VNF Packages:"
VNF_PKGS=$(curl -s --max-time 5 http://localhost:30888/vnfpkgm/v1/vnf_packages/)
echo "$VNF_PKGS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f'    Count: {len(data)}')
    for p in data[:5]:
        state = p.get('onboardingState', '?')
        print(f'    {p[\"id\"]}  [{state}]')
    if len(data) > 5: print(f'    ... and {len(data)-5} more')
except: print('    (unable to parse)')
" 2>/dev/null

echo "  NS Descriptors:"
NS_DESC=$(curl -s --max-time 5 http://localhost:30888/nsd/v1/ns_descriptors/)
echo "$NS_DESC" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f'    Count: {len(data)}')
    for d in data[:5]:
        state = d.get('nsdOnboardingState', '?')
        name = d.get('nsdName', '?')
        print(f'    {d[\"id\"]}  [{state}] {name}')
    if len(data) > 5: print(f'    ... and {len(data)-5} more')
except: print('    (unable to parse)')
" 2>/dev/null

echo "  NS Instances:"
NS_INST=$(curl -s --max-time 5 http://localhost:30888/nslcm/v1/ns_instances/)
echo "$NS_INST" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f'    Count: {len(data)}')
    for i in data[:5]:
        state = i.get('nsState', '?')
        name = i.get('nsInstanceName', '?')
        vnfs = len(i.get('vnfInstance', []))
        print(f'    {i[\"id\"]}  [{state}] {name} ({vnfs} VNFs)')
    if len(data) > 5: print(f'    ... and {len(data)-5} more')
except: print('    (unable to parse)')
" 2>/dev/null

# --- Host header fix check ---
echo ""
echo "=== FIX VERIFICATION ==="
echo "  Plugin Host header fix:"
grep -q "svc.cluster.local" /data/plugin/kube5gnfvo/allocate/main.py 2>/dev/null \
  && echo "  OK (dynamic FQDN Host header present)" \
  || echo "  MISSING — NSSI allocation may fail (no FQDN Host header fix)"

echo ""
echo "  Plugin __pycache__:"
if [ -d /data/plugin/kube5gnfvo/allocate/__pycache__ ]; then
  echo "  EXISTS (will use cached bytecode)"
else
  echo "  CLEAN (will recompile on next run)"
fi

echo ""
echo "========== Done =========="
