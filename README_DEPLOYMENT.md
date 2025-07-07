# GenAI Stack - Despliegue en 3 VPS con Docker Swarm

Este documento proporciona una guía completa para orquestar el despliegue del GenAI Stack en 3 servidores VPS utilizando Docker Swarm.

## 📋 Arquitectura del Sistema

### Distribución de Servicios

**Nodo Manager (VPS 1):**
- Neo4j Database
- Nginx Load Balancer
- Prometheus Monitoring
- Grafana Dashboard
- Loader Service

**Nodo Worker 1 (VPS 2):**
- Ollama LLM Service
- API Service (1-2 réplicas)
- Support Bot Service
- Frontend Service

**Nodo Worker 2 (VPS 3):**
- Ollama LLM Service
- PDF Bot Service
- API Service (1-2 réplicas)
- Frontend Service

## 🚀 Guía de Despliegue Rápido

### 1. Preparación de VPS

**Requisitos mínimos por VPS:**
- 4 GB RAM
- 2 CPU cores
- 50 GB almacenamiento
- Ubuntu 20.04+ o CentOS 7+
- Acceso SSH con clave pública

### 2. Configuración del Cluster

```bash
# Hacer ejecutable el script de configuración
chmod +x deploy/setup-swarm.sh

# Ejecutar configuración del cluster
./deploy/setup-swarm.sh
```

El script te pedirá:
- IP del nodo manager
- IP del worker 1
- IP del worker 2
- Ruta de la clave SSH

### 3. Despliegue de la Aplicación

```bash
# SSH al nodo manager
ssh -i ~/.ssh/your-key root@manager-ip

# Navegar al directorio de la aplicación
cd /opt/genai-stack

# Configurar variables de entorno
cp env.production .env
nano .env  # Editar con tus configuraciones

# Desplegar el stack
./deploy/deploy-stack.sh
```

## 🔧 Configuración Detallada

### Variables de Entorno Críticas

```bash
# Base de datos
NEO4J_PASSWORD=tu_contraseña_segura
NEO4J_URI=neo4j://database:7687

# Modelos de IA
LLM=llama2
EMBEDDING_MODEL=sentence_transformer
OLLAMA_BASE_URL=http://llm:11434

# APIs opcionales
OPENAI_API_KEY=sk-tu-clave-openai
GOOGLE_API_KEY=tu-clave-google

# Monitoreo
GRAFANA_PASSWORD=tu_contraseña_grafana
```

### Configuración de SSL

```bash
# Generar certificados SSL personalizados
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem \
  -subj "/C=ES/ST=State/L=City/O=Organization/CN=tu-dominio.com"
```

## 📊 Monitoreo y Gestión

### URLs de Acceso

- **Aplicación Principal:** `https://tu-dominio.com`
- **Support Bot:** `https://tu-dominio.com/bot`
- **PDF Bot:** `https://tu-dominio.com/pdf`
- **Loader:** `https://tu-dominio.com/loader`
- **API:** `https://tu-dominio.com/api`
- **Neo4j Browser:** `https://tu-dominio.com/neo4j`
- **Grafana:** `https://tu-dominio.com/grafana`
- **Prometheus:** `https://tu-dominio.com/prometheus`

### Comandos de Gestión

```bash
# Ver estado del cluster
docker node ls

# Ver servicios del stack
docker service ls

# Ver logs de un servicio
docker service logs genai_api

# Escalar un servicio
docker service scale genai_api=3

# Actualizar un servicio
docker service update genai_api

# Ver métricas en tiempo real
docker stats

# Backup de la base de datos
docker exec -it $(docker ps -q -f name=genai_database) \
  neo4j-admin backup --backup-dir=/backup --name=genai-backup
```

## 🔧 Solución de Problemas

### Servicios No Inician

```bash
# Verificar logs detallados
docker service logs --details genai_<service_name>

# Verificar recursos disponibles
docker system df
docker node ls --format "table {{.Hostname}}\t{{.Status}}\t{{.Availability}}"

# Verificar conectividad entre nodos
docker network ls
docker network inspect genai_network
```

### Problemas de Rendimiento

```bash
# Monitorear recursos por nodo
docker stats --no-stream

# Verificar límites de memoria
docker service inspect genai_api --format='{{.Spec.TaskTemplate.Resources.Limits.MemoryBytes}}'

# Ajustar recursos
docker service update --limit-memory=2G genai_api
```

### Problemas de Red

```bash
# Verificar puertos abiertos
netstat -tulpn | grep :80
netstat -tulpn | grep :443

# Verificar conectividad entre servicios
docker exec -it $(docker ps -q -f name=genai_api) ping database
```

## 🛡️ Seguridad

### Configuración del Firewall

```bash
# Permitir puertos necesarios
ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw allow 2377/tcp    # Docker Swarm
ufw allow 7946/tcp    # Docker Swarm
ufw allow 4789/udp    # Docker Overlay
ufw enable
```

### Hardening del Sistema

```bash
# Actualizar sistema
apt update && apt upgrade -y

# Configurar fail2ban
apt install fail2ban -y
systemctl enable fail2ban
systemctl start fail2ban

# Configurar logrotate para Docker
cat > /etc/logrotate.d/docker << EOF
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        systemctl reload docker
    endscript
}
EOF
```

## 📈 Optimización de Rendimiento

### Ajustes de Neo4j

```bash
# En el archivo .env
NEO4J_dbms_memory_heap_initial__size=1G
NEO4J_dbms_memory_heap_max__size=2G
NEO4J_dbms_memory_pagecache_size=1G
NEO4J_dbms_query_cache_size=100M
```

### Configuración de Nginx

```bash
# Aumentar worker_connections en nginx.conf
worker_connections 2048;

# Habilitar compresión
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_comp_level 6;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
```

### Optimización de Docker

```bash
# Configurar límites de log
cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl restart docker
```

## 🔄 Backup y Recuperación

### Backup Automatizado

```bash
# Crear script de backup
cat > /opt/backup-genai.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Crear directorio de backup
mkdir -p $BACKUP_DIR

# Backup de Neo4j
docker exec -it $(docker ps -q -f name=genai_database) \
  neo4j-admin backup --backup-dir=/backup --name=genai-$DATE

# Backup de configuraciones
tar -czf $BACKUP_DIR/config-$DATE.tar.gz \
  /opt/genai-stack/.env \
  /opt/genai-stack/nginx/ \
  /opt/genai-stack/monitoring/

# Limpiar backups antiguos (mantener 7 días)
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
EOF

chmod +x /opt/backup-genai.sh

# Programar backup diario
echo "0 2 * * * /opt/backup-genai.sh" | crontab -
```

### Recuperación de Desastres

```bash
# Restaurar desde backup
./deploy/deploy-stack.sh --remove
docker volume rm genai_neo4j_data
# Restaurar datos
# Redesplegar
./deploy/deploy-stack.sh
```

## 📚 Comandos Útiles

```bash
# Comandos de gestión del stack
./deploy/deploy-stack.sh --help
./deploy/deploy-stack.sh --status
./deploy/deploy-stack.sh --update
./deploy/deploy-stack.sh --logs api
./deploy/deploy-stack.sh --remove

# Comandos de Docker Swarm
docker stack ls
docker stack ps genai
docker service ls
docker service ps genai_api
docker node ls
docker node inspect manager

# Comandos de monitoreo
docker system df
docker system prune
docker stats
docker service logs -f genai_api
```

## 🎯 Próximos Pasos

1. **Configurar SSL con Let's Encrypt**
2. **Implementar CI/CD con GitHub Actions**
3. **Configurar alertas en Grafana**
4. **Implementar backup automático a S3**
5. **Configurar escalado automático**

## 🆘 Soporte

Si encuentras problemas durante el despliegue:

1. Verifica los logs de servicios
2. Revisa la conectividad de red
3. Confirma los recursos disponibles
4. Consulta la documentación de Docker Swarm

¡El sistema está listo para orquestar el despliegue en tus 3 VPS! 🚀