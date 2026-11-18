# Laboratorio 3 - Enlaces Internacionales de Internet en Bolivia

- **Estudiante:** Cristhian Tomas Silicuana Quispe
- **Materia:** ETN-1011 Laboratorio de Sistemas de Comunicación II
- **Fecha de consulta de las fuentes web:** 18/11/2026
- **Mediciones (dig, ping, RDAP, RIPEstat):** 18/11/2026, entre las 13:59 y las 14:11, desde Ubuntu 24.04 (WSL) conectado a la red de la UMSA (AS27828)

En las tablas, cuando no encontré evidencia puse "no verificable", y cuando algo es una suposición mía lo marco como inferencia.

## 1. Infraestructura de fibra

| Infraestructura identificada | Ubicación / extremos publicados | Fuente (URL) |
|---|---|---|
| Fibra terrestre 1 | ENTEL, Fibra Óptica al Pacífico: La Paz - Desaguadero (frontera con Perú) - Ilo (Perú). Desde Ilo sigue por fibra submarina hasta Lurín (Lima). Inaugurada en septiembre de 2020. | https://correodelsur.com/sociedad/20200904/inauguran-nueva-fibra-optica-del-estado-y-comprometen-mas-velocidad-de-internet-a-menor-costo.html |
| Fibra terrestre 2 | ENTEL, Corredor Sudamericano de Telecomunicaciones: Lurín (Perú) - Desaguadero - Puerto Quijarro (frontera con Brasil) - São Paulo. La fuente dice que el tramo Lima - São Paulo funciona desde 2024. | https://dplnews.com/?p=293705 y https://dplnews.com/?p=273092 |
| Cable submarino 1 | Curie, costa del Pacífico. Estación de amarre: Valparaíso, Chile (las otras son Balboa, Panamá, y El Segundo, EE. UU.). Según la ficha: dueño Google, en servicio desde 2020 Q2, 10.476 km. | https://www.submarinecablemap.com/submarine-cable/curie |
| Cable submarino 2 | EllaLink, costa del Atlántico. Estación de amarre: Fortaleza, Brasil (también llega a Sines, Portugal, entre otras). Según la ficha: dueño EllaLink, en servicio desde junio de 2021, 6.200 km. | https://www.submarinecablemap.com/submarine-cable/ellalink |

Los dos tramos terrestres los saqué de noticias sobre Entel; no los contrasté con el mapa de la UIT.

**Diferencia:** el mapa muestra por dónde pasa la fibra o el cable y dónde llega a la costa, pero no demuestra qué ISP boliviano lo usa ni cuánta capacidad tiene contratada. Por ejemplo, que exista fibra hasta Desaguadero no prueba que el tráfico de AXS o TIGO salga por ahí.

## 2. ASN y proveedores

Busqué los ASN en HE BGP (https://bgp.he.net/country/BO) y los comparé con PeeringDB. Rutas IPv4 / IPv6 (prefijos) que muestra HE para cada ISP: ENTEL 275 / 87, AXS 221 / 17, COMTECO 32 / 19, COTAS 116 / 3, TIGO 376 / 160.

| Red / servicio | ASN encontrado | Titular o nombre visible | Upstream probable (solo ISP) |
|---|---|---|---|
| ENTEL | AS6568 | EMPRESA NACIONAL DE TELECOMUNICACIONES SOCIEDAD ANONIMA | AS3356 Lumen |
| AXS | AS26210 | AXS Bolivia S. A. | AS174 Cogent |
| COMTECO | AS27839 | Comteco Ltda | |
| COTAS | AS25620 | COTAS LTDA. | |
| TIGO | AS27882 | Telefónica Celular de Bolivia S.A. | |
| Google / YouTube | AS15169 (Google), AS36040 (YouTube) | Google LLC | — |
| Netflix | AS2906 | Netflix Streaming Services | — |
| Meta / Facebook | AS32934 | Meta (Facebook, Instagram, WhatsApp) | — |
| TikTok / ByteDance | AS396986 y AS138699 | ByteDance (en PeeringDB AS396986 aparece también como TikTok) | — |

**Verificación en LACNIC RDAP** (comando `curl https://rdap.lacnic.net/rdap/autnum/<ASN>`):

- AS6568: titular registrado "EMPRESA NACIONAL DE TELECOMUNICACIONES SOCIEDAD ANONIMA". Coincide con HE. El nombre comercial "Entel" no aparece, solo la razón social.
- AS26210: titular registrado "AXS Bolivia S. A.". Coincide con HE.

**Upstreams:** los saqué de la lista de vecinos de HE (https://bgp.he.net/AS6568 y https://bgp.he.net/AS26210). Son probables, no contratos demostrados. ENTEL tiene además como vecinos a Sparkle (AS6762) y Telefónica (AS12956). AXS tiene también a Telefónica (AS12956).

**TikTok:** ByteDance tiene red propia (AS396986 y AS138699), pero eso no prueba que todo TikTok salga de esos ASN, porque también puede usar CDN de otras empresas. Eso no lo verifiqué.

## 3. Peering, tránsito y BGP

ISP elegido: ENTEL (AS6568).

| Relación entre ASN | Tipo: tránsito / peering / incierto | Evidencia (herramienta/URL) |
|---|---|---|
| AS6568 ENTEL - AS3356 Lumen | Tránsito probable. AS3356 aparece justo antes de ENTEL en 5 de los 6 AS_PATH que vi en RIPEstat, y Lumen es una red internacional muy grande. | RIPEstat, prefijo 190.129.0.0/20 y https://bgp.he.net/AS6568 |
| AS6568 ENTEL - AS6939 Hurricane Electric | Incierto (podría ser peering, porque HE tiene política de peering abierta, pero la fuente no indica el tipo). | https://bgp.he.net/AS6568 |

**PeeringDB:**

- ENTEL (https://www.peeringdb.com/net/12953): política de peering selectiva. Declara presencia en 3 IXP: PIT Bolivia, PIT Perú (Lima) y Equinix São Paulo.
- Meta (https://peeringdb.com/net/979): también está en PIT Perú (Lima) y Equinix São Paulo. Coinciden en 2 IXP con ENTEL, pero eso no prueba que tengan una sesión de peering activa.

**AS_PATH en RIPEstat** (prefijo de ENTEL 190.129.0.0/20, visto desde el colector de Londres):

```
8218 6461 3356 6568
48070 61049 174 3356 6568
6894 3257 3356 6568
31742 1299 12956 6568
35266 2914 3356 6568
917 60068 3356 6568
```

El último número es ENTEL (el que origina la ruta). Justo antes aparece Lumen (3356) en 5 caminos y Telefónica (12956) en 1. La ruta es lógica, no dice por qué ciudades ni cables pasa.

**Respuesta:** aparecer como vecino BGP no prueba un contrato ni una ruta física porque BGP solo muestra que dos redes se pasan rutas, no si una le paga a la otra ni por qué fibra van los paquetes.

## 4. Dominios y DNS

Dominios elegidos: impuestos.bo, umsa.bo, entel.bo (ISP) y bcp.com.bo (empresa privada: Banco de Crédito de Bolivia).

| Dominio | A (IP o sin respuesta) | NS (uno) | MX (uno o ausente) | TTL (s) |
|---|---|---|---|---|
| impuestos.bo | Sin respuesta (NXDOMAIN) | Sin respuesta | Sin respuesta | — |
| umsa.bo | 200.7.161.56 | jupiter.umsa.bo | aspmx.l.google.com | 3600 |
| ISP elegido: entel.bo | Sin respuesta (www.entel.bo sí tiene: 190.129.60.166) | ns.entelnet.bo | entel-bo.mail.protection.outlook.com | 53 (www.entel.bo) |
| Empresa privada: bcp.com.bo | 170.245.35.119 (devuelve 3 IP) | server29.bcp.com.bo | mxa-004a9b01.gslb.pphosted.com | 60 |

**AAAA, SOA y TXT de dos dominios:**

- umsa.bo: AAAA 2801:104:dc:a161::a56 (TTL 60), o sea que sí tiene IPv6. SOA: el servidor principal de la zona es marte.umsa.bo. TXT: un registro SPF (la lista de servidores que pueden mandar correo con @umsa.bo, entre ellos Google) y códigos de verificación de Google y GlobalSign.
- entel.bo: AAAA sin respuesta, no tiene IPv6 en ese nombre. SOA: el servidor principal es ns.entelnet.bo. TXT: un registro SPF que autoriza a Microsoft (outlook.com) a mandar su correo.

**Nota sobre impuestos.bo:** `dig impuestos.bo` devuelve `status: NXDOMAIN`, o sea que ese dominio no existe; también probé con `dig @1.1.1.1` y da lo mismo. El dominio real del SIN es impuestos.gob.bo, que sí tiene IP: 170.82.244.41 (TTL 300).

**Respuesta:** DNS no permite saber por sí solo en qué país está el servicio. Solo da una IP, que puede ser de una CDN o de un proxy. Por ejemplo, umsa.bo, entel.bo y bcp.com.bo son dominios bolivianos, pero su correo (MX) está en Google, Microsoft y Proofpoint.

### Ping

5 paquetes a cada dominio, desde la red de la UMSA.

| Dominio | IP resuelta | RTT promedio (ms) | Pérdida (%) | Observación |
|---|---|---:|---:|---|
| impuestos.bo | No resuelve | — | — | NXDOMAIN. Probé impuestos.gob.bo (170.82.244.41): ICMP sin respuesta, 100 % de pérdida. |
| umsa.bo | 200.7.161.56 | 13,05 | 0 | Medido desde la misma red de la UMSA. |
| ISP elegido: www.entel.bo | 190.129.60.166 | 112,38 | 0 | entel.bo no tiene IP, por eso medí www.entel.bo. Varió entre 65,5 y 143,4 ms. |

## 5. CDN usadas por servicios populares

ISP elegidos: ENTEL (AS6568) y AXS (AS26210).

| Servicio | ISP boliviano 1: evidencia | ISP boliviano 2: evidencia | ¿Caché dentro del ISP demostrada? |
|---|---|---|---|
| Netflix | ENTEL: no verificable. Los dos están en Equinix São Paulo, pero eso no prueba peering. | AXS: no verificable. AXS solo declara PIT Bolivia y Netflix no está ahí. | No |
| Google / YouTube | ENTEL: no verificable. Los dos están en Equinix São Paulo. | AXS: no verificable. | No |
| TikTok | ENTEL: no verificable. No comparten ningún IXP declarado. | AXS: no verificable. | No |
| Facebook / Meta | ENTEL: no verificable. Coinciden en PIT Lima y Equinix São Paulo, pero no hay peering declarado. | AXS: no verificable. | No |

Fuentes: PeeringDB de ENTEL (https://www.peeringdb.com/net/12953), AXS (https://www.peeringdb.com/net/12744), Netflix (https://peeringdb.com/net/457), Google (https://www.peeringdb.com/net/433), Meta (https://peeringdb.com/net/979), ByteDance (https://www.peeringdb.com/net/19428) y PIT Bolivia (https://www.peeringdb.com/ix/3333).

| CDN comercial | ASN o red encontrada | Servicio / característica identificada |
|---|---|---|
| Cloudflare | AS13335 | Usa una red anycast global y ofrece caché instalada dentro de la red del ISP si cumple requisitos. (https://www.peeringdb.com/asn/13335) |
| Fastly | AS54113 | Se presenta como plataforma "edge cloud" para entregar contenido rápido y seguro. (https://peeringdb.com/net?asn=54113) |
| Akamai | AS20940 | Política de peering abierta; está en PIT Lima, PIT Santiago e IX.br São Paulo. (https://www.peeringdb.com/asn/20940) |

**Pregunta final:** para afirmar que un ISP boliviano tiene caché de Netflix o Google haría falta una fuente específica, como un anuncio del ISP o de la plataforma, o mediciones que muestren que el contenido responde desde IPs del propio ISP. Una IP de CDN no demuestra ubicación física porque con anycast la misma IP puede responder desde servidores en distintos países.

## Observaciones

1. El dominio impuestos.bo no existe (NXDOMAIN); el del SIN es impuestos.gob.bo. Un registro que no existe también es un resultado.
2. Desde la red de la UMSA, umsa.bo respondió en 13 ms y www.entel.bo en 112 ms, aunque los dos están en Bolivia. En los AS_PATH que muestra RTSAK (https://rtsak.com/en/as-numbers/AS27828/prefixes/200.7.160.0-20), la UMSA (AS27828) aparece detrás de COMTECO (AS27839) y ENTEL (AS6568). Con solo ping no se puede saber la causa de los 112 ms; puede ser el camino o que el servidor da baja prioridad al ping (inferencia).
3. En PIT Bolivia están casi todos los ISP bolivianos, pero ninguna gran red de contenido (Google, Netflix, Meta o ByteDance). ENTEL coincide con algunas recién en Lima y São Paulo.
4. No encontré evidencia pública de caché de Netflix, Google, Meta o TikTok dentro de ENTEL o AXS, así que todo quedó como no verificable.
5. LACNIC y HE coinciden en los titulares de los ASN, pero el número de prefijos cambia según la página de HE que se mire (ENTEL: 275 rutas IPv4 en la lista del país y 254 prefijos en su ficha).
