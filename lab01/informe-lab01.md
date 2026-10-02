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

## 5. Construcción

## 6. Verificación

### Interfaces

### Direcciones

### Rutas

### Vecinos

### Conectividad

## 7. Captura y análisis de tráfico

## 8. Falla y diagnóstico

## 9. Uso de OpenCode

## 10. Conclusiones
