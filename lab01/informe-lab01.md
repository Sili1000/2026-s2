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
