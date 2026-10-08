# Laboratorio 1 — Redes virtuales con Linux

**Estudiante:** Cristhian Tomas Silicuana Quispe
**Usuario GitHub:** Sili1000
**Fecha:** 2026-10-02

## 1. Datos del entorno

| Elemento | Valor |
|---|---|
| Usuario Linux | `cristhian` |
| Distribución | Ubuntu 24.04.5 LTS (Noble Numbat) |
| Entorno | WSL2 sobre Windows |
| Kernel | `6.6.87.2-microsoft-standard-WSL2` |
| Arquitectura | `x86_64` |

Evidencia: [`evidencias/00-entorno.txt`](evidencias/00-entorno.txt)

### Reconocimiento de la red principal (Actividad 1)

Antes de construir la topología se observó la red del sistema principal con `ip link`, `ip addr`, `ip route` e `ip neigh`.

| Elemento | Resultado |
|---|---|
| Interfaces | `lo` (loopback) y `eth0` |
| Estado | `lo` activa (`state UNKNOWN`, normal en loopback); `eth0` en `state UP` |
| IPv4 principal | `172.24.132.23` en `eth0` |
| Prefijo | `/20` → red `172.24.128.0/20`, broadcast `172.24.143.255` |
| Ruta por defecto | `default via 172.24.128.1 dev eth0` |
| Gateway | `172.24.128.1` (Windows, que actúa como router en WSL2) |
| Interfaz de salida | `eth0` |
| Vecinos | `172.24.128.1` con MAC `00:15:5d:b6:ff:a8` |

Rutas observadas:

```text
default via 172.24.128.1 dev eth0 proto kernel
172.24.128.0/20 dev eth0 proto kernel scope link src 172.24.132.23
```

La segunda ruta fue creada automáticamente por el kernel al asignar la dirección `/20` a `eth0`: corresponde a la red directamente conectada y no usa gateway. Todo destino fuera de esa red se envía al gateway mediante la ruta por defecto.

En la tabla de vecinos el único vecino es el gateway. Su entrada estaba en estado `STALE` y pasó a `REACHABLE` después de un `ping`, porque Linux volvió a confirmar que el gateway responde.

**Observación:** en una primera revisión la MAC de eth0 era `00:15:5d:30:b2:d7` y después cambió a `00:15:5d:30:b8:cd`, probablemente porque WSL se reinició, aunque la IP siguió siendo la misma. Por eso los datos de red en WSL hay que tomarlos en el momento.

### Prueba de conectividad

| Prueba | Resultado |
|---|---|
| `ping -c 4 8.8.8.8` | 4/4 respuestas, 0 % de pérdida, RTT promedio ≈ 125 ms |
| `ping -c 4 google.com` | Resuelto a `142.250.0.113`, 4/4 respuestas, 0 % de pérdida |
| `traceroute 8.8.8.8` | 14 saltos; el primero es el gateway `172.24.128.1` |

El primer salto del traceroute coincide con el gateway de la ruta por defecto. Los saltos 4 a 7 usan direcciones privadas (`10.x.x.x`), probablemente de la red interna del proveedor; los últimos pertenecen a la red de Google.

**Pregunta:** si `ping 8.8.8.8` funciona pero `ping google.com` no, se investigaría primero el **DNS**. El ping a una IP demuestra que la interfaz, la dirección, las rutas y el gateway funcionan; lo único adicional que requiere `ping google.com` es traducir el nombre a una dirección IP.

**Caso real durante el laboratorio:** `git pull` se quedó colgado y `ssh -T git@github.com` dio el error `Could not resolve hostname github.com`. Parecía un problema de DNS, pero al hacer `ping -c 4 8.8.8.8` hubo 100 % de pérdida, así que en realidad no había conectividad y el DNS fallaba como consecuencia. Después de un rato la conexión volvió y `ping`, `ssh` y `git pull` funcionaron.

## 2. Objetivo

Construir y verificar una red virtual aislada dentro de una sola computadora Linux, representando dos nodos independientes mediante *network namespaces* conectados por un par `veth`, asignar direccionamiento IPv4, comprobar la conectividad, observar interfaces, rutas y vecinos, y provocar y diagnosticar una falla controlada.

## 3. Topología

```text
       hostA                           hostB
┌───────────────────┐          ┌───────────────────┐
│ network namespace │          │ network namespace │
│  10.10.1.1/30     │          │  10.10.1.2/30     │
│       vethA       ├══════════┤       vethB       │
│                   │   veth   │                   │
└───────────────────┘          └───────────────────┘
```

## 4. Direccionamiento

| Nodo | Namespace | Interfaz | Dirección IPv4 |
|---|---|---|---|
| Host A | `hostA` | `vethA` | `10.10.1.1/30` |
| Host B | `hostB` | `vethB` | `10.10.1.2/30` |

Comandos usados:

```bash
sudo ip netns exec hostA ip addr add 10.10.1.1/30 dev vethA
sudo ip netns exec hostB ip addr add 10.10.1.2/30 dev vethB
```

Verificación con `ip addr` dentro de cada nodo:

```text
hostA:  inet 10.10.1.1/30 scope global vethA
hostB:  inet 10.10.1.2/30 scope global vethB
```

Las dos interfaces ya tienen dirección, pero siguen en `state DOWN`: tener IP no significa que la interfaz esté encendida.

### Cálculo de la red 10.10.1.0/30 (Actividad 2)

Con `/30` quedan 2 bits para hosts, así que la red tiene 2² = 4 direcciones:

| Dirección | Función |
|---|---|
| `10.10.1.0` | Dirección de red |
| `10.10.1.1` | Utilizable (hostA) |
| `10.10.1.2` | Utilizable (hostB) |
| `10.10.1.3` | Broadcast |

Direcciones utilizables: 4 − 2 = **2**.

`10.10.1.1` y `10.10.1.2` pueden estar en el mismo enlace porque comparten los primeros 30 bits, es decir, pertenecen a la misma red `10.10.1.0/30`. Solo cambian los 2 últimos bits (`01` y `10`), que son la parte de host. Por eso se pueden comunicar directamente sin router. Un `/30` es justo lo necesario para un enlace punto a punto entre dos equipos.

## 5. Construcción

### Namespaces

Se crearon los dos nodos:

```bash
sudo ip netns add hostA
sudo ip netns add hostB
ip netns list
```

```text
hostB
hostA
```

Al mirar dentro de hostA con `sudo ip netns exec hostA ip link`, solo aparece un `lo` apagado:

```text
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN
```

hostA no ve `eth0` ni ninguna interfaz del sistema principal. Eso es lo que hace un *network namespace*: le da a cada nodo su propia red (interfaces, direcciones, rutas y vecinos), separada del resto, aunque todos usan el mismo kernel Linux.

### Par veth

Se creó el "cable" virtual:

```bash
sudo ip link add vethA type veth peer name vethB
```

Al hacer `ip link` en el sistema principal aparecieron las dos puntas:

```text
3: vethB@vethA: <BROADCAST,MULTICAST,M-DOWN> ... state DOWN
4: vethA@vethB: <BROADCAST,MULTICAST,M-DOWN> ... state DOWN
```

Aparecen en el sistema principal porque el comando se ejecutó ahí (no tenía `ip netns exec`). Un veth siempre se crea en pares y lo que entra por una punta sale por la otra.

### Mover cada punta a su nodo

```bash
sudo ip link set vethA netns hostA
sudo ip link set vethB netns hostB
```

Después de esto, en el `ip link` del sistema principal solo quedan `lo` y `eth0`. vethA y vethB desaparecieron de ahí porque una interfaz solo puede estar en un namespace a la vez.

Dentro de cada nodo:

```text
hostA:  4: vethA@if3: <BROADCAST,MULTICAST> ... state DOWN ... link-netns hostB
hostB:  3: vethB@if4: <BROADCAST,MULTICAST> ... state DOWN ... link-netns hostA
```

vethA dice que su pareja es la interfaz 3 y que está en hostB; vethB dice que su pareja es la 4 y está en hostA, así que el cable une los dos nodos. Antes se veía `vethA@vethB` y ahora `vethA@if3`: desde dentro de hostA ya no se puede ver el nombre de vethB porque está en otro namespace.

Todas las interfaces están en `DOWN` y sin dirección IP; eso se configura en los siguientes pasos.

## 6. Verificación

### Interfaces

Antes de encender las interfaces, la tabla de rutas de hostA estaba vacía (`sudo ip netns exec hostA ip route` no mostró nada), aunque vethA ya tenía dirección.

Se encendieron las interfaces en cada nodo:

```bash
sudo ip netns exec hostA ip link set lo up
sudo ip netns exec hostA ip link set vethA up
sudo ip netns exec hostB ip link set lo up
sudo ip netns exec hostB ip link set vethB up
```

Resultado:

```text
hostA:  4: vethA@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> ... state UP
hostB:  3: vethB@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> ... state UP
```

`UP` significa que la interfaz fue habilitada; `LOWER_UP` significa que hay enlace, y en un veth eso solo pasa cuando las dos puntas están encendidas. El `lo` queda en `state UNKNOWN`, que es normal en loopback.

**Diferencia entre interfaz existente, direccionada y UP:**

| Etapa | Qué tenía | ¿Podía comunicarse? |
|---|---|---|
| Existente | Solo la interfaz y su MAC | No |
| Direccionada | Interfaz + IP | No, seguía en `DOWN` y sin ruta |
| UP | Interfaz + IP + encendida | Sí |

Una interfaz necesita las tres cosas: existir, tener dirección y estar en `UP`.

### Direcciones

Las direcciones `10.10.1.1/30` y `10.10.1.2/30` se verificaron en la sección 4 (Direccionamiento).

### Rutas

Sin agregar ninguna ruta manual, cada nodo tiene una sola ruta:

```text
hostA:  10.10.1.0/30 dev vethA proto kernel scope link src 10.10.1.1
hostB:  10.10.1.0/30 dev vethB proto kernel scope link src 10.10.1.2
```

**Actividad 3:**

1. **Ruta en hostA:** `10.10.1.0/30` por `vethA`, con origen `10.10.1.1`.
2. **Ruta en hostB:** `10.10.1.0/30` por `vethB`, con origen `10.10.1.2`.
3. **Por qué apareció:** Linux la crea solo (`proto kernel`) cuando la interfaz tiene dirección y está `UP`. Antes de encender vethA la tabla estaba vacía; después de encenderla apareció. Es el mismo tipo de ruta que `172.24.128.0/20 dev eth0` en el sistema principal.
4. **Interfaz para llegar al otro nodo:** `10.10.1.2` está dentro de `10.10.1.0/30`, así que hostA usa `vethA`; hostB usa `vethB` para llegar a `10.10.1.1`.
5. **¿Hace falta gateway?** No. Los dos nodos están en la misma red `10.10.1.0/30` y unidos directamente por el veth (`scope link`, sin `via`). Un gateway solo se necesita para llegar a redes que no están directamente conectadas.

Como no existe ruta `default`, ningún nodo puede llegar a internet: solo conocen su propia red.

### Vecinos

Antes del ping, la tabla de vecinos de hostA estaba vacía (`sudo ip netns exec hostA ip neigh` no mostró nada). Después del ping:

```text
hostA:  10.10.1.2 dev vethA lladdr 8a:10:55:bd:37:45 STALE
hostB:  10.10.1.1 dev vethB lladdr 66:86:98:1d:54:9f STALE
```

**Actividad 4:**

| Nodo | IP del vecino | MAC observada | Estado |
|---|---|---|---|
| hostA | `10.10.1.2` | `8a:10:55:bd:37:45` | `STALE` |
| hostB | `10.10.1.1` | `66:86:98:1d:54:9f` | `STALE` |

Las MAC coinciden con las de vethB y vethA vistas en la construcción. El estado es `STALE` porque pasaron unos segundos desde el ping; con más tráfico vuelve a `REACHABLE`.

En un enlace Ethernet los paquetes IP viajan dentro de tramas que van dirigidas a una MAC, no a una IP. Por eso, antes del primer ping, hostA tuvo que preguntar por ARP cuál era la MAC de `10.10.1.2`. Esa respuesta es la que queda guardada en la tabla de vecinos.

### Conectividad

```bash
sudo ip netns exec hostA ping -c 4 10.10.1.2
sudo ip netns exec hostB ping -c 4 10.10.1.1
```

| Prueba | Resultado |
|---|---|
| hostA → hostB | 4/4 respuestas, 0 % pérdida, RTT promedio 0.099 ms, `ttl=64` |
| hostB → hostA | 4/4 respuestas, 0 % pérdida, RTT promedio 0.063 ms, `ttl=64` |

Hay conectividad en los dos sentidos.

- Los tiempos (~0.06 ms) son mucho menores que hacia internet (~125 ms) porque los paquetes nunca salen de la laptop: el veth es memoria dentro del mismo kernel.
- El `ttl=64` llega sin cambios, lo que confirma que no hay ningún router entre los dos nodos.
- El primer ping de hostA fue más lento (0.243 ms) porque antes tuvo que resolver la MAC de hostB por ARP. En el ping de hostB el primero no fue más lento porque hostB ya había aprendido la MAC de hostA.

## 7. Captura y análisis de tráfico

Antes de capturar se vació la tabla de vecinos de los dos nodos, para que el ping tuviera que hacer ARP de nuevo:

```bash
sudo ip netns exec hostA ip neigh flush all
sudo ip netns exec hostB ip neigh flush all
```

En una terminal se capturó en hostA y en otra se hizo ping desde hostB:

```bash
sudo ip netns exec hostA tcpdump -n -i vethA
sudo ip netns exec hostB ping -c 4 10.10.1.1
```

Captura:

```text
17:38:23.002984 ARP, Request who-has 10.10.1.1 tell 10.10.1.2, length 28
17:38:23.003004 ARP, Reply 10.10.1.1 is-at 66:86:98:1d:54:9f, length 28
17:38:23.003007 IP 10.10.1.2 > 10.10.1.1: ICMP echo request, id 1228, seq 1, length 64
17:38:23.003102 IP 10.10.1.1 > 10.10.1.2: ICMP echo reply, id 1228, seq 1, length 64
...
17:38:26.063252 IP 10.10.1.2 > 10.10.1.1: ICMP echo request, id 1228, seq 4, length 64
17:38:26.063274 IP 10.10.1.1 > 10.10.1.2: ICMP echo reply, id 1228, seq 4, length 64
17:38:28.143477 ARP, Request who-has 10.10.1.2 tell 10.10.1.1, length 28
17:38:28.143526 ARP, Reply 10.10.1.2 is-at 8a:10:55:bd:37:45, length 28
12 packets captured
```

**Actividad 5 — secuencia observada:**

1. **ARP Request:** hostB pregunta quién tiene `10.10.1.1`. Lo envía a todos (broadcast) porque todavía no conoce ninguna MAC.
2. **ARP Reply:** hostA responde con su MAC `66:86:98:1d:54:9f` (la de vethA).
3. **ICMP Echo Request / Echo Reply:** 4 pares, uno por segundo. Cada request tiene su reply con el mismo `seq`; el `id 1228` es el mismo porque son del mismo comando ping.
4. **ARP al final:** unos 5 segundos después, hostA pregunta por `10.10.1.2`. hostA había aprendido la MAC de hostB a partir de su pregunta, sin confirmarla; este ARP sirve para verificarla.

El ARP aparece antes del ping porque sin la MAC del destino no se puede armar la trama Ethernet que lleva el paquete IP.

## 8. Falla y diagnóstico

### 1. Predicción previa

Antes de apagar vethB se anotó lo que se esperaba:

- El ping de hostA a hostB **no** va a funcionar, porque vethB tiene que estar encendida.
- La ruta de hostB: sin predicción.
- vethA en hostA va a seguir con `LOWER_UP`.

### 2. Síntoma observado

```bash
sudo ip netns exec hostB ip link set vethB down
sudo ip netns exec hostA ping -c 4 10.10.1.2
```

```text
From 10.10.1.1 icmp_seq=1 Destination Host Unreachable
...
4 packets transmitted, 0 received, +4 errors, 100% packet loss
```

El mensaje viene de `10.10.1.1`, o sea del propio hostA: no consiguió la MAC de hostB por ARP y declaró el destino inalcanzable.

### 3. Comandos de diagnóstico y resultados

| Nodo | Comando | Resultado | Interpretación |
|---|---|---|---|
| hostA | `ip link` | `vethA: <NO-CARRIER,...,UP> state DOWN` | vethA está encendida pero no hay nadie al otro lado |
| hostA | `ip addr` | `inet 10.10.1.1/30` | La IP sigue configurada |
| hostA | `ip route` | `10.10.1.0/30 dev vethA ... linkdown` | La ruta existe pero marcada como enlace caído |
| hostA | `ip neigh` | `10.10.1.2 dev vethA FAILED` | El ARP hacia hostB no tuvo respuesta |
| hostB | `ip link` | `vethB: <BROADCAST,MULTICAST> state DOWN` | **No aparece `UP`: vethB está apagada** |
| hostB | `ip addr` | `inet 10.10.1.2/30` | La IP sigue configurada |
| hostB | `ip route` | *(vacío)* | La ruta desapareció porque la interfaz está apagada |

**Comparación con la predicción:** el ping falló como se esperaba. Pero vethA **no** siguió con `LOWER_UP`: pasó a `NO-CARRIER`. En un veth, `LOWER_UP` solo aparece cuando las dos puntas están encendidas; al apagar vethB, vethA se quedó sin nada al otro lado. La ruta de hostB desapareció, igual que en la sección de puesta en servicio antes de encender la interfaz.

### 4. Causa de la falla

Siguiendo la secuencia de la guía (¿existe el namespace? → ¿existe la interfaz? → ¿está UP?), el problema aparece en el tercer paso: **vethB en hostB estaba apagada** (sin `UP`). hostA mostraba `UP` pero `NO-CARRIER`, lo que indicaba que el problema estaba del otro lado del enlace.

### 5. Acción correctiva

```bash
sudo ip netns exec hostB ip link set vethB up
```

### 6. Prueba de recuperación

```text
hostA ping 10.10.1.2:  4 packets transmitted, 4 received, 0% packet loss
hostB ip route:        10.10.1.0/30 dev vethB proto kernel scope link src 10.10.1.2
hostA ip link:         vethA: <BROADCAST,MULTICAST,UP,LOWER_UP> state UP
```

El ping volvió a funcionar, la ruta de hostB reapareció y vethA recuperó `LOWER_UP`. El primer ping fue un poco más lento (0.136 ms) porque hostA tuvo que volver a resolver la MAC de hostB por ARP.

## 9. Uso de OpenCode

### Problema

Durante la falla controlada, el ping de hostA a hostB daba `Destination Host Unreachable`. Se quiso comprobar si, con las salidas de hostA solamente, OpenCode llegaba a la misma conclusión que el diagnóstico manual.

### Consulta

Se usó OpenCode en modo **Plan** (solo analiza, no ejecuta), con el modelo gratuito Big Pickle:

```text
Tengo dos network namespaces Linux (hostA y hostB) conectados por un par veth.
hostA tiene 10.10.1.1/30 en vethA y hostB tiene 10.10.1.2/30 en vethB.
El ping de hostA a hostB da "Destination Host Unreachable".
Salidas en hostA:
ip link:  vethA@if3: <NO-CARRIER,BROADCAST,MULTICAST,UP> state DOWN
ip route: 10.10.1.0/30 dev vethA proto kernel scope link src 10.10.1.1 linkdown
ip neigh: 10.10.1.2 dev vethA FAILED
No ejecutes comandos ni modifiques archivos. No me des la solución completa.
Indícame qué debería verificar primero y por qué.
Distingue hechos observables de tus inferencias.
```

### Propuesta obtenida

- **Hechos:** vethA está administrativamente `UP` pero sin portadora (`NO-CARRIER`, `state DOWN`); la ruta existe pero está `linkdown`; el ARP hacia `10.10.1.2` falló.
- **Inferencias:** `NO-CARRIER` sugiere que el otro extremo (vethB) no está activo; la ruta `linkdown` y el vecino `FAILED` serían consecuencias del enlace caído, no causas.
- **Qué verificar primero:** el estado de vethB en hostB, porque un veth necesita las dos puntas en `UP`. En segundo lugar, que el par esté bien emparejado (`@if3`) y en el namespace correcto.

### Verificación

- En hostB, `ip link` mostró vethB **sin `UP`**: se confirma la inferencia principal.
- Al encender vethB, la ruta `linkdown` y el vecino `FAILED` se corrigieron solos: se confirma que eran consecuencias.
- El emparejamiento ya se había comprobado en la construcción (`vethA@if3` ↔ `vethB@if4`).

**Comparación con un primer intento:** antes de esta consulta se envió por error un mensaje incompleto. Esa respuesta daba directamente la solución y afirmaba que `Destination Host Unreachable` suele indicar una ruta ausente. Eso **no coincidía con lo observado**: hostA sí tenía la ruta (`linkdown`), y el mensaje aparecía porque el ARP no obtuvo respuesta. Cuando realmente falta la ruta, Linux muestra `Network is unreachable`. Esto muestra que una respuesta de IA hay que contrastarla con las salidas reales.

### Explicación técnica

Un par veth funciona como un cable: `UP` es el estado que configura uno mismo, pero `LOWER_UP` (portadora) depende de que el otro extremo también esté `UP`. Por eso, desde hostA se ve el síntoma (`NO-CARRIER`), pero la causa está en hostB. La ruta y el vecino fallan como consecuencia, no son el origen del problema.

### Otras herramientas de IA

Además de OpenCode, se usó un asistente de IA (Claude) como apoyo para interpretar salidas de comandos y organizar el informe. Cada dato del informe se verificó con las salidas obtenidas en la terminal.

## 10. Conclusiones

- Con una sola computadora se pudieron armar dos "equipos" (hostA y hostB) y conectarlos con un cable virtual. Cada uno tiene su propia red y no ve la del otro ni la del sistema principal.
- Se aprendió que no basta con ponerle IP a una interfaz: también hay que encenderla. Mientras estaba apagada no había ruta y no se podía hacer ping.
- No se necesitó gateway porque los dos equipos están en la misma red y unidos directamente por el cable.
- Para enviar un ping, primero el equipo tiene que saber la MAC del otro. Eso se vio en tcpdump: primero aparece ARP y después el ping.
- Cuando se apagó vethB, el problema se veía en hostA, pero la causa estaba en hostB. Se esperaba que vethA siguiera con LOWER_UP, pero no fue así, porque depende de que las dos puntas del cable estén encendidas.
- OpenCode ayudó a saber qué revisar primero, pero no todo lo que dice la IA es correcto; hay que comprobarlo con lo que muestra la terminal.