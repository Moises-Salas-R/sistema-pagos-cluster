/**
 * Script de prueba para conectar al cluster Redis del sistema de pagos
 * Requiere: npm install redis
 */

const redis = require('redis');

// Configuración - obtener desde terraform output
const config = {
  host: process.env.REDIS_ENDPOINT || 'tu-endereco-redis.xxxxxx.use1.cache.amazonaws.com',
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_AUTH_TOKEN || 'tu-token-seguro'
};

async function testConnection() {
  const client = redis.createClient({
    host: config.host,
    port: config.port,
    password: config.password,
    tls: {} // Requerido para ElastiCache con encriptación
  });

  client.on('error', (err) => {
    console.error('Error de conexión a Redis:', err);
  });

  client.on('connect', () => {
    console.log('✅ Conectado exitosamente a Redis del sistema de pagos');
  });

  try {
    await client.connect();
    
    // Test básico
    await client.set('test:key', 'Hola Redis Cluster!');
    const value = await client.get('test:key');
    console.log('✅ Test de escritura/lectura del sistema de pagos:', value);
    
    // Test con estructura del catálogo
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
    
    // Guardar como hash (estructura recomendada)
    await client.hSet(`catalogo:${testItem.id}`, testItem);
    console.log('✅ Item de catálogo del sistema de pagos guardado');
    
    // Recuperar item
    const retrieved = await client.hGetAll(`catalogo:${testItem.id}`);
    console.log('✅ Item del sistema de pagos recuperado:', retrieved);
    
    // Listar todos los items del catálogo
    const keys = await client.keys('catalogo:*');
    console.log(`✅ Total items en catálogo del sistema de pagos: ${keys.length}`);
    
    // Limpiar datos de prueba
    await client.del('test:key');
    await client.del(`catalogo:${testItem.id}`);
    
    console.log('✅ Todos los tests del sistema de pagos pasaron exitosamente');
    
  } catch (error) {
    console.error('❌ Error en los tests:', error);
  } finally {
    await client.quit();
  }
}

// Ejemplo de cómo guardar el catálogo completo
async function guardarCatalogoCompleto() {
  const client = redis.createClient({
    host: config.host,
    port: config.port,
    password: config.password,
    tls: {}
  });

  try {
    await client.connect();
    
    // Catálogo de ejemplo (los mismos datos que mencionaste)
    const catalogo = [
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
      }
      // ... agregar más items según el catálogo completo
    ];
    
    // Limpiar catálogo existente
    await client.flushDb();
    console.log('🗑️ Catálogo anterior del sistema de pagos eliminado');
    
    // Guardar todos los items
    for (const item of catalogo) {
      await client.hSet(`catalogo:${item.id}`, item);
    }
    
    console.log(`✅ Catálogo del sistema de pagos guardado con ${catalogo.length} items`);
    
    // Verificar
    const keys = await client.keys('catalogo:*');
    console.log(`✅ Verificación: ${keys.length} items en Redis del sistema de pagos`);
    
  } catch (error) {
    console.error('❌ Error guardando catálogo:', error);
  } finally {
    await client.quit();
  }
}

// Ejemplo de cómo obtener el catálogo completo
async function obtenerCatalogoCompleto() {
  const client = redis.createClient({
    host: config.host,
    port: config.port,
    password: config.password,
    tls: {}
  });

  try {
    await client.connect();
    
    const keys = await client.keys('catalogo:*');
    const catalogo = [];
    
    for (const key of keys) {
      const item = await client.hGetAll(key);
      catalogo.push(item);
    }
    
    console.log('📋 Catálogo completo del sistema de pagos:');
    console.log(JSON.stringify(catalogo, null, 2));
    
    return catalogo;
    
  } catch (error) {
    console.error('❌ Error obteniendo catálogo:', error);
    return [];
  } finally {
    await client.quit();
  }
}

// Exportar funciones para usar en Lambda
module.exports = {
  testConnection,
  guardarCatalogoCompleto,
  obtenerCatalogoCompleto
};

// Si se ejecuta directamente
if (require.main === module) {
  console.log('🚀 Iniciando tests de Redis del sistema de pagos...');
  testConnection()
    .then(() => {
      console.log('\n📦 Guardando catálogo de ejemplo del sistema de pagos...');
      return guardarCatalogoCompleto();
    })
    .then(() => {
      console.log('\n📋 Obteniendo catálogo completo del sistema de pagos...');
      return obtenerCatalogoCompleto();
    })
    .catch(console.error);
}
