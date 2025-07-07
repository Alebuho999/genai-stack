# 🚀 Sistema de Orquestación GenAI Stack - 3 VPS

## ✅ Sistema Completo Preparado

**¡Perfecto! He preparado todo el sistema de orquestación para desplegar el GenAI Stack en 3 VPS usando Docker Swarm.** 

## 📁 Archivos Creados

### 🔧 Configuración de Orquestación

1. **`docker-swarm-stack.yml`** - Archivo principal de Docker Swarm
   - Configuración completa de servicios distribuidos
   - Réplicas, recursos, y restricciones de placement
   - Load balancing y alta disponibilidad

2. **`nginx/nginx.conf`** - Load Balancer y Reverse Proxy
   - Balanceador de carga con SSL/HTTPS
   - Configuración de upstream para todos los servicios
   - Rate limiting y headers de seguridad

3. **`env.production`** - Variables de entorno optimizadas
   - Configuración de producción para 3 VPS
   - Todas las variables necesarias comentadas

### 🛠️ Scripts de Despliegue

4. **`deploy/setup-swarm.sh`** - Configuración inicial del cluster
   - Instala Docker en los 3 VPS
   - Configura Docker Swarm
   - Etiqueta nodos y configura SSL

5. **`deploy/deploy-stack.sh`** - Despliegue del stack
   - Construye imágenes Docker
   - Despliega servicios en el cluster
   - Opciones para actualizar, monitorear, etc.

### 📊 Monitoreo y Observabilidad

6. **`monitoring/prometheus.yml`** - Configuración de Prometheus
   - Métricas de todos los servicios
   - Monitoreo de Docker Swarm
   - Configuración de alertas

7. **`monitoring/grafana/datasources/prometheus.yml`** - Datasource de Grafana
   - Conexión automática a Prometheus
   - Configuración de alertas

### 📖 Documentación

8. **`README_DEPLOYMENT.md`** - Guía completa de despliegue
   - Instrucciones paso a paso
   - Solución de problemas
   - Comandos útiles
   - Optimización de rendimiento

## 🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    NGINX LOAD BALANCER                         │
│                         (SSL/HTTPS)                            │
└─────────────────────────┬───────────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          │              │              │
     ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
     │ VPS 1   │    │ VPS 2   │    │ VPS 3   │
     │MANAGER  │    │WORKER-1 │    │WORKER-2 │
     └─────────┘    └─────────┘    └─────────┘
          │              │              │
     ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
     │Neo4j DB │    │Ollama   │    │Ollama   │
     │Load Bal │    │LLM      │    │LLM      │
     │Promethe │    │API x2   │    │PDF Bot  │
     │Grafana  │    │Bot      │    │API x1   │
     │Loader   │    │Frontend │    │Frontend │
     └─────────┘    └─────────┘    └─────────┘
```

## 🚀 Cómo Usar el Sistema

### 1. Configuración Inicial (Solo una vez)

```bash
# Hacer ejecutables los scripts
chmod +x deploy/*.sh

# Configurar el cluster de 3 VPS
./deploy/setup-swarm.sh
```

### 2. Despliegue del Stack

```bash
# SSH al nodo manager
ssh root@tu-manager-ip

# Ir al directorio de la aplicación
cd /opt/genai-stack

# Configurar variables de entorno
cp env.production .env
nano .env  # Editar con tus configuraciones

# Desplegar el stack completo
./deploy/deploy-stack.sh
```

### 3. Gestión del Sistema

```bash
# Ver estado del cluster
./deploy/deploy-stack.sh --status

# Ver logs de un servicio
./deploy/deploy-stack.sh --logs api

# Actualizar el stack
./deploy/deploy-stack.sh --update

# Escalar servicios
docker service scale genai_api=5
```

## 🎯 Características Principales

### ✅ Alta Disponibilidad
- **Réplicas múltiples** de servicios críticos
- **Failover automático** entre nodos
- **Load balancing** inteligente

### ✅ Escalabilidad
- **Escalado horizontal** fácil
- **Distribución automática** de carga
- **Recursos optimizados** por servicio

### ✅ Seguridad
- **SSL/HTTPS** con certificados
- **Rate limiting** en APIs
- **Firewall** y hardening del sistema

### ✅ Monitoreo
- **Prometheus** para métricas
- **Grafana** para dashboards
- **Alertas** automáticas

### ✅ Operaciones
- **Backup automático** de datos
- **Logs centralizados**
- **Deployment** con un comando

## 🔧 Servicios Distribuidos

| Servicio | Nodo | Réplicas | Puerto | Descripción |
|----------|------|----------|---------|-------------|
| Neo4j | Manager | 1 | 7474/7687 | Base de datos |
| Ollama LLM | Workers | 2 | 11434 | Modelo de IA |
| API | All | 3 | 8504 | API REST |
| Support Bot | Workers | 2 | 8501 | Chat bot |
| PDF Bot | Workers | 2 | 8503 | Procesador PDF |
| Frontend | All | 3 | 8505 | Interfaz web |
| Loader | Manager | 1 | 8502 | Carga datos |
| Nginx | Manager | 2 | 80/443 | Load balancer |
| Prometheus | Manager | 1 | 9090 | Métricas |
| Grafana | Manager | 1 | 3000 | Dashboard |

## 🌐 URLs de Acceso

Una vez desplegado, accede a:

- **🏠 Aplicación Principal:** `https://tu-dominio.com`
- **🤖 Support Bot:** `https://tu-dominio.com/bot`
- **📄 PDF Bot:** `https://tu-dominio.com/pdf`
- **⚙️ Loader:** `https://tu-dominio.com/loader`
- **🔌 API:** `https://tu-dominio.com/api`
- **🗄️ Neo4j:** `https://tu-dominio.com/neo4j`
- **📊 Grafana:** `https://tu-dominio.com/grafana`
- **📈 Prometheus:** `https://tu-dominio.com/prometheus`

## 📋 Checklist de Despliegue

- [ ] **3 VPS preparados** con Ubuntu 20.04+
- [ ] **Acceso SSH** con llaves públicas
- [ ] **Puertos abiertos** (80, 443, 2377, 7946, 4789)
- [ ] **Dominio configurado** (opcional)
- [ ] **Variables de entorno** configuradas
- [ ] **Scripts ejecutables** (`chmod +x`)

## 🎉 ¡Listo para Producción!

El sistema está **completamente preparado** para orquestar el despliegue en 3 VPS. Incluye:

- ✅ **Orquestación completa** con Docker Swarm
- ✅ **Load balancing** con Nginx
- ✅ **Monitoreo** con Prometheus + Grafana
- ✅ **Scripts automatizados** de despliegue
- ✅ **Documentación completa** en español
- ✅ **Configuración de producción** optimizada
- ✅ **Seguridad** y hardening del sistema

**¡Solo ejecuta los scripts y tendrás tu GenAI Stack corriendo en 3 VPS con alta disponibilidad!** 🚀