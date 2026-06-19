// lib/providers/prestamos_provider.dart

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/producto.dart';

class ItemPrestamo {
  final Producto producto;
  double cantidad;
  bool venderAlCosto;

  ItemPrestamo({
    required this.producto,
    this.cantidad = 1.0,
    this.venderAlCosto = false,
  });

  double get subtotal => (venderAlCosto ? producto.costo : producto.precioVenta) * cantidad;
}

class PrestamosProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  final List<ItemPrestamo> _carrito = [];
  List<Producto> _todosProductos = [];

  // ⭐ NUEVAS LISTAS PARA EL MANEJO OFICIAL DE CLIENTES
  List<Map<String, dynamic>> _catalogoClientes = [];
  List<Map<String, dynamic>> _cuentasAgrupadas = [];

  bool _isLoading = false;

  List<ItemPrestamo> get carrito => List.unmodifiable(_carrito);
  List<Producto> get todosProductos => List.unmodifiable(_todosProductos);
  List<Map<String, dynamic>> get catalogoClientes => _catalogoClientes;
  List<Map<String, dynamic>> get cuentasAgrupadas => _cuentasAgrupadas;
  bool get isLoading => _isLoading;

  double get totalCarrito => _carrito.fold(0.0, (sum, item) => sum + item.subtotal);
  bool get carritoVacio => _carrito.isEmpty;

  Future<void> cargarDatos() async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('productos', orderBy: 'nombre ASC');
      _todosProductos = maps.map((map) => Producto.fromMap(map)).toList();

      await cargarCatalogoClientes();
      await actualizarListaCuentas();
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ⭐ NUEVO: Carga todos los clientes del catálogo
  Future<void> cargarCatalogoClientes() async {
    final db = await _dbHelper.database;
    _catalogoClientes = await db.query('clientes', orderBy: 'nombre ASC');
    notifyListeners();
  }

  // ⭐ NUEVO: Agrupa las deudas por Cliente
  Future<void> actualizarListaCuentas() async {
    final db = await _dbHelper.database;
    _cuentasAgrupadas = await db.rawQuery('''
      SELECT c.id as cliente_id, c.nombre, c.telefono, 
             SUM(p.saldo_pendiente) as deuda_total,
             MIN(p.fecha) as fecha_mas_antigua 
      FROM clientes c 
      JOIN prestamos p ON c.id = p.cliente_id 
      WHERE p.estado = 'pendiente' 
      GROUP BY c.id
    '''); // Quitamos el ORDER BY de SQL porque ahora lo haremos dinámico en Dart
    notifyListeners();
  }

  // ==========================================================
  // ⭐ 2. NUEVO BLOQUE: LÓGICA DE FILTROS Y BÚSQUEDA
  // ==========================================================
  String _searchQuery = '';
  String _criterioOrden = 'deuda_desc'; // Opciones: deuda_desc, deuda_asc, antiguedad_asc, antiguedad_desc
  double? _montoMinimo;
  double? _montoMaximo;

  String get criterioOrdenActual => _criterioOrden;
  double? get montoMinimoActual => _montoMinimo;
  double? get montoMaximoActual => _montoMaximo;

  void setFiltroBusqueda(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCriterioOrden(String criterio) {
    _criterioOrden = criterio;
    notifyListeners();
  }

  void setRangoMontos(double? min, double? max) {
    _montoMinimo = min;
    _montoMaximo = max;
    notifyListeners();
  }

  void limpiarFiltrosAvanzados() {
    _criterioOrden = 'deuda_desc';
    _montoMinimo = null;
    _montoMaximo = null;
    notifyListeners();
  }

  // ⭐ GETTER MÁGICO: Este es el que usará la interfaz de usuario
  List<Map<String, dynamic>> get cuentasFiltradas {
    var lista = List<Map<String, dynamic>>.from(_cuentasAgrupadas);

    // 1. Filtrar por nombre (Buscador)
    if (_searchQuery.isNotEmpty) {
      lista = lista.where((c) => c['nombre'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // 2. Filtrar por Rango de Cantidad
    if (_montoMinimo != null) {
      lista = lista.where((c) => (c['deuda_total'] as double) >= _montoMinimo!).toList();
    }
    if (_montoMaximo != null) {
      lista = lista.where((c) => (c['deuda_total'] as double) <= _montoMaximo!).toList();
    }

    // 3. Ordenamiento
    lista.sort((a, b) {
      double deudaA = a['deuda_total'] as double;
      double deudaB = b['deuda_total'] as double;
      String fechaA = (a['fecha_mas_antigua'] ?? '').toString();
      String fechaB = (b['fecha_mas_antigua'] ?? '').toString();

      if (_criterioOrden == 'deuda_desc') return deudaB.compareTo(deudaA); // Mayor a menor
      if (_criterioOrden == 'deuda_asc') return deudaA.compareTo(deudaB);  // Menor a mayor
      if (_criterioOrden == 'antiguedad_asc') return fechaA.compareTo(fechaB); // Más viejas primero
      if (_criterioOrden == 'antiguedad_desc') return fechaB.compareTo(fechaA); // Más recientes primero
      return 0;
    });

    return lista;
  }

  // ⭐ NUEVO: Obtiene el historial detallado de un solo cliente para abrir su perfil
  Future<List<Map<String, dynamic>>> obtenerHistorialCliente(int clienteId) async {
    final db = await _dbHelper.database;
    // Traemos todos sus préstamos (pagados y pendientes) con sus detalles
    final prestamos = await db.query('prestamos', where: 'cliente_id = ?', whereArgs: [clienteId], orderBy: 'fecha DESC');

    List<Map<String, dynamic>> historialCompleto = [];

    for (var p in prestamos) {
      final detalles = await db.rawQuery('''
        SELECT pd.cantidad, pd.precio_unitario, pd.subtotal, pr.nombre as producto_nombre
        FROM prestamo_detalle pd
        JOIN productos pr ON pd.producto_id = pr.id
        WHERE pd.prestamo_id = ?
      ''', [p['id']]);

      final abonos = await db.query('abonos', where: 'prestamo_id = ?', whereArgs: [p['id']], orderBy: 'fecha ASC');

      historialCompleto.add({
        'prestamo': p,
        'detalles': detalles,
        'abonos': abonos,
      });
    }
    return historialCompleto;
  }

  List<Producto> buscarProductos(String query) {
    if (query.isEmpty) return [];
    final queryLower = query.toLowerCase();
    return _todosProductos.where((p) => p.codigo.toLowerCase().contains(queryLower) || p.nombre.toLowerCase().contains(queryLower)).take(10).toList();
  }

  // Métodos del carrito...
  void agregarProducto(Producto producto, double cantidad) {
    final index = _carrito.indexWhere((item) => item.producto.id == producto.id);
    if (index >= 0) { _carrito[index].cantidad += cantidad; }
    else { _carrito.add(ItemPrestamo(producto: producto, cantidad: cantidad)); }
    notifyListeners();
  }

  void eliminarItem(int index) {
    if (index >= 0 && index < _carrito.length) { _carrito.removeAt(index); notifyListeners(); }
  }

  void actualizarCantidad(int index, double nuevaCantidad) {
    if (index >= 0 && index < _carrito.length && nuevaCantidad > 0) { _carrito[index].cantidad = nuevaCantidad; notifyListeners(); }
  }

  void toggleVenderAlCosto(int index, bool value) {
    if (index >= 0 && index < _carrito.length) { _carrito[index].venderAlCosto = value; notifyListeners(); }
  }

  void limpiarCarrito() {
    _carrito.clear();
    notifyListeners();
  }

  // ⭐ ACTUALIZADO: Registra el préstamo amarrado a un cliente_id
  Future<bool> registrarPrestamo({required int turnoId, int? clienteId, String? nombreNuevoCliente}) async {
    if (_carrito.isEmpty || (clienteId == null && (nombreNuevoCliente == null || nombreNuevoCliente.isEmpty))) return false;

    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {

        // Si no hay ID, creamos al cliente en el momento
        int idOficial = clienteId ?? 0;
        if (idOficial == 0 && nombreNuevoCliente != null) {
          idOficial = await txn.insert('clientes', {
            'nombre': nombreNuevoCliente.trim(),
            'fecha_creacion': DateTime.now().toIso8601String(),
          });
        }

        // Crear el préstamo oficial
        final prestamoId = await txn.insert('prestamos', {
          'turno_id': turnoId,
          'cliente_id': idOficial, // <--- Usamos el ID
          'total': totalCarrito,
          'saldo_pendiente': totalCarrito,
          'fecha': DateTime.now().toIso8601String(),
          'estado': 'pendiente'
        });

        for (var item in _carrito) {
          final precioUnitario = item.venderAlCosto ? item.producto.costo : item.producto.precioVenta;
          await txn.insert('prestamo_detalle', {
            'prestamo_id': prestamoId, 'producto_id': item.producto.id!, 'cantidad': item.cantidad,
            'precio_unitario': precioUnitario, 'costo_unitario': item.producto.costo, 'subtotal': item.subtotal,
          });
          await txn.rawUpdate('UPDATE productos SET stock = stock - ? WHERE id = ?', [item.cantidad, item.producto.id]);
        }
      });

      limpiarCarrito();
      await cargarCatalogoClientes(); // Refrescamos por si agregamos uno nuevo
      await actualizarListaCuentas();
      return true;
    } catch (e) {
      debugPrint('Error al registrar préstamo: $e');
      return false;
    }
  }

  // ⭐ NUEVO Y PODEROSO: Abono Inteligente
  Future<bool> abonarAClienteGlobal({required int clienteId, required int turnoId, required double montoPago}) async {
    if (montoPago <= 0) return false;

    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Buscamos todas sus deudas pendientes, de la más antigua a la más nueva
        final pendientes = await txn.query('prestamos', where: 'cliente_id = ? AND estado = ?', whereArgs: [clienteId, 'pendiente'], orderBy: 'fecha ASC');

        double dineroRestante = montoPago;

        for (var p in pendientes) {
          if (dineroRestante <= 0) break; // Ya repartimos todo el abono

          double deudaDeEsteTicket = p['saldo_pendiente'] as double;
          int prestamoId = p['id'] as int;

          // ¿Cuánto de este ticket podemos pagar con el dinero que nos sobra?
          double abonoAEsteTicket = dineroRestante >= deudaDeEsteTicket ? deudaDeEsteTicket : dineroRestante;
          double nuevoSaldo = deudaDeEsteTicket - abonoAEsteTicket;

          // Registramos el recibo de este abono
          await txn.insert('abonos', {
            'prestamo_id': prestamoId, 'turno_id': turnoId, 'monto': abonoAEsteTicket, 'fecha': DateTime.now().toIso8601String(),
          });

          // Actualizamos la deuda de este ticket
          await txn.update('prestamos',
            {'saldo_pendiente': nuevoSaldo, 'estado': nuevoSaldo <= 0.01 ? 'pagado' : 'pendiente'},
            where: 'id = ?', whereArgs: [prestamoId],
          );

          // Restamos lo que ya usamos de las manos del cliente
          dineroRestante -= abonoAEsteTicket;
        }
      });

      await actualizarListaCuentas();
      return true;
    } catch (e) {
      debugPrint('Error al registrar abono global: $e');
      return false;
    }
  }

  // ⭐ NUEVO: Editar nombre del cliente
  Future<bool> editarNombreCliente(int clienteId, String nuevoNombre) async {
    if (nuevoNombre.trim().isEmpty) return false;
    try {
      final db = await _dbHelper.database;
      await db.update('clientes', {'nombre': nuevoNombre.trim()}, where: 'id = ?', whereArgs: [clienteId]);
      await cargarCatalogoClientes();
      await actualizarListaCuentas();
      return true;
    } catch (e) {
      debugPrint('Error al editar cliente: $e');
      return false;
    }
  }

  // ⭐ NUEVO: Eliminar cliente (Solo si no debe nada)
  Future<bool> eliminarCliente(int clienteId, double deudaActual) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('clientes', where: 'id = ?', whereArgs: [clienteId]);
      await cargarCatalogoClientes();
      await actualizarListaCuentas();
      return true;
    } catch (e) {
      debugPrint('Error al eliminar cliente: $e');
      return false;
    }
  }


  // ⭐ NUEVO: Préstamo de dinero en efectivo físico
    Future<bool> prestarEfectivoGlobal({required int clienteId, required String nombreCliente, required int turnoId, required double montoPrestado}) async {
      if (montoPrestado <= 0) return false;

      try {
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          // 1. Crear el ticket de préstamo a nombre del cliente
          await txn.insert('prestamos', {
            'turno_id': turnoId,
            'cliente_id': clienteId,
            'total': montoPrestado,
            'saldo_pendiente': montoPrestado,
            'fecha': DateTime.now().toIso8601String(),
            'estado': 'pendiente'
          });

          // 2. Registrar la salida del dinero de la caja registradora
          await txn.insert('gastos_operativos', {
            'turno_id': turnoId,
            'concepto': 'Préstamo en efectivo a $nombreCliente',
            'monto': montoPrestado, // Positivo, porque tus gastos se restan automáticamente en Finanzas
            'fecha': DateTime.now().toIso8601String()
          });
        });

        await actualizarListaCuentas();
        return true;
      } catch (e) {
        debugPrint('Error al registrar préstamo en efectivo: $e');
        return false;
      }
    }
}