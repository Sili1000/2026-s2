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

### Prueba de conectividad

| Prueba | Resultado |
|---|---|
| `ping -c 4 8.8.8.8` | 4/4 respuestas, 0 % de pérdida, RTT promedio ≈ 125 ms |
| `ping -c 4 google.com` | Resuelto a `142.250.0.113`, 4/4 respuestas, 0 % de pérdida |
| `traceroute 8.8.8.8` | 14 saltos; el primero es el gateway `172.24.128.1` |

El primer salto del traceroute coincide con el gateway de la ruta por defecto. Los saltos 4 a 7 usan direcciones privadas (`10.x.x.x`), probablemente de la red interna del proveedor; los últimos pertenecen a la red de Google.

**Pregunta:** si `ping 8.8.8.8` funciona pero `ping google.com` no, se investigaría primero el **DNS**. El ping a una IP demuestra que la interfaz, la dirección, las rutas y el gateway funcionan; lo único adicional que requiere `ping google.com` es traducir el nombre a una dirección IP.

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

## 8. Falla y diagnóstico

## 9. Uso de OpenCode

## 10. Conclusiones
