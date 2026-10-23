# Laboratorio 2 — FRRouting en WSL/Ubuntu (un solo router)

**Estudiante:** Cristhian Tomas Silicuana Quispe
**Usuario GitHub:** Sili1000
**Fecha:** 2026-10-22

## 1. Objetivo

En este laboratorio convertí mi Ubuntu de WSL2 en un router usando FRRouting (FRR). Practiqué rutas conectadas y estáticas, guardé la configuración y comparé los comandos con los de Cisco IOS, que es lo que estoy llevando en NetAcad.

Lo principal que entendí: Linux es el que tiene las interfaces y manda los paquetes, y FRR es el que decide y administra las rutas.

## 2. Topología

```text
Windows
  └── WSL2 / Ubuntu
       └── R1: Linux + FRR
            ├── eth0     172.24.132.23/20  (interfaz de WSL, no se toca)
            └── dummy0   10.10.10.1/24     (interfaz de práctica)
```

Trabajé con un solo router. Por eso no hay vecinos OSPF ni BGP.

## 3. Entorno (Ejercicios 1 y 2)

Ubuntu 24.04.5 LTS sobre WSL2, kernel `6.6.87.2-microsoft-standard-WSL2`.

Antes de instalar revisé que systemd estuviera activo, porque FRR funciona como servicio:

```bash
ps -p 1 -o comm=
```

Me respondió `systemd`, así que no tuve que cambiar nada.

## 4. Instalación de FRR (Ejercicio 3)

```bash
sudo apt update
sudo apt install -y frr frr-pythontools
apt policy frr
```

Quedó instalada la versión `8.4.4-1.1ubuntu6.7`. En Cisco esto no existe, porque el router ya trae su sistema instalado.

## 5. Activar FRR (Ejercicio 4)

FRR no es un solo programa, son varios procesos (daemons) y cada uno hace una tarea. En el archivo `/etc/frr/daemons` se elige cuáles se encienden. Primero intenté leerlo con `grep` sin `sudo` y me salió `Permission denied`, porque es un archivo del sistema. Después lo abrí con:

```bash
sudo nano /etc/frr/daemons
```

`bgpd=no` y `ospfd=no` ya estaban en `no`, que es lo que pide la guía. Busqué las líneas `zebra=yes` y `staticd=yes` pero no estaban. Luego vi que el mismo archivo dice: *"The watchfrr, zebra and staticd daemons are always started"*. O sea que en esta versión esos dos se prenden siempre y no hay que escribirlos. Salí sin cambiar nada.

- **zebra:** le pasa las rutas de FRR a Linux y le avisa a FRR de las interfaces.
- **staticd:** maneja las rutas estáticas que escribo yo.
- **watchfrr:** vigila que los otros procesos sigan funcionando.

Luego encendí el servicio y revisé su estado:

```bash
sudo systemctl enable --now frr
sudo systemctl status frr --no-pager
```

Salió `Active: active (running)` y se veían corriendo `watchfrr`, `zebra` y `staticd`. También apareció `Cannot stop zebra`. No impidió que FRR arrancara, porque después salió `Started frr.service` y zebra estaba corriendo.

## 6. Consola vtysh (Ejercicio 5)

`vtysh` es la consola de FRR y se parece mucho a la de Cisco. Entré con `sudo vtysh` (el indicador cambió a `DESKTOP-9JRP8JA#`) y probé:

```text
show version          → FRRouting 8.4.4
show interface        → eth0 y lo con "is up, line protocol is up"
show ip route         → las redes de eth0 y lo como C (conectadas)
show running-config   → casi vacío, todavía no había configurado nada
```

Lo que me llamó la atención:

- FRR no crea interfaces, ve las mismas que Linux.
- En `show ip route` no aparece la ruta `default` hacia internet, aunque Linux sí la tiene (`default via 172.24.128.1 dev eth0`). No la toqué.
- En `show running-config` aparece `no ip forwarding`, es decir, todavía no reenvía paquetes entre redes. Para este laboratorio no hace falta.

Para salir de vtysh se usa `exit`. Dentro de vtysh no funcionan los comandos de Linux y afuera no funcionan los `show`.

## 7. Interfaz de práctica dummy0 (Ejercicio 6)

Como solo tengo `eth0`, creé una interfaz virtual para tener una red de prueba. Esto se hace en Linux, no en FRR:

```bash
sudo ip link add dummy0 type dummy
sudo ip addr add 10.10.10.1/24 dev dummy0
sudo ip link set dummy0 up
ip -br addr show dummy0
```

```text
dummy0   UNKNOWN   10.10.10.1/24
```

`UNKNOWN` es normal porque no tiene cable real, igual que el `lo` del Lab 1. Para mí `dummy0` es parecida a una Loopback de Cisco. En Cisco serían `interface Loopback0`, `ip address 10.10.10.1 255.255.255.0` y `no shutdown`. La diferencia es que en Cisco todo se configura dentro del router, y aquí las IP se ponen en Linux.

## 8. Ruta conectada (Ejercicio 7)

```bash
ip -4 route show dev dummy0
sudo vtysh -c 'show ip route connected'
```

```text
C>* 10.10.10.0/24 is directly connected, dummy0
```

La ruta apareció sola al poner la IP y encender la interfaz. Yo la creé en Linux, pero FRR también la ve porque zebra le avisa. En Cisco pasa lo mismo: al configurar una interfaz aparece una **C** en `show ip route`.

## 9. Ruta estática blackhole (Ejercicios 8 y 9)

Como no tengo otro router al que mandar paquetes, la guía usa una ruta `blackhole`, que manda los paquetes "a la basura". La red `198.51.100.0/24` está reservada para ejemplos.

```text
sudo vtysh
conf t
ip route 198.51.100.0/24 blackhole
end
show ip route 198.51.100.0/24
```

```text
Known via "static", distance 1, metric 0, best
* unreachable (blackhole)
```

Usé `conf t`, como en Cisco, y FRR lo aceptó. La distancia administrativa es 1, igual que una ruta estática en Cisco. En Cisco sería `ip route 198.51.100.0 255.255.255.0 Null0`. La diferencia es que FRR acepta la máscara como `/24`.

Después revisé si Linux también tenía la ruta:

```bash
ip -4 route show 198.51.100.0/24
```

```text
blackhole 198.51.100.0/24 proto static metric 20
```

Sí la tenía. Entonces el camino fue: la escribí en FRR, staticd la recibió, zebra se la pasó a Linux y Linux la instaló.

## 10. Guardar la configuración (Ejercicios 10 y 11)

```text
show running-config   → ya aparece "ip route 198.51.100.0/24 blackhole"
show ip route static  → S>* 198.51.100.0/24 [1/0] unreachable (blackhole)
write memory          → Integrated configuration saved to /etc/frr/frr.conf [OK]
```

El `[1/0]` es distancia administrativa / métrica, igual que en Cisco. Comprobé que se guardó en el archivo:

```bash
sudo grep -n "198.51.100.0" /etc/frr/frr.conf
```

```text
10:ip route 198.51.100.0/24 blackhole
```

`write memory` es como `copy running-config startup-config` de Cisco, y `/etc/frr/frr.conf` sería la startup-config. Pero solo guarda lo de FRR: **no guarda `dummy0`**, porque esa interfaz la creé en Linux. Por eso, si se reinicia WSL, la ruta debería volver (está en frr.conf), pero dummy0 habría que crearla de nuevo.

## 11. Borrar y restaurar la ruta (Ejercicio 12)

```text
conf t
no ip route 198.51.100.0/24 blackhole
end
show ip route 198.51.100.0/24   → % Network not in table
```

La ruta desapareció. Luego la volví a poner con el mismo comando sin el `no`. Funciona igual que en Cisco.

## 12. Prueba del descarte (Ejercicio 13)

```bash
ip route get 198.51.100.10
ping -c 2 198.51.100.10
```

```text
RTNETLINK answers: Invalid argument
ping: connect: Invalid argument
```

Al principio pensé que era un error, pero es lo esperado: Linux encuentra la ruta blackhole y no envía el paquete, lo descarta y devuelve ese mensaje. Con una ruta a `Null0` en Cisco el ping también falla.