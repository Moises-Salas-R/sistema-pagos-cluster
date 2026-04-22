# Ejemplos de Lambda Functions para Sistema de Pagos

## Configuración Base

### package.json para Lambda
```json
{
  "name": "sistema-pagos-lambda",
  "version": "1.0.0",
  "dependencies": {
    "redis": "^4.6.10",
    "aws-sdk": "^2.1500.0",
    "csv-parser": "^3.0.0",
    "multer": "^1.4.5-lts.1"
  }
}
```

### redis-client.js (Módulo compartido)
```javascript
const redis = require('redis');

class RedisClient {
  constructor() {
    this.client = null;
    this.config = {
      host: process.env.REDIS_ENDPOINT || 'master.sistema-pagos-cluster.oofk4z.use1.cache.amazonaws.com',
      port: process.env.REDIS_PORT || 6379,
      password: process.env.REDIS_AUTH_TOKEN || 'SistemaPagos2024Token',
      tls: {},
      retryDelayOnFailover: 100,
      enableReadyCheck: false,
      maxRetriesPerRequest: 3
    };
  }

  async connect() {
    if (!this.client) {
      this.client = redis.createClient(this.config);
      
      this.client.on('error', (err) => {
        console.error('Redis Client Error:', err);
      });

      this.client.on('connect', () => {
        console.log('Redis Client Connected');
      });

      await this.client.connect();
    }
    return this.client;
  }

  async disconnect() {
    if (this.client) {
      await this.client.quit();
      this.client = null;
    }
  }

  async getClient() {
    if (!this.client) {
      await this.connect();
    }
    return this.client;
  }
}

module.exports = new RedisClient();
```

## Lambda Functions

### 1. upload-catalog.js (POST /catalog/update)

```javascript
const redisClient = require('./redis-client');
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const csv = require('csv-parser');

exports.handler = async (event) => {
  console.log('Evento recibido:', JSON.stringify(event, null, 2));
  
  let client;
  try {
    // Conectar a Redis
    client = await redisClient.getClient();
    
    // Procesar el archivo CSV desde S3 o directamente del evento
    const datos = await procesarCatalogo(event);
    
    // Limpiar catálogo existente
    await client.flushDb();
    console.log('Catálogo anterior eliminado');
    
    // Guardar nuevos datos
    let itemsGuardados = 0;
    for (const item of datos) {
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
      itemsGuardados++;
    }
    
    console.log(`Se guardaron ${itemsGuardados} items en el catálogo`);
    
    // Verificar que los datos se guardaron correctamente
    const keys = await client.keys('catalogo:*');
    console.log(`Verificación: ${keys.length} items en Redis`);
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        message: 'Catálogo actualizado exitosamente',
        itemsProcesados: itemsGuardados,
        timestamp: new Date().toISOString()
      })
    };
    
  } catch (error) {
    console.error('Error en upload-catalog:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        error: 'Error procesando el catálogo',
        details: error.message
      })
    };
  } finally {
    if (client) {
      await redisClient.disconnect();
    }
  }
};

async function procesarCatalogo(event) {
  // Datos de ejemplo del catálogo mencionado
  return [
    {
      id: '1',
      categoria: 'Energía',
      proveedor: 'Empresa Eléctrica Nacional',
      servicio: 'Luz Residencial',
      plan: 'Básico',
      precio_mensual: '45000',
      detalles: '150 kWh incluidos',
      estado: 'Activo'
    },
    {
      id: '2',
      categoria: 'Energía',
      proveedor: 'Empresa Eléctrica Nacional',
      servicio: 'Luz Residencial',
      plan: 'Premium',
      precio_mensual: '75000',
      detalles: '300 kWh incluidos',
      estado: 'Activo'
    },
    {
      id: '3',
      categoria: 'Agua',
      proveedor: 'Acueducto Municipal',
      servicio: 'Agua Potable',
      plan: 'Estándar',
      precio_mensual: '25000',
      detalles: '20 m³ incluidos',
      estado: 'Activo'
    },
    {
      id: '4',
      categoria: 'Internet',
      proveedor: 'Tigo',
      servicio: 'Internet Hogar',
      plan: 'Básico',
      precio_mensual: '89900',
      detalles: '100 Mbps',
      estado: 'Activo'
    },
    {
      id: '5',
      categoria: 'Internet',
      proveedor: 'Tigo',
      servicio: 'Internet Hogar',
      plan: 'Avanzado',
      precio_mensual: '129900',
      detalles: '200 Mbps',
      estado: 'Activo'
    }
    // ... agregar más items según el catálogo completo
  ];
}

// Función para procesar CSV desde S3 (opcional)
async function procesarCSVDesdeS3(bucket, key) {
  return new Promise((resolve, reject) => {
    const results = [];
    
    const s3Stream = s3.getObject({ bucket, key }).createReadStream();
    
    s3Stream
      .pipe(csv())
      .on('data', (data) => {
        // Convertir datos del CSV al formato esperado
        results.push({
          id: data.ID,
          categoria: data.Categoría,
          proveedor: data.Proveedor,
          servicio: data.Servicio,
          plan: data.Plan,
          precio_mensual: data['Precio Mensual'].replace(/[^\d]/g, ''),
          detalles: data['Velocidad/Detalles'],
          estado: data.Estado
        });
      })
      .on('end', () => {
        resolve(results);
      })
      .on('error', (error) => {
        reject(error);
      });
  });
}
```

### 2. catalogo-servicios.js (GET /catalog)

```javascript
const redisClient = require('./redis-client');

exports.handler = async (event) => {
  console.log('Evento recibido:', JSON.stringify(event, null, 2));
  
  let client;
  try {
    // Conectar a Redis
    client = await redisClient.getClient();
    
    // Obtener todas las keys del catálogo
    const keys = await client.keys('catalogo:*');
    console.log(`Found ${keys.length} items in catalog`);
    
    const catalogo = [];
    
    // Recuperar cada item
    for (const key of keys) {
      const item = await client.hGetAll(key);
      
      // Convertir a formato JSON esperado por el frontend
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
    
    // Ordenar por ID para consistencia
    catalogo.sort((a, b) => a.id - b.id);
    
    console.log(`Retrieved ${catalogo.length} items from catalog`);
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify(catalogo)
    };
    
  } catch (error) {
    console.error('Error en catalogo-servicios:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        error: 'Error obteniendo el catálogo',
        details: error.message
      })
    };
  } finally {
    if (client) {
      await redisClient.disconnect();
    }
  }
};
```

### 3. test-connection.js (Lambda de prueba)

```javascript
const redisClient = require('./redis-client');

exports.handler = async (event) => {
  console.log('Test de conexión a Redis');
  
  let client;
  try {
    // Conectar a Redis
    client = await redisClient.getClient();
    
    // Test básico de escritura/lectura
    await client.set('test:connection', 'OK');
    const value = await client.get('test:connection');
    
    // Test de estructura de catálogo
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
    
    // Limpiar datos de prueba
    await client.del('test:connection');
    await client.del(`catalogo:${testItem.id}`);
    
    // Verificar estado del cluster
    const info = await client.info();
    const lines = info.split('\r\n');
    const redisVersion = lines.find(line => line.startsWith('redis_version'))?.split(':')[1];
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        status: 'success',
        message: 'Conexión a Redis exitosa',
        tests: {
          basicReadWrite: value === 'OK',
          catalogStructure: Object.keys(retrieved).length > 0,
          clusterInfo: {
            version: redisVersion,
            connected: true
          }
        },
        timestamp: new Date().toISOString()
      })
    };
    
  } catch (error) {
    console.error('Error en test-connection:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        status: 'error',
        message: 'Error conectando a Redis',
        error: error.message,
        timestamp: new Date().toISOString()
      })
    };
  } finally {
    if (client) {
      await redisClient.disconnect();
    }
  }
};
```

## Configuración de Variables de Entorno

### Para cada Lambda function:
```
REDIS_ENDPOINT=master.sistema-pagos-cluster.oofk4z.use1.cache.amazonaws.com
REDIS_PORT=6379
REDIS_AUTH_TOKEN=SistemaPagos2024Token
NODE_ENV=production
```

## Configuración IAM Role

### Política mínima requerida:
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
        "elasticache:Connect",
        "elasticache:DescribeReplicationGroups"
      ],
      "Resource": "arn:aws:elasticache:us-east-1:662271354434:replicationgroup:sistema-pagos-cluster"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::tu-bucket-de-catalogos/*"
    }
  ]
}
```

## Configuración VPC para Lambda

### Asignar a las Lambda functions:
- **VPC**: `vpc-0ae3d0b7ff67195b2`
- **Subnets**: 
  - `subnet-096c20ec2cdcf1c6f` (us-east-1a)
  - `subnet-01662b765bd74677e` (us-east-1b)
- **Security Group**: `sg-0277d7759f5e00925` o uno nuevo que permita salida a internet

## Testing

### 1. Probar conexión:
```bash
# Invocar test-connection Lambda
aws lambda invoke --function-name test-connection response.json
cat response.json
```

### 2. Probar upload-catalog:
```bash
aws lambda invoke --function-name upload-catalog --payload '{}' response.json
cat response.json
```

### 3. Probar catalogo-servicios:
```bash
aws lambda invoke --function-name catalogo-servicios response.json
cat response.json | jq '.'
```

## Monitoreo

### CloudWatch Metrics:
- **Latencia**: Tiempo de respuesta de Redis
- **Errores**: Conexiones fallidas
- **Invocaciones**: Uso de las Lambda functions
- **Memoria**: Uso de memoria de las instancias Redis

### Logs importantes:
- **Redis Connection Logs**: Errores de conexión
- **Performance Logs**: Slow queries
- **Business Logs**: Operaciones del catálogo
