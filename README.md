<<<<<<< HEAD
# sistema-pagos-cluster
=======
# Infraestructura de Cluster Redis para Sistema de Pagos

Este proyecto contiene la infraestructura de Terraform para desplegar un cluster de Redis en AWS utilizando ElastiCache, diseñado específicamente para soportar el sistema de pagos y catálogo de servicios.

## Arquitectura

La infraestructura creada incluye:

- **VPC dedicada** con subnets privadas para alta disponibilidad
- **Cluster Redis** con configuración de alta disponibilidad y replicación
- **Security Groups** configurados para acceso seguro
- **Encriptación** tanto en tránsito como en reposo
- **Backups automáticos** con retención de 7 días

## Requisitos Previos

- Terraform >= 1.0
- AWS CLI configurado con permisos adecuados
- Node.js y npm (para scripts de prueba)

## Configuración

1. **Clonar o copiar este repositorio**
2. **Copiar el archivo de variables de ejemplo:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Editar `terraform.tfvars` con tus valores:**
   ```hcl
   aws_region = "us-east-1"
   environment = "production"
   redis_node_type = "cache.t3.micro"
   redis_num_nodes = 2
   redis_auth_token = "tu-token-seguro-generado"
   ```

   **Importante:** Genera un token seguro con:
   ```bash
   openssl rand -base64 32
   ```

## Despliegue

1. **Inicializar Terraform:**
   ```bash
   terraform init
   ```

2. **Revisar el plan de despliegue:**
   ```bash
   terraform plan
   ```

3. **Aplicar la infraestructura:**
   ```bash
   terraform apply
   ```

## Configuración para Lambda Functions

Una vez desplegado, obtén los valores de conexión:

```bash
terraform output
```

Los valores importantes para tu compañero son:

- **redis_endpoint**: Endpoint del cluster Redis
- **redis_port**: Puerto (6379)
- **redis_auth_token**: Token de autenticación

### Ejemplo de configuración para Lambda (Node.js)

```javascript
const redis = require('redis');

const client = redis.createClient({
  host: 'tu-endpoint-redis.xxxxxx.use1.cache.amazonaws.com',
  port: 6379,
  password: 'tu-auth-token',
  tls: {} // Requerido para encriptación en tránsito
});

// Ejemplo de guardar datos del catálogo
async function guardarCatalogo(datosCSV) {
  // Limpiar catálogo existente
  await client.flushdb();
  
  // Guardar nuevos datos
  for (const item of datosCSV) {
    await client.hset(`catalogo:${item.id}`, {
      id: item.id,
      categoria: item.categoria,
      proveedor: item.proveedor,
      servicio: item.servicio,
      plan: item.plan,
      precio_mensual: item.precio_mensual,
      detalles: item.detalles,
      estado: item.estado
    });
  }
}

// Ejemplo de obtener catálogo completo
async function obtenerCatalogo() {
  const keys = await client.keys('catalogo:*');
  const catalogo = [];
  
  for (const key of keys) {
    const item = await client.hgetall(key);
    catalogo.push(item);
  }
  
  return catalogo;
}
```

## Estructura de Datos en Redis

Los datos del catálogo se almacenarán en Redis usando hashes:

```
Key: catalogo:1
Fields:
  - id: "1"
  - categoria: "Energía"
  - proveedor: "Empresa Eléctrica Nacional"
  - servicio: "Luz Residencial"
  - plan: "Básico"
  - precio_mensual: "45000"
  - detalles: "150 kWh incluidos"
  - estado: "Activo"
```

## Monitoreo y Mantenimiento

### Verificar estado del cluster
```bash
aws elasticache describe-replication-groups --replication-group-id sistema-pagos-cluster
```

### Conectarse al cluster (para pruebas)
```bash
redis-cli -h tu-endpoint-redis -p 6379 -a tu-auth-token --tls
```

### Verificar datos
```bash
# Ver todas las keys
KEYS catalogo:*

# Ver un item específico
HGETALL catalogo:1
```

## Costos Estimados

Los costos mensuales aproximados (us-east-1):

- **cache.t3.micro** (2 nodos): ~$25-30 USD
- **Transferencia de datos**: Variable según uso
- **Backups**: Incluidos en el precio

Para producción, considera usar instancias más grandes como `cache.t3.small` o `cache.r5.large`.

## Seguridad

- El cluster está configurado con encriptación en tránsito y reposo
- Autenticación mediante token
- Security groups restringidos (ajustar según necesidades)
- VPC aislada

## Escalabilidad

Para escalar el cluster:

1. **Vertical**: Cambiar `redis_node_type` a una instancia más grande
2. **Horizontal**: Incrementar `redis_num_nodes` (máximo 6 para cluster mode)

## Soporte

Para problemas o preguntas:

1. Revisa los logs de CloudWatch para ElastiCache
2. Verifica la configuración de security groups
3. Confirma la conectividad desde las Lambdas

## Destrucción

Para eliminar toda la infraestructura:
```bash
terraform destroy
```

**Advertencia:** Esto eliminará todos los datos del cluster Redis del sistema de pagos.
>>>>>>> develop
