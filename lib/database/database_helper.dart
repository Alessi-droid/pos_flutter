// lib/database/database_helper.dart

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String path = join(appDocDir.path, 'pos_tablet_v7_final.db');

    debugPrint('📁 Ruta de la BD: $path');

    return await openDatabase(
      path,
      version: 9, // ⭐ VERSIÓN 9: Catálogo estricto de Categorías
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ==========================================================
  // CREACIÓN DESDE CERO (Para instalaciones nuevas)
  // ==========================================================
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('🛠️ Creando base de datos versión $version desde cero');

    // Tablas base
    await db.execute('''CREATE TABLE productos (id INTEGER PRIMARY KEY AUTOINCREMENT, codigo TEXT UNIQUE NOT NULL, nombre TEXT NOT NULL, costo REAL NOT NULL DEFAULT 0.0, precio_venta REAL NOT NULL DEFAULT 0.0, stock REAL NOT NULL DEFAULT 0.0, stock_minimo REAL DEFAULT 0.0, es_suelto INTEGER DEFAULT 0, producto_padre_id INTEGER, unidades_por_caja INTEGER DEFAULT 1, a_granel INTEGER DEFAULT 0, unidad_medida TEXT, fecha_creacion TEXT NOT NULL, fecha_actualizacion TEXT NOT NULL, FOREIGN KEY (producto_padre_id) REFERENCES productos (id) ON DELETE SET NULL)''');
    await db.execute('''CREATE TABLE turnos (id INTEGER PRIMARY KEY AUTOINCREMENT, monto_inicial REAL NOT NULL, fecha_apertura TEXT NOT NULL, fecha_cierre TEXT, activo INTEGER DEFAULT 1, monto_cierre REAL)''');
    await db.execute('''CREATE TABLE ventas (id INTEGER PRIMARY KEY AUTOINCREMENT, turno_id INTEGER NOT NULL, folio INTEGER NOT NULL DEFAULT 1, total REAL NOT NULL, metodo_pago TEXT NOT NULL, fecha TEXT NOT NULL, FOREIGN KEY (turno_id) REFERENCES turnos (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE venta_detalle (id INTEGER PRIMARY KEY AUTOINCREMENT, venta_id INTEGER NOT NULL, producto_id INTEGER NOT NULL, cantidad REAL NOT NULL, precio_unitario REAL NOT NULL, costo_unitario REAL NOT NULL DEFAULT 0.0, subtotal REAL NOT NULL, FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE, FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE gastos_operativos (id INTEGER PRIMARY KEY AUTOINCREMENT, turno_id INTEGER NOT NULL, tipo TEXT NOT NULL DEFAULT 'operativo', concepto TEXT NOT NULL, monto REAL NOT NULL, fecha TEXT NOT NULL, FOREIGN KEY (turno_id) REFERENCES turnos (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE surtidos (id INTEGER PRIMARY KEY AUTOINCREMENT, turno_id INTEGER NOT NULL, producto_id INTEGER NOT NULL, cantidad REAL NOT NULL, costo_unitario REAL NOT NULL, costo_total REAL NOT NULL, fecha TEXT NOT NULL, FOREIGN KEY (turno_id) REFERENCES turnos (id) ON DELETE CASCADE, FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE mermas (id INTEGER PRIMARY KEY AUTOINCREMENT, turno_id INTEGER NOT NULL, producto_id INTEGER NOT NULL, cantidad REAL NOT NULL, motivo TEXT, valor_perdido REAL NOT NULL, fecha TEXT NOT NULL, FOREIGN KEY (turno_id) REFERENCES turnos (id) ON DELETE CASCADE, FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE)''');

    // Tablas de Clientes y Préstamos
    await db.execute('''CREATE TABLE clientes (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, telefono TEXT, limite_credito REAL DEFAULT 0.0, fecha_creacion TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE prestamos (id INTEGER PRIMARY KEY AUTOINCREMENT, turno_id INTEGER NOT NULL, cliente_id INTEGER NOT NULL, total REAL NOT NULL, saldo_pendiente REAL NOT NULL, fecha TEXT NOT NULL, estado TEXT DEFAULT 'pendiente', FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE prestamo_detalle (id INTEGER PRIMARY KEY AUTOINCREMENT, prestamo_id INTEGER NOT NULL, producto_id INTEGER NOT NULL, cantidad REAL NOT NULL, precio_unitario REAL NOT NULL, costo_unitario REAL NOT NULL DEFAULT 0.0, subtotal REAL NOT NULL, FOREIGN KEY (prestamo_id) REFERENCES prestamos (id) ON DELETE CASCADE, FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE abonos (id INTEGER PRIMARY KEY AUTOINCREMENT, prestamo_id INTEGER NOT NULL, turno_id INTEGER NOT NULL, monto REAL NOT NULL, fecha TEXT NOT NULL, FOREIGN KEY (prestamo_id) REFERENCES prestamos (id) ON DELETE CASCADE)''');

    // ⭐ TABLA V9: Catálogo Estricto de Categorías
    await db.execute('''
      CREATE TABLE categorias_catalogo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL 
      )
    ''');

    // Categorías por defecto iniciales
    await db.insert('categorias_catalogo', {'nombre': 'Renta', 'tipo': 'gasto'});
    await db.insert('categorias_catalogo', {'nombre': 'Luz', 'tipo': 'gasto'});
    await db.insert('categorias_catalogo', {'nombre': 'Pago Proveedor', 'tipo': 'gasto'});
    await db.insert('categorias_catalogo', {'nombre': 'Caducado', 'tipo': 'merma'});
    await db.insert('categorias_catalogo', {'nombre': 'Roto / Dañado', 'tipo': 'merma'});
    await db.insert('categorias_catalogo', {'nombre': 'Consumo Personal', 'tipo': 'merma'});

    // Índices
    await db.execute('CREATE INDEX idx_productos_codigo ON productos(codigo)');
    await db.execute('CREATE INDEX idx_productos_nombre ON productos(nombre)');
    await db.execute('CREATE INDEX idx_ventas_turno ON ventas(turno_id)');
    await db.execute('CREATE INDEX idx_ventas_fecha ON ventas(fecha)');
    await db.execute('CREATE INDEX idx_ventas_folio ON ventas(folio)');

    debugPrint('✅ Base de datos creada exitosamente');
  }

  // ==========================================================
  // BITÁCORA HISTÓRICA DE MIGRACIONES
  // ==========================================================
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 Actualizando BD de v$oldVersion a v$newVersion');

    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE ventas ADD COLUMN folio INTEGER DEFAULT 1');
        await db.execute('CREATE INDEX idx_ventas_folio ON ventas(folio)');
        debugPrint('✅ Migración v1→v2 completada');
      } catch (e) { debugPrint('⚠️ Error v1→v2: $e'); }
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE productos ADD COLUMN unidad_medida TEXT');
        debugPrint('✅ Migración v2→v3 completada');
      } catch (e) { debugPrint('⚠️ Error v2→v3: $e'); }
    }

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE gastos_operativos ADD COLUMN tipo TEXT NOT NULL DEFAULT \'operativo\'');
        debugPrint('✅ Migración v3→v4 completada');
      } catch (e) { debugPrint('⚠️ Error v3→v4: $e'); }
    }

    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE productos_nueva (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            codigo TEXT UNIQUE NOT NULL,
            nombre TEXT NOT NULL,
            costo REAL NOT NULL DEFAULT 0.0,
            precio_venta REAL NOT NULL DEFAULT 0.0,
            stock REAL NOT NULL DEFAULT 0.0,
            stock_minimo REAL DEFAULT 0.0,
            es_suelto INTEGER DEFAULT 0,
            producto_padre_id INTEGER,
            unidades_por_caja INTEGER DEFAULT 1,
            a_granel INTEGER DEFAULT 0,
            unidad_medida TEXT,
            fecha_creacion TEXT NOT NULL,
            fecha_actualizacion TEXT NOT NULL,
            FOREIGN KEY (producto_padre_id) REFERENCES productos (id) ON DELETE SET NULL
          )
        ''');
        await db.execute('''
          INSERT INTO productos_nueva
          SELECT id, codigo, nombre, costo, precio_venta, stock, CAST(stock_minimo AS REAL), es_suelto, producto_padre_id, unidades_por_caja, a_granel, unidad_medida, fecha_creacion, fecha_actualizacion FROM productos
        ''');
        await db.execute('DROP TABLE productos');
        await db.execute('ALTER TABLE productos_nueva RENAME TO productos');
        await db.execute('CREATE INDEX idx_productos_codigo ON productos(codigo)');
        await db.execute('CREATE INDEX idx_productos_nombre ON productos(nombre)');
        debugPrint('✅ Migración v4→v5 completada');
      } catch (e) { debugPrint('⚠️ Error v4→v5: $e'); }
    }

    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE venta_detalle ADD COLUMN costo_unitario REAL NOT NULL DEFAULT 0.0');
        debugPrint('✅ Migración v5→v6 completada');
      } catch (e) { debugPrint('⚠️ Error v5→v6: $e'); }
    }

    if (oldVersion < 7) {
      try {
        // En v7 creamos el sistema viejo de préstamos (con cliente como texto)
        await db.execute('''CREATE TABLE prestamos (id INTEGER PRIMARY KEY AUTOINCREMENT, turno_id INTEGER NOT NULL, cliente TEXT NOT NULL, total REAL NOT NULL, saldo_pendiente REAL NOT NULL, fecha TEXT NOT NULL, estado TEXT DEFAULT 'pendiente')''');
        await db.execute('''CREATE TABLE prestamo_detalle (id INTEGER PRIMARY KEY AUTOINCREMENT, prestamo_id INTEGER NOT NULL, producto_id INTEGER NOT NULL, cantidad REAL NOT NULL, precio_unitario REAL NOT NULL, costo_unitario REAL NOT NULL DEFAULT 0.0, subtotal REAL NOT NULL, FOREIGN KEY (prestamo_id) REFERENCES prestamos (id) ON DELETE CASCADE, FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE)''');
        await db.execute('''CREATE TABLE abonos (id INTEGER PRIMARY KEY AUTOINCREMENT, prestamo_id INTEGER NOT NULL, turno_id INTEGER NOT NULL, monto REAL NOT NULL, fecha TEXT NOT NULL, FOREIGN KEY (prestamo_id) REFERENCES prestamos (id) ON DELETE CASCADE)''');
        debugPrint('✅ Migración v6→v7 completada');
      } catch (e) { debugPrint('⚠️ Error v6→v7: $e'); }
    }

    if (oldVersion < 8) {
      try {
        debugPrint('🚀 INICIANDO MIGRACIÓN MÁGICA DE CLIENTES (v7->v8)...');
        await db.execute('''CREATE TABLE clientes (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, telefono TEXT, limite_credito REAL DEFAULT 0.0, fecha_creacion TEXT NOT NULL)''');

        final prestamosViejos = await db.query('prestamos');
        final Map<String, int> mapaClientesOficiales = {};

        await db.execute('''
          CREATE TABLE prestamos_nueva (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            turno_id INTEGER NOT NULL,
            cliente_id INTEGER NOT NULL,
            total REAL NOT NULL,
            saldo_pendiente REAL NOT NULL,
            fecha TEXT NOT NULL,
            estado TEXT DEFAULT 'pendiente',
            FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE
          )
        ''');

        for (var p in prestamosViejos) {
          final String nombreCrudo = p['cliente'] as String;
          final String nombreLimpio = nombreCrudo.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
          int? idOficial;

          if (!mapaClientesOficiales.containsKey(nombreLimpio)) {
            final String nombreBonito = nombreLimpio.split(' ').map((palabra) {
              if (palabra.isEmpty) return '';
              return palabra[0].toUpperCase() + palabra.substring(1);
            }).join(' ');

            idOficial = await db.insert('clientes', {'nombre': nombreBonito, 'fecha_creacion': DateTime.now().toIso8601String()});
            mapaClientesOficiales[nombreLimpio] = idOficial;
          } else {
            idOficial = mapaClientesOficiales[nombreLimpio];
          }

          await db.insert('prestamos_nueva', {
            'id': p['id'], 'turno_id': p['turno_id'], 'cliente_id': idOficial, 'total': p['total'], 'saldo_pendiente': p['saldo_pendiente'], 'fecha': p['fecha'], 'estado': p['estado']
          });
        }

        await db.execute('DROP TABLE prestamos');
        await db.execute('ALTER TABLE prestamos_nueva RENAME TO prestamos');
        debugPrint('✅ MIGRACIÓN v7→v8 COMPLETADA.');
      } catch (e) { debugPrint('⚠️ Error CRÍTICO v7→v8: $e'); }
    }

    // ⭐ MIGRACIÓN V9: Catálogo de Categorías
    if (oldVersion < 9) {
      try {
        debugPrint('🚀 INICIANDO MIGRACIÓN A CATÁLOGO DE CATEGORÍAS (v8->v9)...');
        await db.execute('''
          CREATE TABLE categorias_catalogo (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            tipo TEXT NOT NULL 
          )
        ''');

        // Extraer lo que ya escribiste antes y convertirlo en oficial
        await db.execute('''
          INSERT INTO categorias_catalogo (nombre, tipo)
          SELECT DISTINCT concepto, 'gasto' FROM gastos_operativos WHERE monto > 0 AND concepto != ''
          UNION
          SELECT DISTINCT motivo, 'merma' FROM mermas WHERE motivo != ''
        ''');

        debugPrint('✅ MIGRACIÓN DE CATEGORÍAS v8->v9 COMPLETADA.');
      } catch (e) {
        debugPrint('⚠️ Error en migración v8→v9: $e');
      }
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> resetDatabase() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String path = join(appDocDir.path, 'pos_tablet_v7_final.db');
    await deleteDatabase(path);
    _database = null;
  }
}