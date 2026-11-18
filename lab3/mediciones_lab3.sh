#!/usr/bin/env bash
# Laboratorio 3 - mediciones DNS, ping, RDAP y AS_PATH
OUT="resultados_lab3.txt"
DOMINIOS="impuestos.bo umsa.bo entel.bo bcp.com.bo"

echo "== Instalando herramientas (pide tu contraseña) =="
sudo apt update -qq && sudo apt install -y -qq dnsutils iputils-ping curl python3 >/dev/null

{
echo "Fecha de medición: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo
echo "################ DNS ################"
for d in $DOMINIOS; do
  echo "===== $d ====="
  echo "--- A (con TTL) ---";  dig "$d" A +noall +answer
  echo "--- NS ---";           dig "$d" NS +short
  echo "--- MX ---";           dig "$d" MX +short
  echo
done
for d in impuestos.bo umsa.bo; do
  echo "===== $d (AAAA, SOA, TXT) ====="
  echo "--- AAAA ---"; dig "$d" AAAA +noall +answer
  echo "--- SOA ---";  dig "$d" SOA +short
  echo "--- TXT ---";  dig "$d" TXT +short
  echo
done
echo "===== impuestos.bo A consultado a Cloudflare (1.1.1.1) ====="
dig @1.1.1.1 impuestos.bo A +noall +answer
echo
echo "################ PING ################"
for d in impuestos.bo umsa.bo entel.bo; do
  echo "===== ping $d ====="
  ping -c 5 "$d" 2>&1 | tail -n 4
  echo
done
echo "################ LACNIC RDAP ################"
for asn in 6568 26210; do
  echo "===== AS$asn ====="
  curl -s "https://rdap.lacnic.net/rdap/autnum/$asn" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("handle:", d.get("handle"), "| name:", d.get("name"))
for e in d.get("entities",[]):
    v=e.get("vcardArray",[None,[]])[1]
    fn=[x[3] for x in v if x[0]=="fn"]
    print("entidad:", e.get("roles"), fn)
' 2>&1 | head -n 8
  echo
done
echo "################ RIPEstat AS_PATH (prefijo de ENTEL) ################"
curl -s "https://stat.ripe.net/data/looking-glass/data.json?resource=190.129.0.0/20" | python3 -c '
import json,sys
d=json.load(sys.stdin)
n=0
for rrc in d["data"]["rrcs"]:
    for p in rrc["peers"]:
        print(rrc["location"], "| prefijo:", p["prefix"], "| AS_PATH:", p["as_path"])
        n+=1
        if n>=6: sys.exit()
' 2>&1
} | tee "$OUT"
echo
echo "Listo. Resultados guardados en $OUT"
