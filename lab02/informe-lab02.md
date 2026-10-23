# Laboratorio 2 — FRRouting en WSL/Ubuntu (un solo router)

**Estudiante:** Cristhian Tomas Silicuana Quispe
**Usuario GitHub:** Sili1000
**Fecha:** 2026-10-23

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

Trabajé en Ubuntu 24.04.5 LTS sobre WSL2, el mismo del Lab 1.

```bash
whoami
uname -r
```

```text
cristhian
6.6.87.2-microsoft-standard-WSL2
```

Antes de instalar revisé que systemd estuviera activo, porque FRR funciona como servicio:

```bash
ps -p 1 -o comm=
```

Me respondió `systemd`, así que no tuve que cambiar nada.

Interfaces y rutas de Linux:

```bash
ip -br addr
ip -4 route
```

```text
lo       UNKNOWN   127.0.0.1/8 10.255.255.254/32 ::1/128
eth0     UP        172.24.132.23/20 fe80::215:5dff:feb3:304c/64
dummy0   UNKNOWN   10.10.10.1/24 fe80::4cd0:c8ff:fefd:dabe/64

default via 172.24.128.1 dev eth0 proto kernel
10.10.10.0/24 dev dummy0 proto kernel scope link src 10.10.10.1
172.24.128.0/20 dev eth0 proto kernel scope link src 172.24.132.23
blackhole 198.51.100.0/24 proto static metric 20
```

Estos dos comandos los ejecuté al final del laboratorio, por eso ya aparecen `dummy0` y la ruta `blackhole` que configuré después. La interfaz de WSL es `eth0` y la ruta `default` va por `172.24.128.1`. No las modifiqué.

En Cisco serían `show ip interface brief` y `show ip route`.

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

Salió `Active: active (running)` y se veían corriendo `watchfrr`, `zebra` y `staticd`. También apareció `Cannot stop zebra`. No impidió que FRR arrancara, porque después salió `Started frr.service` y zebra estaba corriendo. Lo que significaba lo entendí después con los logs (sección 14).

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
- En `show ip route` de FRR no aparece la ruta `default` hacia internet, aunque Linux sí la tiene (`default via 172.24.128.1 dev eth0`, sección 3). No la toqué.
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

En Linux:

```text
10.10.10.0/24 proto kernel scope link src 10.10.10.1
```

En FRR:

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

## 13. Contadores de la interfaz (Ejercicio 14)

```bash
ip -s link show dummy0
sudo vtysh -c 'show interface dummy0'
```

```text
dummy0: <BROADCAST,NOARP,UP,LOWER_UP>
RX:  bytes packets errors dropped
         0       0      0       0
TX:  bytes packets errors dropped
       630       9      0       0
```

RX (recibido) está en 0 porque dummy0 no está conectada a nada, así que nadie le puede mandar paquetes. TX (enviado) tiene 9 paquetes, probablemente mensajes automáticos de IPv6 que Linux manda al encender una interfaz. También dice `NOARP`: dummy0 no usa ARP porque no tiene a quién preguntarle una MAC, a diferencia del veth del Lab 1.

Desde FRR sale `Interface dummy0 is up, line protocol is up`, y además FRR guardó cuándo se cayó y cuándo se levantó:

```text
Link ups:       1    last: 2026/10/22 23:25:02
Link downs:     1    last: 2026/10/22 23:24:17
```

Coincide con lo que hice: dummy0 se creó apagada y unos segundos después la encendí.

En Cisco esto se ve con `show interfaces Loopback0` (packets input y packets output).

## 14. Logs de FRR (Ejercicio 15)

```bash
sudo journalctl -u frr -n 20 --no-pager
```

```text
22:55:20 watchfrr: zebra state -> down : initial connection attempt failed
22:55:20 watchfrr: staticd state -> down : initial connection attempt failed
22:55:20 watchfrr: Forked background command: watchfrr.sh restart all
22:55:20 watchfrr.sh: Cannot stop zebra: pid file not found
22:55:20 watchfrr: zebra state -> up : connect succeeded
22:55:20 watchfrr: staticd state -> up : connect succeeded
22:55:20 systemd: Started frr.service - FRRouting.
23:37:35 watchfrr: configuration write completed with exit code 0
```

Con el log entendí el mensaje `Cannot stop zebra` que vi en la sección 5. Al arrancar, watchfrr vio que zebra y staticd todavía no estaban corriendo y mandó reiniciarlos. Para reiniciar primero intentó apagar zebra, pero como aún no existía no había nada que apagar. Después los dos quedaron `up`.

La última línea (23:37:35) es mi `write memory` de la sección 10; `exit code 0` significa que se guardó sin errores.

En Cisco el equivalente es `show logging`.

## 15. OSPF con un solo router (Ejercicio 16)

Primero pregunté por vecinos OSPF:

```bash
sudo vtysh -c 'show ip ospf neighbor'
```

```text
ospfd is not running
```

Tiene sentido porque en `/etc/frr/daemons` estaba `ospfd=no`. Lo activé y reinicié FRR:

```bash
sudo sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons
sudo grep "^ospfd=" /etc/frr/daemons
sudo systemctl restart frr
```

`sed` funciona como un buscar y reemplazar: cambió `ospfd=no` por `ospfd=yes` sin abrir el archivo. El `grep` confirmó `ospfd=yes`.

Después configuré OSPF en vtysh:

```text
conf t
router ospf
 network 10.10.10.0/24 area 0
end
show ip ospf interface
show ip ospf neighbor
```

En Cisco sería `router ospf 1` y `network 10.10.10.0 0.0.0.255 area 0`. En FRR no se pone número de proceso y se usa `/24` en vez de wildcard.

Resultado de `show ip ospf interface`:

```text
dummy0 is up
  Internet Address 10.10.10.1/24, Broadcast 10.10.10.255, Area 0.0.0.0
  Router ID 10.255.255.254, Network Type BROADCAST, Cost: 10
  Transmit Delay is 1 sec, State Waiting, Priority 1
  Timer intervals configured, Hello 10s, Dead 40s, Wait 40s, Retransmit 5
  Neighbor Count is 0, Adjacent neighbor count is 0
```

- OSPF quedó activo en dummy0, en el área 0.
- El Router ID se eligió solo (`10.255.255.254`), porque no configuré uno.
- `State Waiting`: está esperando para elegir DR, pero no hay otro router.
- Manda un Hello cada 10 s y espera 40 s antes de dar por muerto a un vecino.
- `Neighbor Count is 0`.

`show ip ospf neighbor` salió con la tabla vacía, solo con los títulos. OSPF necesita otro router en la misma red que responda los Hello para formar adyacencia, y aquí hay uno solo. Esta configuración de OSPF no la guardé con `write memory` porque la guía no lo pedía.

## 16. Preguntas de evaluación

1. **¿Qué diferencia hay entre FRR y el kernel Linux?** FRR decide y administra las rutas. El kernel de Linux es el que guarda la tabla de rutas y envía los paquetes. Lo vi con la ruta blackhole: la escribí en FRR y apareció en Linux como `proto static`.
2. **¿Qué función cumple zebra?** Es el intermediario entre FRR y Linux. Le pasa a Linux las rutas de FRR y le avisa a FRR de las interfaces y rutas de Linux. Por eso FRR vio `dummy0` aunque la creé con `ip`.
3. **¿Qué diferencia hay entre `show ip route` e `ip -4 route`?** `show ip route` es la vista de FRR y `ip -4 route` es la vista de Linux. Con la ruta blackhole, FRR mostraba `Known via "static"` y Linux mostraba `blackhole ... proto static metric 20`. Además, la ruta `default` aparece en Linux pero no en FRR.
4. **¿Qué conserva `write memory`?** La configuración de FRR, que queda en `/etc/frr/frr.conf`. No guarda `dummy0` porque esa interfaz es de Linux.
5. **¿Por qué no aparecen vecinos OSPF?** Porque hay un solo router. OSPF necesita otro router en la misma red que responda los Hello.
6. **¿Qué hace una ruta blackhole?** Descarta los paquetes que van a esa red. Al hacer `ping 198.51.100.10` el paquete ni siquiera salió (`Invalid argument`).
7. **¿Cuál es el equivalente de `write memory` en Cisco IOS?** `copy running-config startup-config`.
8. **¿Por qué la IP se configura fuera de vtysh en este laboratorio?** Porque las interfaces y sus direcciones las maneja Linux. FRR solo se encarga de las rutas y los protocolos. En Cisco, en cambio, todo se configura dentro del router.

## 17. Uso de IA

Usé un asistente de IA (Claude) para que me explicara los comandos en palabras simples y comparándolos con Cisco IOS, y para ordenar el informe. Las salidas son las que obtuve en mi terminal, y verifiqué cada explicación con ellas. Por ejemplo, el significado de `Cannot stop zebra` lo confirmé recién al leer los logs.

## 18. Conclusiones

- En Linux, el router se divide en dos partes: Linux tiene las interfaces y manda los paquetes, y FRR decide las rutas. Zebra es el que conecta las dos.
- Los comandos de FRR se parecen mucho a Cisco (`conf t`, `show ip route`, `no`, `[1/0]`), pero hay diferencias: la máscara se escribe como `/24`, la ruta de descarte se llama `blackhole` en vez de `Null0` y se guarda con `write memory`.
- Una ruta conectada aparece sola al poner la IP y encender la interfaz, y una estática la tengo que escribir yo.
- `write memory` solo guarda lo de FRR. Lo que hago con `ip` en Linux, como `dummy0`, se pierde al reiniciar WSL.
- Los logs me ayudaron a entender un mensaje que al principio parecía un error (`Cannot stop zebra`).
- Con un solo router OSPF se puede configurar, pero no forma vecinos. Para eso se necesita un segundo router, por ejemplo usando namespaces como en el Lab 1.

## Anexo: demostración después de reiniciar la máquina

Al apagar la laptop, FRR sigue instalado y arranca solo (`systemctl enable`), y la ruta blackhole sigue porque la guardé con `write memory`. Lo que se pierde es `dummy0` (creada con `ip`) y la configuración de OSPF (no la guardé). Orden para la demostración:

### 1. Comprobar que FRR está encendido

```bash
cd ~/2026-s2
sudo systemctl status frr --no-pager
```

Debe decir `active (running)`.

### 2. Volver a crear dummy0

```bash
sudo ip link add dummy0 type dummy
sudo ip addr add 10.10.10.1/24 dev dummy0
sudo ip link set dummy0 up
ip -br addr show dummy0
```

Si sale `File exists`, dummy0 ya existe y se sigue al paso 3.

### 3. Ver rutas en FRR y en Linux

```bash
sudo vtysh -c 'show ip route'
ip -4 route
```

Deben aparecer `C>* 10.10.10.0/24 ... dummy0` y `S>* 198.51.100.0/24 ... blackhole` (la ruta sigue porque estaba guardada en frr.conf).

### 4. Borrar y restaurar la ruta estática

```text
sudo vtysh
conf t
no ip route 198.51.100.0/24 blackhole
end
show ip route 198.51.100.0/24
conf t
ip route 198.51.100.0/24 blackhole
end
write memory
exit
```

### 5. Probar el descarte

```bash
ip route get 198.51.100.10
ping -c 2 198.51.100.10
```

Debe salir `Invalid argument`.

### 6. OSPF sin vecinos

```text
sudo vtysh
conf t
router ospf
 network 10.10.10.0/24 area 0
end
show ip ospf interface
show ip ospf neighbor
exit
```

Debe salir `Neighbor Count is 0` y la tabla de vecinos vacía.

### Si algo falla

| Error | Qué hacer |
|---|---|
| `File exists` al crear dummy0 | Ya existe, seguir al siguiente paso |
| `ospfd is not running` | Revisar `sudo grep "^ospfd=" /etc/frr/daemons` y `sudo systemctl restart frr` |
| `active` no aparece | `sudo systemctl restart frr` y ver logs con `sudo journalctl -u frr -n 20 --no-pager` |
| vtysh no responde a comandos de Linux | Salir con `exit`: dentro de vtysh solo funcionan los comandos de FRR |

No hice la limpieza de la guía (borrar dummy0 y la ruta) para poder hacer la demostración en la defensa.