// lib/providers/finanzas_provider.dart

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class FinanzasProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ================= VARIABLES FINANCIERAS =================
  double _cajaInicial = 0.0;
  double _inversionInicial = 0.0;
  double _totalSurtido = 0.0;
  double _ventasHoy = 0.0;
  double _gastosOperativos = 0.0;
  double _devoluciones = 0.0;
  double _ventasEfectivo = 0.0;
  double _ventasTarjeta = 0.0;
  double _totalMerma = 0.0;
  double _costoDeLoVendido = 0.0;
  double _totalAbonos = 0.0;

  List<Map<String, dynamic>> _gastosAgrupados = [];
  List<Map<String, dynamic>> _mermasAgrupadas = [];

  double get cajaInicial => _cajaInicial;
  double get inversionInicial => _inversionInicial;
  double get totalSurtido => _totalSurtido;
  double get ventasHoy => _ventasHoy;
  double get gastosOperativos => _gastosOperativos;
  double get devoluciones => _devoluciones;
  double get ventasEfectivo => _ventasEfectivo;
  double get ventasTarjeta => _ventasTarjeta;
  double get totalMerma => _totalMerma;
  double get totalAbonos => _totalAbonos;

  List<Map<String, dynamic>> get gastosAgrupados => _gastosAgrupados;
  List<Map<String, dynamic>> get mermasAgrupadas => _mermasAgrupadas;

  double get dineroEnCaja => _cajaInicial + _ventasEfectivo + _totalAbonos - _gastosOperativos - _totalSurtido - _inversionInicial - _devoluciones;
  double get gananciaReal => (_ventasHoy + _totalAbonos) - _costoDeLoVendido;

  // Variables Mensuales
  double _ventasMesTotal = 0.0;
  double _ventasMesEfectivo = 0.0;
  double _ventasMesTarjeta = 0.0;
  double _costoVendidoMes = 0.0;
  double _gastosMes = 0.0;
  double _mermasMes = 0.0;
  double _abonosMes = 0.0;
  List<Map<String, dynamic>> _gastosAgrupadosMes = [];
  List<Map<String, dynamic>> _mermasAgrupadasMes = [];

  double get ventasMesTotal => _ventasMesTotal;
  double get ventasMesEfectivo => _ventasMesEfectivo;
  double get ventasMesTarjeta => _ventasMesTarjeta;
  double get costoVendidoMes => _costoVendidoMes;
  double get gastosMes => _gastosMes;
  double get mermasMes => _mermasMes;
  double get abonosMes => _abonosMes;
  List<Map<String, dynamic>> get gastosAgrupadosMes => _gastosAgrupadosMes;
  List<Map<String, dynamic>> get mermasAgrupadasMes => _mermasAgrupadasMes;
  double get gananciaNetaMensual => (_ventasMesTotal + _abonosMes) - _costoVendidoMes - _gastosMes - _mermasMes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _categoriasGasto = [];
  List<Map<String, dynamic>> _categoriasMerma = [];
  List<Map<String, dynamic>> get categoriasGasto => _categoriasGasto;
  List<Map<String, dynamic>> get categoriasMerma => _categoriasMerma;

  // LISTA MIXTA DE GASTOS Y SUS FILTROS
  List<Map<String, dynamic>> _historialMixto = [];
  String _searchQuery = '';
  String _filtroTipo = 'todos'; 
  String _ordenLista = 'fecha_desc'; 

  String get filtroTipoActual => _filtroTipo;
  String get ordenListaActual => _ordenLista;
  String get searchQueryActual => _searchQuery;

  // ================= MÉTODOS DE LECTURA DE BALANCE =================

  Future<void> cargarBalance(int turnoId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final cajaResult = await db.rawQuery('SELECT monto_inicial FROM turnos WHERE id = ?', [turnoId]);
      _cajaInicial = (cajaResult.isNotEmpty ? (cajaResult.first['monto_inicial'] as num).toDouble() : 0.0);
      final inversionResult = await db.rawQuery('''SELECT COALESCE(SUM(p.costo * p.stock), 0) as total FROM productos p WHERE p.fecha_creacion >= (SELECT fecha_apertura FROM turnos WHERE id = ?) AND p.fecha_creacion < COALESCE((SELECT fecha_cierre FROM turnos WHERE id = ?), datetime('now')) AND NOT EXISTS (SELECT 1 FROM surtidos s WHERE s.producto_id = p.id)''', [turnoId, turnoId]);
      _inversionInicial = (inversionResult.first['total'] as num).toDouble();
      final surtidoResult = await db.rawQuery('SELECT COALESCE(SUM(costo_total), 0) as total FROM surtidos WHERE turno_id = ?', [turnoId]);
      _totalSurtido = (surtidoResult.first['total'] as num).toDouble();
      final ventasResult = await db.rawQuery('SELECT COALESCE(SUM(total), 0) as total FROM ventas WHERE turno_id = ?', [turnoId]);
      _ventasHoy = (ventasResult.first['total'] as num).toDouble();
      final costoResult = await db.rawQuery('''SELECT COALESCE(SUM(p.costo * vd.cantidad), 0) as total FROM venta_detalle vd JOIN ventas v ON vd.venta_id = v.id JOIN productos p ON vd.producto_id = p.id WHERE v.turno_id = ?''', [turnoId]);
      _costoDeLoVendido = (costoResult.first['total'] as num).toDouble();
      final gastosResult = await db.rawQuery('SELECT COALESCE(SUM(monto), 0) as total FROM gastos_operativos WHERE turno_id = ? AND monto > 0', [turnoId]);
      _gastosOperativos = (gastosResult.first['total'] as num).toDouble();
      final devolucionesResult = await db.rawQuery('SELECT COALESCE(SUM(ABS(monto)), 0) as total FROM gastos_operativos WHERE turno_id = ? AND monto < 0', [turnoId]);
      _devoluciones = (devolucionesResult.first['total'] as num).toDouble();
      final efectivoResult = await db.rawQuery("SELECT COALESCE(SUM(total), 0) as total FROM ventas WHERE turno_id = ? AND metodo_pago = 'efectivo'", [turnoId]);
      _ventasEfectivo = (efectivoResult.first['total'] as num).toDouble();
      final tarjetaResult = await db.rawQuery("SELECT COALESCE(SUM(total), 0) as total FROM ventas WHERE turno_id = ? AND metodo_pago = 'tarjeta'", [turnoId]);
      _ventasTarjeta = (tarjetaResult.first['total'] as num).toDouble();
      final mermaResult = await db.rawQuery('SELECT COALESCE(SUM(valor_perdido), 0) as total FROM mermas WHERE turno_id = ?', [turnoId]);
      _totalMerma = (mermaResult.first['total'] as num).toDouble();
      final abonosResult = await db.rawQuery('SELECT COALESCE(SUM(monto), 0) as total FROM abonos WHERE turno_id = ?', [turnoId]);
      _totalAbonos = (abonosResult.first['total'] as num).toDouble();

      _gastosAgrupados = await db.rawQuery('SELECT concepto as categoria, SUM(monto) as total FROM gastos_operativos WHERE turno_id = ? AND monto > 0 GROUP BY concepto ORDER BY total DESC', [turnoId]);
      _mermasAgrupadas = await db.rawQuery('SELECT motivo as categoria, SUM(valor_perdido) as total FROM mermas WHERE turno_id = ? GROUP BY motivo ORDER BY total DESC', [turnoId]);
    } catch (e) { debugPrint('Error en FinanzasProvider.cargarBalance: $e'); } finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> cargarResumenMensual(DateTime fecha) async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await _dbHelper.database;
      String mesStr = DateFormat('yyyy-MM').format(fecha);
      String likeStr = '$mesStr%';
      var vTotal = await db.rawQuery("SELECT COALESCE(SUM(total), 0) as t FROM ventas WHERE fecha LIKE ?", [likeStr]);
      _ventasMesTotal = (vTotal.first['t'] as num).toDouble();
      var vEfec = await db.rawQuery("SELECT COALESCE(SUM(total), 0) as t FROM ventas WHERE fecha LIKE ? AND metodo_pago = 'efectivo'", [likeStr]);
      _ventasMesEfectivo = (vEfec.first['t'] as num).toDouble();
      var vTarj = await db.rawQuery("SELECT COALESCE(SUM(total), 0) as t FROM ventas WHERE fecha LIKE ? AND metodo_pago = 'tarjeta'", [likeStr]);
      _ventasMesTarjeta = (vTarj.first['t'] as num).toDouble();
      var costo = await db.rawQuery('''SELECT COALESCE(SUM(p.costo * vd.cantidad), 0) as t FROM venta_detalle vd JOIN ventas v ON vd.venta_id = v.id JOIN productos p ON vd.producto_id = p.id WHERE v.fecha LIKE ?''', [likeStr]);
      _costoVendidoMes = (costo.first['t'] as num).toDouble();
      var gastos = await db.rawQuery("SELECT COALESCE(SUM(monto), 0) as t FROM gastos_operativos WHERE fecha LIKE ? AND monto > 0", [likeStr]);
      _gastosMes = (gastos.first['t'] as num).toDouble();
      var mermas = await db.rawQuery("SELECT COALESCE(SUM(valor_perdido), 0) as t FROM mermas WHERE fecha LIKE ?", [likeStr]);
      _mermasMes = (mermas.first['t'] as num).toDouble();
      var abonos = await db.rawQuery("SELECT COALESCE(SUM(monto), 0) as t FROM abonos WHERE fecha LIKE ?", [likeStr]);
      _abonosMes = (abonos.first['t'] as num).toDouble();

      _gastosAgrupadosMes = await db.rawQuery('SELECT concepto as categoria, SUM(monto) as total FROM gastos_operativos WHERE fecha LIKE ? AND monto > 0 GROUP BY concepto ORDER BY total DESC', [likeStr]);
      _mermasAgrupadasMes = await db.rawQuery('SELECT motivo as categoria, SUM(valor_perdido) as total FROM mermas WHERE fecha LIKE ? GROUP BY motivo ORDER BY total DESC', [likeStr]);
    } catch (e) { debugPrint('Error en cargarResumenMensual: $e'); } finally { _isLoading = false; notifyListeners(); }
  }

  // ================= EL GESTOR DE CATEGORÍAS =================
  Future<void> cargarCatalogoCategorias() async {
    final db = await _dbHelper.database;
    _categoriasGasto = await db.query('categorias_catalogo', where: 'tipo = ?', whereArgs: ['gasto'], orderBy: 'nombre ASC');
    _categoriasMerma = await db.query('categorias_catalogo', where: 'tipo = ?', whereArgs: ['merma'], orderBy: 'nombre ASC');
    notifyListeners();
  }

  Future<void> agregarCategoria(String nombre, String tipo) async {
    final db = await _dbHelper.database;
    await db.insert('categorias_catalogo', {'nombre': nombre.trim(), 'tipo': tipo});
    await cargarCatalogoCategorias();
  }

  Future<void> editarCategoria(int id, String nombreAntiguo, String nombreNuevo, String tipo) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update('categorias_catalogo', {'nombre': nombreNuevo.trim()}, where: 'id = ?', whereArgs: [id]);
      if (tipo == 'gasto') {
        await txn.update('gastos_operativos', {'concepto': nombreNuevo.trim()}, where: 'concepto = ?', whereArgs: [nombreAntiguo]);
      } else {
        await txn.update('mermas', {'motivo': nombreNuevo.trim()}, where: 'motivo = ?', whereArgs: [nombreAntiguo]);
      }
    });
    await cargarCatalogoCategorias();
  }

  Future<void> eliminarCategoria(int id) async {
    final db = await _dbHelper.database;
    await db.delete('categorias_catalogo', where: 'id = ?', whereArgs: [id]);
    await cargarCatalogoCategorias();
  }

  // ================= GESTOR DE LISTA MIXTA Y FILTROS =================
  Future<void> cargarHistorialMixto(DateTime fecha, bool porMes) async {
    final db = await _dbHelper.database;
    String fechaStr = porMes ? DateFormat('yyyy-MM').format(fecha) : DateFormat('yyyy-MM-dd').format(fecha);
    String likeStr = '$fechaStr%';

    List<Map<String, dynamic>> todos = [];
    todos.addAll(await db.rawQuery('SELECT s.id, s.turno_id, s.producto_id, \'surtido\' as tipo, p.nombre as texto_busqueda, s.cantidad, s.costo_unitario, s.costo_total as monto, s.fecha FROM surtidos s JOIN productos p ON s.producto_id = p.id WHERE s.fecha LIKE ?', [likeStr]));
    todos.addAll(await db.rawQuery('SELECT id, turno_id, null as producto_id, \'operativo\' as tipo, concepto as texto_busqueda, null as cantidad, null as costo_unitario, monto, fecha FROM gastos_operativos WHERE fecha LIKE ? AND monto > 0', [likeStr]));
    todos.addAll(await db.rawQuery('SELECT id, turno_id, null as producto_id, \'devolucion\' as tipo, concepto as texto_busqueda, null as cantidad, null as costo_unitario, ABS(monto) as monto, fecha FROM gastos_operativos WHERE fecha LIKE ? AND monto < 0', [likeStr]));
    todos.addAll(await db.rawQuery('SELECT m.id, m.turno_id, m.producto_id, \'merma\' as tipo, p.nombre || \' - \' || m.motivo as texto_busqueda, m.cantidad, null as costo_unitario, m.valor_perdido as monto, m.fecha, m.motivo FROM mermas m JOIN productos p ON m.producto_id = p.id WHERE m.fecha LIKE ?', [likeStr]));

    _historialMixto = todos;
    notifyListeners();
  }

  void setFiltrosListaMixta(String query, String tipo, String orden) {
    _searchQuery = query;
    _filtroTipo = tipo;
    _ordenLista = orden;
    notifyListeners();
  }

  List<Map<String, dynamic>> get historialMixtoFiltrado {
    var lista = List<Map<String, dynamic>>.from(_historialMixto);
    if (_filtroTipo != 'todos') { lista = lista.where((item) => item['tipo'] == _filtroTipo).toList(); }
    if (_searchQuery.isNotEmpty) { lista = lista.where((item) => item['texto_busqueda'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList(); }

    lista.sort((a, b) {
      if (_ordenLista == 'fecha_desc') return b['fecha'].compareTo(a['fecha']);
      if (_ordenLista == 'fecha_asc') return a['fecha'].compareTo(b['fecha']);
      if (_ordenLista == 'monto_desc') return (b['monto'] as double).compareTo(a['monto'] as double);
      if (_ordenLista == 'monto_asc') return (a['monto'] as double).compareTo(b['monto'] as double);
      return 0;
    });

    return lista;
  }

  // ================= MÉTODOS DE ESCRITURA Y CANCELACIÓN =================

  Future<bool> registrarGastoOperativo({required int turnoId, required String concepto, required double monto}) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('gastos_operativos', {'turno_id': turnoId, 'concepto': concepto, 'monto': monto, 'fecha': DateTime.now().toIso8601String(), 'tipo': 'operativo'});
      await cargarBalance(turnoId);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> registrarMerma({required int turnoId, required int productoId, required double cantidad, required String motivo, required double valorPerdido}) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.insert('mermas', {'turno_id': turnoId, 'producto_id': productoId, 'cantidad': cantidad, 'motivo': motivo, 'valor_perdido': valorPerdido, 'fecha': DateTime.now().toIso8601String()});
        await txn.rawUpdate('UPDATE productos SET stock = stock - ? WHERE id = ?', [cantidad, productoId]);
      });
      await cargarBalance(turnoId);
      return true;
    } catch (e) { return false; }
  }

  // ⭐ NUEVO Y BLINDADO: CANCELAR SURTIDO SIN BLOQUEOS
  Future<String?> cancelarSurtido(int surtidoId, int productoId, double cantidadSurtida, int turnoActivoId) async {
    try {
      final db = await _dbHelper.database;
      
      // Ejecución directa saltando la validación estricta
      await db.transaction((txn) async {
        // 1. Eliminamos el registro de la inversión
        await txn.delete('surtidos', where: 'id = ?', whereArgs: [surtidoId]);
        
        // 2. Descontamos el stock con un candado SQL nativo.
        // Si al restar la cantidad el stock cae por debajo de 0, el CASE lo forzará a quedarse en 0.
        await txn.rawUpdate(
          'UPDATE productos SET stock = CASE WHEN stock - ? < 0 THEN 0 ELSE stock - ? END WHERE id = ?', 
          [cantidadSurtida, cantidadSurtida, productoId]
        );
      });

      await cargarBalance(turnoActivoId);
      return null; // Null significa éxito
    } catch (e) {
      return 'Ocurrió un error al intentar cancelar: $e';
    }
  }

  Future<bool> cancelarGastoOperativo(int gastoId, int turnoActivoId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('gastos_operativos', where: 'id = ?', whereArgs: [gastoId]);
      await cargarBalance(turnoActivoId);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> cancelarMerma(int mermaId, int productoId, double cantidadPerdida, int turnoActivoId) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete('mermas', where: 'id = ?', whereArgs: [mermaId]);
        await txn.rawUpdate('UPDATE productos SET stock = stock + ? WHERE id = ?', [cantidadPerdida, productoId]);
      });
      await cargarBalance(turnoActivoId);
      return true;
    } catch (e) { return false; }
  }
}