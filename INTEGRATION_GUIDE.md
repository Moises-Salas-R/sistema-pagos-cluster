# Guía de Integración - Sistema de Pagos Cluster Redis

## Checklist de Verificación para tu Compañero

### 1. Verificación de Infraestructura AWS

#### Estado del Cluster Redis
```bash
# Verificar estado del cluster
aws elasticache describe-replication-groups --replication-group-id sistema-pagos-cluster

# Verificar nodos específicos
aws elasticache describe-cache-clusters --cache-cluster-id sistema-pagos-cluster-001
aws elasticache describe-cache-clusters --cache-cluster-id sistema-pagos-cluster-002
```

**Expected Output:**
- Status: `available`
- Node Groups: 1 (2 nodes: 1 primary, 1 replica)
- Encryption: enabled (transit & at-rest)
- Auth: enabled

#### Configuración de Red
```bash
# Verificar VPC
aws ec2 describe-vpcs --vpc-ids vpc-0ae3d0b7ff67195b2

# Verificar Security Groups
aws ec2 describe-security-groups --group-ids sg-0277d7759f5e00925

# Verificar Subnets
aws ec2 describe-subnets --subnet-ids subnet-096c20ec2cdcf1c6f subnet-01662b765bd74677e
```

### 2. Configuración de Lambda Functions

#### Variables de Entorno Requeridas
```bash
# Para cada Lambda function
REDIS_ENDPOINT=master.sistema-pagos-cluster.oofk4z.use1.cache.amazonaws.com
REDIS_PORT=6379
REDIS_AUTH_TOKEN=SistemaPagos2024Token
```

#### Configuración VPC
- **VPC ID**: `vpc-0ae3d0b7ff67195b2`
- **Subnets**: `subnet-096c20ec2cdcf1c6f`, `subnet-01662b765bd74677e`
- **Security Group**: `sg-0277d7759f5e00925`

#### IAM Role Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticache:Connect"
      ],
      "Resource": "arn:aws:elasticache:us-east-1:662271354434:replicationgroup:sistema-pagos-cluster"
    }
  ]
}
```

### 3. Testing de Conexión

#### Script de Prueba Básico
```javascript
const redis = require('redis');

async function testConnection() {
  const client = redis.createClient({
    host: 'master.sistema-pagos-cluster.oofk4z.use1.cache.amazonaws.com',
    port: 6379,
    password: 'SistemaPagos2024Token',
    tls: {}
  });

  try {
    await client.connect();
    
    // Test básico
    await client.set('test:key', 'Hola Redis!');
    const value = await client.get('test:key');
    console.log('Test básico:', value);
    
    // Test de catálogo
    const testItem = {
      id: '999',
      categoria: 'Test',
      proveedor: 'Test Provider',
      servicio: 'Test Service',
      plan: 'Test Plan',
      precio_mensual: '10000',
      detalles: 'Test details',
      estado: 'Activo'
    };
    
    await client.hSet(`catalogo:${testItem.id}`, testItem);
    const retrieved = await client.hGetAll(`catalogo:${testItem.id}`);
    console.log('Test catálogo:', retrieved);
    
    // Limpiar
    await client.del('test:key');
    await client.del(`catalogo:${testItem.id}`);
    
    console.log('Todos los tests pasaron!');
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await client.quit();
  }
}

testConnection();
```

### 4. Flujo de Datos Esperado

#### POST /catalog/update
```
1. Lambda recibe archivo CSV/Excel
2. Conecta al cluster Redis
3. Limpia catálogo existente (flushDb)
4. Procesa cada fila del CSV
5. Guarda cada item como hash: catalogo:{id}
6. Retorna confirmación
```

#### GET /catalog
```
1. Lambda recibe request
2. Conecta al cluster Redis
3. Obtiene todas las keys: keys('catalogo:*')
4. Recupera cada item con hGetAll
5. Formatea como JSON array
6. Retorna catálogo completo
```

### 5. Estructura de Datos Validada

#### Formato de Item en Redis
```
Key: catalogo:1
Hash Fields:
{
  "id": "1",
  "categoria": "Energía",
  "proveedor": "Empresa Eléctrica Nacional",
  "servicio": "Luz Residencial",
  "plan": "Básico",
  "precio_mensual": "45000",
  "detalles": "150 kWh incluidos",
  "estado": "Activo"
}
```

#### Formato de Respuesta JSON
```json
[
  {
    "id": 1,
    "categoria": "Energía",
    "proveedor": "Empresa Eléctrica Nacional",
    "servicio": "Luz Residencial",
    "plan": "Básico",
    "precio_mensual": 45000,
    "detalles": "150 kWh incluidos",
    "estado": "Activo"
  }
]
```

### 6. Comandos de Verificación

#### Verificar Datos en Redis
```bash
# Conectar al cluster (requiere redis-cli con TLS)
redis-cli -h master.sistema-pagos-cluster.oofk4z.use1.cache.amazonaws.com -p 6379 -a SistemaPagos2024Token --tls

# Comandos dentro de Redis
KEYS catalogo:*
HGETALL catalogo:1
DBSIZE
INFO memory
```

#### Verificar Logs de Lambda
```bash
# Ver logs de ejecución
aws logs tail /aws/lambda/nombre-de-la-lambda --follow

# Ver logs específicos
aws logs get-log-events --log-group-name /aws/lambda/nombre-de-la-lambda --log-stream-name nombre-del-stream
```

### 7. Troubleshooting Común

#### Error: Connection Timeout
- Verificar que Lambda está en la misma VPC
- Revisar Security Groups (permitir salida al puerto 6379)
- Verificar configuración de subnets

#### Error: Auth Failed
- Verificar token de autenticación
- Confirmar que AuthToken está enabled

#### Error: TLS Required
- Asegurar que `tls: {}` está en la configuración
- Verificar que TransitEncryption está enabled

#### Performance Issues
- Verificar tipo de instancia (cache.t3.micro para desarrollo)
- Monitorear métricas de CPU y memoria
- Considerar upgrade a cache.t3.small para producción

### 8. Métricas de Monitoreo

#### CloudWatch Metrics importantes
- `CurrItems` - Número de items en Redis
- `BytesUsedForCache` - Memoria utilizada
- `CacheHits` / `CacheMisses` - Performance
- `ReplicationLag` - Latencia de réplica
- `CPUUtilization` - Uso de CPU

#### Alertas recomendadas
- CPU > 80%
- Memory > 80%
- Connection errors > 5/min
- Replication lag > 1 second

### 9. Checklist Final de Integración

- [ ] Cluster Redis está `available`
- [ ] Lambda functions tienen variables de entorno configuradas
- [ ] Lambda functions están asignadas a la VPC correcta
- [ ] Security Groups permiten conexión a Redis
- [ ] IAM roles tienen permisos necesarios
- [ ] Test de conexión básico funciona
- [ ] Test de catálogo funciona
- [ ] POST /catalog/update guarda datos correctamente
- [ ] GET /catalog retorna datos en formato esperado
- [ ] Logs de Lambda no muestran errores de conexión
- [ ] Métricas de Redis son normales

### 10. Documentación de Referencia

- **Cluster Info**: `CLUSTER_INFO.md`
- **Lambda Examples**: `LAMBDA_EXAMPLES.md`
- **Terraform Config**: `main.tf`, `variables.tf`, `outputs.tf`
- **Test Scripts**: `test-redis.js`

### 11. Contacto de Soporte

Para issues con el cluster:
1. Revisar esta guía
2. Verificar logs de CloudWatch
3. Ejecutar comandos de verificación
4. Contactar si el problema persiste

---

**Nota**: Esta guía asume que el cluster Redis ya está desplegado y funcionando. La configuración de red y seguridad debe ser validada antes de probar las Lambda functions.
