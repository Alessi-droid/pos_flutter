import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class PosProvider with ChangeNotifier {
  Database? _database;
  List<VentaItem> _carrito = [];
  
  List<Map<String, dynamic>> historialVentas = [];
  List<Map<String, dynamic>> historialGastos = [];
  DateTime _fechaReporte = DateTime.now();
  bool _verPorMes = false;
  
  // ==========================================
  // 1. VARIABLES DE CAJA (V5)
  // ==========================================
  double _montoInicialDia = 0.0;
  bool _cajaAbiertaHoy = false;

  // ==========================================
  // 2. VARIABLES DE MÉTRICAS (LO QUE FALTABA)
  // ==========================================
  List<double> ventasSemana = [0,0,0,0,0,0,0];
  List<String> etiquetasSemana = ["Lun", "Mar", "Mie", "Jue", "Vie", "Sab", "Dom"];
  Map<String, double> datosPastelPagos = {'EFECTIVO': 0, 'TARJETA': 0};

  // ==========================================
  // 3. GETTERS PÚBLICOS
  // ==========================================
  double get montoInicialDia => _montoInicialDia;
  bool get cajaAbiertaHoy => _cajaAbiertaHoy;
  
  DateTime get fechaReporte => _fechaReporte;
  bool get verPorMes => _verPorMes;

  List<VentaItem> get carrito => _carrito;
  double get totalCarrito => _carrito.fold(0, (sum, item) => sum + item.total);
  double get totalCostoCarrito => _carrito.fold(0, (sum, item) => sum + (item.producto.precioCompra * item.cantidad));

  // Getters Financieros
  double get ventasTotal => historialVentas.fold(0.0, (sum, item) => sum + (item['total'] as double));
  double get gastosTotalGlobal => historialGastos.fold(0.0, (sum, item) => sum + (item['monto'] as double));

  // Getters Desglosados
  double get gastosSurtido => historialGastos.where((g) => g['tipo'] == 'SURTIDO').fold(0.0, (sum, item) => sum + (item['monto'] as double));
  double get gastosOperativos => historialGastos.where((g) => g['tipo'] == 'OPERATIVO').fold(0.0, (sum, item) => sum + (item['monto'] as double));
  double get gastosMerma => historialGastos.where((g) => g['tipo'] == 'MERMA').fold(0.0, (sum, item) => sum + (item['monto'] as double));

  // Getters Balance Cascada
  double get remanenteCajaInicial => _montoInicialDia - gastosSurtido;
  double get utilidadOperativaDia => ventasTotal - gastosOperativos;
  double get dineroTotalEnCaja => remanenteCajaInicial + utilidadOperativaDia; 

  PosProvider() {
    _initDB();
  }

  Future<void> _initDB() async {
    String path = join(await getDatabasesPath(), 'pos_database_v2.db');
    
    _database = await openDatabase(
      path,
      version: 5, 
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE productos(id INTEGER PRIMARY KEY AUTOINCREMENT, codigo TEXT, nombre TEXT, precio_venta REAL, precio_compra REAL, stock REAL, producto_padre_id INTEGER, factor_conversion INTEGER, es_granel INTEGER, es_kilo INTEGER)');
        await db.execute('CREATE TABLE ventas(id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, total REAL, metodo_pago TEXT, detalles TEXT)');
        await db.execute('CREATE TABLE gastos(id INTEGER PRIMARY KEY AUTOINCREMENT, descripcion TEXT, monto REAL, fecha TEXT, tipo TEXT)');
        await db.execute('CREATE TABLE aperturas_caja(id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, monto_inicial REAL)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) { try { await db.execute("ALTER TABLE ventas ADD COLUMN detalles TEXT"); } catch (_) {} }
        if (oldVersion < 4) { try { await db.execute("ALTER TABLE gastos ADD COLUMN tipo TEXT DEFAULT 'OPERATIVO'"); } catch (_) {} }
        if (oldVersion < 5) { try { await db.execute('CREATE TABLE aperturas_caja(id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, monto_inicial REAL)'); } catch (_) {} }
      }
    );
    await _verificarCajaDia();
    await cargarMetricas(); // Cargamos métricas al inicio
    notifyListeners();
  }

  // --- CONTROL DE APERTURA DE CAJA ---
  Future<void> _verificarCajaDia() async {
    final db = _database;
    if (db == null) return;
    String hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final res = await db.query('aperturas_caja', where: 'fecha = ?', whereArgs: [hoy]);
    if (res.isNotEmpty) {
      _montoInicialDia = double.tryParse(res.first['monto_inicial'].toString()) ?? 0.0;
      _cajaAbiertaHoy = true;
    } else {
      _montoInicialDia = 0.0;
      _cajaAbiertaHoy = false;
    }
    notifyListeners();
  }

  Future<void> abrirCajaDiaria(double monto) async {
    final db = _database;
    if (db == null) return;
    String hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await db.insert('aperturas_caja', {'fecha': hoy, 'monto_inicial': monto});
    _montoInicialDia = monto;
    _cajaAbiertaHoy = true;
    notifyListeners();
  }

  // --- MÉTODOS DE NEGOCIO ---
  Future<void> cobrar(String metodoPago) async {
    final db = _database; if (db == null) return;
    List<Map<String, dynamic>> itemsVenta = _carrito.map((item) => {'id_producto': item.producto.id, 'cantidad': item.cantidad, 'nombre': item.producto.nombre, 'es_kilo': item.producto.esKilo ? 1 : 0}).toList();
    await db.insert('ventas', {'fecha': DateTime.now().toIso8601String(), 'total': totalCarrito, 'metodo_pago': metodoPago, 'detalles': jsonEncode(itemsVenta)});
    for (var item in _carrito) { await _descontarStock(item.producto, item.cantidad); }
    limpiarCarrito(); 
    cargarReportes();
    cargarMetricas(); // Actualizamos gráficas
  }

  Future<void> _descontarStock(Producto p, double cantidad) async {
    final db = _database; if (db == null) return;
    double stockActual = p.stock;
    if (p.esGranel && p.productoPadreId != null && stockActual < cantidad) {
        int padreId = p.productoPadreId!; int conversion = p.factorConversion;
        if (conversion > 0) {
          double faltante = cantidad - stockActual; int paquetes = (faltante / conversion).ceil();
          final resPadre = await db.query('productos', where: 'id = ?', whereArgs: [padreId]);
          if (resPadre.isNotEmpty) {
            double stockPadre = double.tryParse(resPadre.first['stock'].toString()) ?? 0.0;
            await db.update('productos', {'stock': stockPadre - paquetes}, where: 'id = ?', whereArgs: [padreId]);
            stockActual += (paquetes * conversion.toDouble());
          }
        }
    }
    await db.update('productos', {'stock': stockActual - cantidad}, where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> registrarSalidaMasiva(String motivo) async {
    final db = _database; if (db == null) return;
    double costoTotalPerdida = totalCostoCarrito;
    await db.insert('gastos', {'descripcion': "Salida: $motivo", 'monto': costoTotalPerdida, 'fecha': DateTime.now().toIso8601String(), 'tipo': 'MERMA'});
    for (var item in _carrito) { await _descontarStock(item.producto, item.cantidad); }
    limpiarCarrito(); cargarReportes();
  }

  Future<void> resurtirMercancia({required int idProducto, required String nombreProducto, required double cantidad, required double costoUnitario, required double precioVenta, required bool actualizarPrecios}) async {
    final db = _database; if (db == null) return;
    final check = await db.query('productos', columns: ['stock'], where: 'id = ?', whereArgs: [idProducto]);
    if (check.isNotEmpty) {
      double stockActual = double.tryParse(check.first['stock'].toString()) ?? 0.0;
      Map<String, dynamic> updateData = {'stock': stockActual + cantidad};
      if (actualizarPrecios) { updateData['precio_compra'] = costoUnitario; updateData['precio_venta'] = precioVenta; }
      await db.update('productos', updateData, where: 'id = ?', whereArgs: [idProducto]);
      await db.insert('gastos', {'descripcion': "Compra: $nombreProducto", 'monto': cantidad * costoUnitario, 'fecha': DateTime.now().toIso8601String(), 'tipo': 'SURTIDO'});
      notifyListeners(); cargarReportes();
    }
  }

  Future<void> registrarGastoManual(String desc, double monto) async {
    final db = _database; if (db == null) return;
    await db.insert('gastos', {'descripcion': desc, 'monto': monto, 'fecha': DateTime.now().toIso8601String(), 'tipo': 'OPERATIVO'});
    cargarReportes();
  }

  Future<void> cancelarVenta(int idVenta) async {
    final db = _database; if (db == null) return;
    final venta = await db.query('ventas', where: 'id = ?', whereArgs: [idVenta]);
    if (venta.isEmpty) return;
    if (venta.first['detalles'] != null) {
      try {
        List<dynamic> items = jsonDecode(venta.first['detalles'] as String);
        for (var item in items) {
          int prodId = item['id_producto']; double cantidad = double.tryParse(item['cantidad'].toString()) ?? 0.0;
          final prodDB = await db.query('productos', columns: ['stock'], where: 'id = ?', whereArgs: [prodId]);
          if (prodDB.isNotEmpty) { await db.update('productos', {'stock': (double.tryParse(prodDB.first['stock'].toString())??0) + cantidad}, where: 'id = ?', whereArgs: [prodId]); }
        }
      } catch (e) {}
    }
    await db.delete('ventas', where: 'id = ?', whereArgs: [idVenta]);
    notifyListeners(); 
    cargarReportes();
    cargarMetricas();
  }

  // Consultas Generales
  Future<List<Producto>> buscarProductosPorNombre(String query) async {
    final db = _database; if (db == null) return []; if (query.isEmpty) return [];
    final maps = await db.query('productos', where: 'nombre LIKE ? OR codigo LIKE ?', whereArgs: ['%$query%', '%$query%']);
    return List.generate(maps.length, (i) => Producto.fromMap(maps[i]));
  }
  
  Future<Producto?> escanearProducto(dynamic identificador) async {
    final db = _database; if (db == null) return null;
    String codigo = (identificador is Producto) ? identificador.codigo : identificador.toString();
    final maps = await db.query('productos', where: 'codigo = ?', whereArgs: [codigo]);
    if (maps.isNotEmpty) return Producto.fromMap(maps.first); return null;
  }
  
  Future<void> guardarProducto({required String codigo, required String nombre, required double pVenta, required double pCompra, required double stockNuevo, required double stockAnterior, int? padreId, int conversion = 0, bool esGranel = false, bool esKilo = false}) async {
    final db = _database; if (db == null) return;
    final existe = await db.query('productos', where: 'codigo = ?', whereArgs: [codigo]);
    if (existe.isNotEmpty) { await db.update('productos', {'nombre': nombre, 'precio_venta': pVenta, 'precio_compra': pCompra, 'stock': stockNuevo, 'producto_padre_id': padreId, 'factor_conversion': conversion, 'es_granel': esGranel ? 1 : 0, 'es_kilo': esKilo ? 1 : 0}, where: 'codigo = ?', whereArgs: [codigo]); } 
    else { await db.insert('productos', {'codigo': codigo, 'nombre': nombre, 'precio_venta': pVenta, 'precio_compra': pCompra, 'stock': stockNuevo, 'producto_padre_id': padreId, 'factor_conversion': conversion, 'es_granel': esGranel ? 1 : 0, 'es_kilo': esKilo ? 1 : 0}); 
    if (stockNuevo > 0 && pCompra > 0) await db.insert('gastos', {'descripcion': "Inversión Inicial: $nombre", 'monto': stockNuevo * pCompra, 'fecha': DateTime.now().toIso8601String(), 'tipo': 'SURTIDO'}); }
    notifyListeners(); cargarReportes(); 
  }
  
  Future<void> eliminarProducto(int id) async { final db = _database; if (db == null) return; await db.delete('productos', where: 'id = ?', whereArgs: [id]); notifyListeners(); }
  void agregarAlCarrito(Producto p, double cantidad) { int index = _carrito.indexWhere((item) => item.producto.id == p.id); if (index != -1) { _carrito[index].cantidad += cantidad; _carrito[index].total = _carrito[index].cantidad * p.precioVenta; } else { _carrito.add(VentaItem(producto: p, cantidad: cantidad)); } notifyListeners(); }
  void limpiarCarrito() { _carrito.clear(); notifyListeners(); }
  Future<double> calcularTotalInvertido() async { final db = _database; if (db == null) return 0.0; try { final result = await db.rawQuery('SELECT SUM(stock * precio_compra) as total FROM productos'); if (result.isNotEmpty && result.first['total'] != null) return double.tryParse(result.first['total'].toString()) ?? 0.0; } catch (e) {} return 0.0; }
  
  void cambiarModoReporte(bool esMensual) { _verPorMes = esMensual; cargarReportes(); }
  void cambiarFechaReporte(DateTime nuevaFecha) { _fechaReporte = nuevaFecha; cargarReportes(); }
  
  Future<void> cargarReportes() async { 
    final db = _database; if (db == null) return; 
    String fmt = _verPorMes ? 'yyyy-MM' : 'yyyy-MM-dd'; String fechaQuery = DateFormat(fmt).format(_fechaReporte); 
    historialVentas = await db.query('ventas', where: 'fecha LIKE ?', whereArgs: ['$fechaQuery%'], orderBy: "id DESC"); 
    try { historialGastos = await db.query('gastos', where: 'fecha LIKE ?', whereArgs: ['$fechaQuery%'], orderBy: "id DESC"); } catch(e) { historialGastos = []; } 
    await _verificarCajaDia();
    notifyListeners(); 
  }

  // ==========================================
  // 4. LÓGICA DE MÉTRICAS (GRAFICAS)
  // ==========================================
  Future<void> cargarMetricas() async {
    final db = _database;
    if (db == null) return;

    // 1. Gráfica Semanal (Últimos 7 días)
    // Inicializamos en 0
    ventasSemana = [0,0,0,0,0,0,0];
    DateTime now = DateTime.now();
    
    // Obtenemos ventas de los últimos 7 días
    // Nota: Esto es una simplificación rápida. En prod se agrupa por SQL.
    final ultimasVentas = await db.query('ventas', orderBy: "fecha DESC", limit: 200); 

    for (var venta in ultimasVentas) {
      DateTime fechaVenta = DateTime.parse(venta['fecha'] as String);
      double total = venta['total'] as double;
      
      int diferenciaDias = now.difference(fechaVenta).inDays;
      if (diferenciaDias < 7 && diferenciaDias >= 0) {
        // Encontrar el índice: Hoy es el último (6), hace 6 días es el primero (0)
        // Lógica: Si hoy es martes, martes va al final.
        // Simplificación: Agrupamos por día de la semana estático por ahora
        int diaSemana = fechaVenta.weekday - 1; // Lunes = 0, Domingo = 6
        ventasSemana[diaSemana] += total;
      }
    }

    // 2. Gráfica Pastel (Pagos)
    double totalEfectivo = 0;
    double totalTarjeta = 0;
    
    // Usamos el historial del reporte actual para el pastel (lo que se ve en pantalla)
    // O podemos hacer query global. Usaré query global de hoy.
    String hoy = DateFormat('yyyy-MM-dd').format(now);
    final ventasHoy = await db.query('ventas', where: 'fecha LIKE ?', whereArgs: ['$hoy%']);
    
    for(var v in ventasHoy) {
      if (v['metodo_pago'] == 'TARJETA') totalTarjeta += (v['total'] as double);
      else totalEfectivo += (v['total'] as double);
    }
    datosPastelPagos = {'EFECTIVO': totalEfectivo, 'TARJETA': totalTarjeta};

    notifyListeners();
  }
}
