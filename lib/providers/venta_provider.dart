// lib/providers/venta_provider.dart

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/producto.dart';
import '../models/venta.dart';

class ItemCarrito {
  final Producto producto;
  double cantidad;
  bool venderAlCosto; 
  
  ItemCarrito({
    required this.producto,
    this.cantidad = 1.0,
    this.venderAlCosto = false, 
  });

  double get subtotal => (venderAlCosto ? producto.costo : producto.precioVenta) * cantidad;
}

class VentaProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  int _carritoActivoIndex = 0;
  final Map<int, List<ItemCarrito>> _carritos = {0: [], 1: [], 2: []};

  List<Producto> _todosProductos = [];
  bool _isLoading = false;
  
  // ⭐ NUEVO CANDADO: Evita que la venta se procese 2 veces si hay lag o doble clic
  bool _isProcessingVenta = false; 

  int get carritoActivoIndex => _carritoActivoIndex;
  List<ItemCarrito> get items => List.unmodifiable(_carritos[_carritoActivoIndex]!);
  List<Producto> get todosProductos => List.unmodifiable(_todosProductos);
  bool get isLoading => _isLoading;
  bool get isProcessingVenta => _isProcessingVenta;
  
  double get total => _carritos[_carritoActivoIndex]!.fold(0.0, (sum, item) => sum + item.subtotal);
  int get cantidadItems => _carritos[_carritoActivoIndex]!.length;
  bool get carritoVacio => _carritos[_carritoActivoIndex]!.isEmpty;

  int getCantidadItemsEnCarrito(int index) => _carritos[index]?.length ?? 0;

  void cambiarCarrito(int index) {
    if (index >= 0 && index <= 2) {
      _carritoActivoIndex = index;
      notifyListeners();
    }
  }

  Future<void> cargarProductos() async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('productos', orderBy: 'nombre ASC');
      _todosProductos = maps.map((map) => Producto.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error al cargar productos: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Producto> buscarProductos(String query) {
    if (query.isEmpty) return [];
    final queryLower = query.toLowerCase();
    return _todosProductos.where((p) => 
      p.codigo.toLowerCase().contains(queryLower) || p.nombre.toLowerCase().contains(queryLower)
    ).take(10).toList();
  }

  void agregarProducto(Producto producto, double cantidad) {
    final carritoActual = _carritos[_carritoActivoIndex]!;
    final index = carritoActual.indexWhere((item) => item.producto.id == producto.id);
    if (index >= 0) {
      carritoActual[index].cantidad += cantidad;
    } else {
      carritoActual.add(ItemCarrito(producto: producto, cantidad: cantidad));
    }
    notifyListeners();
  }

  void eliminarItem(int index) {
    final carritoActual = _carritos[_carritoActivoIndex]!;
    if (index >= 0 && index < carritoActual.length) {
      carritoActual.removeAt(index);
      notifyListeners();
    }
  }

  void actualizarCantidad(int index, double nuevaCantidad) {
    final carritoActual = _carritos[_carritoActivoIndex]!;
    if (index >= 0 && index < carritoActual.length && nuevaCantidad > 0) {
      carritoActual[index].cantidad = nuevaCantidad;
      notifyListeners();
    }
  }

  void toggleVenderAlCosto(int index, bool value) {
    final carritoActual = _carritos[_carritoActivoIndex]!;
    if (index >= 0 && index < carritoActual.length) {
      carritoActual[index].venderAlCosto = value;
      notifyListeners();
    }
  }

  void limpiarCarrito() {
    _carritos[_carritoActivoIndex]!.clear();
    notifyListeners();
  }

  Future<bool> procesarVenta({required int turnoId, required String metodoPago, required int folio}) async {
    final carritoActual = _carritos[_carritoActivoIndex]!;
    
    // ⭐ CANDADO 1: Aborta si ya está procesando una venta (Anti doble-cobro)
    if (carritoActual.isEmpty || _isProcessingVenta) return false;

    _isProcessingVenta = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      
      // ⭐ VALIDACIÓN CRÍTICA: Verifica stock ANTES de procesar
      for (var item in carritoActual) {
        if (item.producto.stock < item.cantidad) {
          debugPrint('❌ STOCK INSUFICIENTE: ${item.producto.nombre}');
          debugPrint('   Disponible: ${item.producto.stock} | Requerido: ${item.cantidad}');
          _isProcessingVenta = false;
          notifyListeners();
          return false; // Abortamos la venta
        }
      }
      
      // ⭐ CANDADO 2: Transacción estricta. Si algo falla, NADA se guarda, la DB se protege.
      await db.transaction((txn) async {
        final venta = Venta(turnoId: turnoId, total: total, metodoPago: metodoPago, folio: folio);
        final ventaId = await txn.insert('ventas', venta.toMap());

        for (var item in carritoActual) {
          final precioUnitario = item.venderAlCosto ? item.producto.costo : item.producto.precioVenta;

          await txn.insert('venta_detalle', {
            'venta_id': ventaId,
            'producto_id': item.producto.id!,
            'cantidad': item.cantidad,
            'precio_unitario': precioUnitario,
            'costo_unitario': item.producto.costo,
            'subtotal': item.subtotal,
          });

          // ⭐ REPARACIÓN DE LA LÓGICA DE PRODUCTOS SUELTOS
          if (item.producto.esSuelto) {
            final productoActual = await txn.query('productos', where: 'id = ?', whereArgs: [item.producto.id!]);
            final stockActual = (productoActual.first['stock'] as num?)?.toDouble() ?? 0.0; 

            if (stockActual < item.cantidad) {
              final unidadesPorCaja = item.producto.unidadesPorCaja ?? 1;
              final productoPadreId = item.producto.productoPadreId;
              
              if (productoPadreId != null && unidadesPorCaja > 0) {
                // Calcula exactamente cuántas cajas necesita abrir para cubrir lo que pide el cliente
                double faltante = item.cantidad - stockActual;
                int cajasNecesarias = (faltante / unidadesPorCaja).ceil();

                final padre = await txn.query('productos', where: 'id = ?', whereArgs: [productoPadreId]);
                if (padre.isNotEmpty) {
                  final costoPadre = (padre.first['costo'] as num?)?.toDouble() ?? 0.0;
                  
                  await txn.rawUpdate('UPDATE productos SET costo = ? WHERE id = ?', [costoPadre / unidadesPorCaja, item.producto.id]);
                  // Sube el stock del suelto multiplicando las cajas que abrió
                  await txn.rawUpdate('UPDATE productos SET stock = stock + ? WHERE id = ?', [(cajasNecesarias * unidadesPorCaja).toDouble(), item.producto.id]);
                  // Baja las cajas exactas que abrió del producto padre
                  await txn.rawUpdate('UPDATE productos SET stock = stock - ? WHERE id = ?', [cajasNecesarias.toDouble(), productoPadreId]);
                }
              }
            }
          }

          // ⭐ CANDADO 3: Descuento atómico directo en la base de datos
          await txn.rawUpdate('UPDATE productos SET stock = stock - ? WHERE id = ?', [item.cantidad, item.producto.id]);
        }
      });
      
      // Venta exitosa. Limpiamos carrito antes de soltar el candado de seguridad.
      _carritos[_carritoActivoIndex]!.clear(); 
      await cargarProductos();
      return true;
      
    } catch (e) {
      debugPrint('Error CRÍTICO al procesar venta: $e');
      return false; // La transacción revierte todo automáticamente, protegiendo el stock
    } finally {
      _isProcessingVenta = false;
      notifyListeners();
    }
  }
}