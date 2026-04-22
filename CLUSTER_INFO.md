# Estructura del Cluster Redis - Sistema de Pagos

## Información General del Cluster

### Datos de Conexión
- **Endpoint Principal**: `master.sistema-pagos-cluster.oofk4z.use1.cache.amazonaws.com`
- **Puerto**: `6379`
- **Token de Autenticación**: `SistemaPagos2024Token`
- **Connection String**: `redis://master.sistema-pagos-cluster.oofk4z.use1.cache.amazonaws.com:6379`

### Configuración de Red
- **VPC ID**: `vpc-0ae3d0b7ff67195b2`
- **Security Group ID**: `sg-0277d7759f5e00925`
- **Región**: `us-east-1`
- **Availability Zones**: `us-east-1a`, `us-east-1b`

## Arquitectura Implementada

### Componentes de Infraestructura
```
sistema-pagos-cluster/
  main.tf                 # Configuración principal de Terraform
  variables.tf            # Variables configurables
  outputs.tf              # Outputs de conexión
  terraform.tfvars        # Valores específicos del despliegue
  test-redis.js           # Scripts de prueba
  package.json            # Dependencias Node.js
  README.md               # Documentación completa
```

### Recursos AWS Creados

#### 1. VPC y Networking
- **VPC**: `sistema-pagos-vpc` (10.0.0.0/16)
- **Subnet 1**: `sistema-pagos-subnet-1` (10.0.1.0/24) - us-east-1a
- **Subnet 2**: `sistema-pagos-subnet-2` (10.0.2.0/24) - us-east-1b
- **Security Group**: `sistema-pagos-security-group`

#### 2. Cluster ElastiCache Redis
- **Replication Group ID**: `sistema-pagos-cluster`
- **Engine**: Redis 7.x
- **Tipo de Instancia**: `cache.t3.micro`
- **Número de Nodos**: 2 (1 primario + 1 réplica)
- **Modo**: Replication Group (no cluster mode)

#### 3. Configuración de Seguridad
- **Encriptación en Tránsito**: Activada (TLS requerido)
- **Encriptación en Reposo**: Activada
- **Autenticación**: Activada con token
- **Multi-AZ**: Activado para alta disponibilidad
- **Failover Automático**: Activado

## Configuración para Lambda Functions

### Variables de Entorno para Lambda
```javascript
const REDIS_CONFIG = {
  host: process.env.REDIS_ENDPOINT || "master.sistema-pagos-cluster.oofk4z.use1.cache.amazonaws.com",
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_AUTH_TOKEN || "SistemaPagos2024Token",
  tls: {}, // Requerido para encriptación
  retryDelayOnFailover: 100,
  enableReadyCheck: false,
  maxRetriesPerRequest: 3
};
```

### Ejemplo de Conexión (Node.js)
```javascript
const redis = require('redis');

async function createRedisClient() {
  const client = redis.createClient({
    host: 'master.sistema-pagos-cluster.oofk4z.use1.cache.amazonaws.com',
    port: 6379,
    password: 'SistemaPagos2024Token',
    tls: {}
  });

  client.on('error', (err) => {
    console.error('Error de conexión Redis:', err);
  });

  await client.connect();
  return client;
}
```

## Estructura de Datos en Redis

### Formato de Almacenamiento
Los datos del catálogo se almacenan como hashes con la siguiente estructura:

```
Key: catalogo:{id}
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

### Operaciones CRUD

#### Guardar/Actualizar Item
```javascript
async function guardarItem(client, item) {
  await client.hSet(`catalogo:${item.id}`, {
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
```

#### Obtener Item Específico
```javascript
async function obtenerItem(client, id) {
  return await client.hGetAll(`catalogo:${id}`);
}
```

#### Obtener Todo el Catálogo
```javascript
async function obtenerCatalogoCompleto(client) {
  const keys = await client.keys('catalogo:*');
  const catalogo = [];
  
  for (const key of keys) {
    const item = await client.hGetAll(key);
    catalogo.push(item);
  }
  
  return catalogo;
}
```

#### Eliminar Item
```javascript
async function eliminarItem(client, id) {
  return await client.del(`catalogo:${id}`);
}
```

#### Limpiar Catálogo Completo
```javascript
async function limpiarCatalogo(client) {
  await client.flushDb();
}
```

## Flujo de Implementación para Lambda Functions

### 1. POST /catalog/update (upload-catalog)
```javascript
exports.handler = async (event) => {
  const client = await createRedisClient();
  
  try {
    // 1. Procesar archivo CSV/Excel
    const datos = await procesarArchivo(event);
    
    // 2. Limpiar catálogo existente
    await client.flushDb();
    
    // 3. Guardar nuevos datos
    for (const item of datos) {
      await client.hSet(`catalogo:${item.id}`, item);
    }
    
    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Catálogo actualizado exitosamente' })
    };
  } catch (error) {
    console.error('Error:', error);
    throw error;
  } finally {
    await client.quit();
  }
};
```

### 2. GET /catalog (catalogo-servicios)
```javascript
exports.handler = async (event) => {
  const client = await createRedisClient();
  
  try {
    const keys = await client.keys('catalogo:*');
    const catalogo = [];
    
    for (const key of keys) {
      const item = await client.hGetAll(key);
      catalogo.push({
        id: parseInt(item.id),
        categoria: item.categoria,
        proveedor: item.proveedor,
        servicio: item.servicio,
        plan: item.plan,
        precio_mensual: parseInt(item.precio_mensual),
        detalles: item.detalles,
        estado: item.estado
      });
    }
    
    return {
      statusCode: 200,
      body: JSON.stringify(catalogo)
    };
  } catch (error) {
    console.error('Error:', error);
    throw error;
  } finally {
    await client.quit();
  }
};
```

## Configuración de Seguridad

### IAM Role para Lambda Functions
La Lambda necesita permisos para:
- Acceder a ElastiCache (desde la VPC)
- Acceder a S3 (para archivos CSV)
- Logging en CloudWatch

### Security Group Rules
- **Inbound**: Puerto 6379 desde la VPC (0.0.0.0/0 para pruebas)
- **Outbound**: Todo el tráfico permitido

## Monitoreo y Troubleshooting

### Verificar Estado del Cluster
```bash
aws elasticache describe-replication-groups --replication-group-id sistema-pagos-cluster
```

### Conexión de Prueba
```javascript
// Usar el script test-redis.js incluido
npm install redis
node test-redis.js
```

### Logs y Métricas
- **CloudWatch**: Métricas de ElastiCache
- **Eventos**: Failover automático, snapshots
- **Logs**: Slow query log (si está activado)

## Costos Estimados

### Mensuales (us-east-1)
- **cache.t3.micro × 2**: ~$25-30 USD
- **Transferencia de datos**: Variable según uso
- **Storage**: Incluido en el precio de la instancia

## Próximos Pasos para Integración

1. **Configurar Lambda VPC**: Asignar las subnets del cluster
2. **Variables de Entorno**: Configurar endpoint y token
3. **Testing**: Usar el script de prueba incluido
4. **Monitoreo**: Configurar alertas de CloudWatch
5. **Seguridad**: Restringir security groups a IPs específicas

## Contacto y Soporte

Para cualquier issue con el cluster:
1. Verificar conectividad desde Lambda
2. Revisar logs de CloudWatch
3. Validar configuración de security groups
4. Comprobar estado del cluster con AWS CLI
