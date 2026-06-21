// lib/providers/inventario_provider.dart

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/producto.dart';

class InventarioProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Producto> _productos = [];
  bool _isLoading = false;

  List<Producto> get productos => List.unmodifiable(_productos);
  bool get isLoading => _isLoading;

  double get totalInvertido {
    return _productos.fold(0.0, (sum, p) => sum + p.valorInventario);
  }

  Future<void> cargarProductos() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        orderBy: 'nombre ASC',
      );

      _productos = maps.map((map) => Producto.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error al cargar productos: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Producto> buscarProductos(String query) {
    if (query.isEmpty) return _productos;

    final queryLower = query.toLowerCase();
    return _productos.where((p) {
      return p.codigo.toLowerCase().contains(queryLower) ||
             p.nombre.toLowerCase().contains(queryLower);
    }).toList();
  }

  Future<Producto?> obtenerProductoPorId(int id) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return Producto.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error al obtener producto por ID: $e');
      return null;
    }
  }

  Future<Producto?> buscarProductoPorCodigo(String codigo) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: 'codigo = ?',
        whereArgs: [codigo],
      );

      if (maps.isNotEmpty) {
        return Producto.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error al buscar producto por código: $e');
      return null;
    }
  }

  Future<bool> agregarProducto(Producto producto) async {
    try {
      final db = await _dbHelper.database;

      // Verificar si el código ya existe
      final existe = await db.query(
        'productos',
        where: 'codigo = ?',
        whereArgs: [producto.codigo],
      );

      if (existe.isNotEmpty) {
        debugPrint('El código ya existe: ${producto.codigo}');
        return false;
      }

      await db.insert('productos', producto.toMap());
      await cargarProductos();
      return true;
    } catch (e) {
      debugPrint('Error al agregar producto: $e');
      return false;
    }
  }

  Future<bool> actualizarProducto(Producto producto) async {
    try {
      final db = await _dbHelper.database;
      // En modo edición, si cambia el código, verificar que no haya otro con el mismo código (excluyendo este producto)
      final existe = await db.query(
        'productos',
        where: 'codigo = ? AND id != ?',
        whereArgs: [producto.codigo, producto.id],
      );
      if (existe.isNotEmpty) {
        debugPrint('El código ya existe en otro producto: ${producto.codigo}');
        return false;
      }

      await db.update(
        'productos',
        producto.copyWith(
          fechaActualizacion: DateTime.now(),
        ).toMap(),
        where: 'id = ?',
        whereArgs: [producto.id],
      );
      await cargarProductos();
      return true;
    } catch (e) {
      debugPrint('Error al actualizar producto: $e');
      return false;
    }
  }

  Future<bool> eliminarProducto(int id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        'productos',
        where: 'id = ?',
        whereArgs: [id],
      );
      await cargarProductos();
      return true;
    } catch (e) {
      debugPrint('Error al eliminar producto: $e');
      return false;
    }
  }

  Future<bool> resurtirProducto({
    required int productoId,
    required double cantidad, // 👈 ACEPTA DOUBLE (EJ: 1.500)
    required double costoUnitario,
    required double precioVenta,
    required int turnoId,
  }) async {
    // ⭐ VALIDACIÓN CRÍTICA: Verifica que cantidad y costos sean válidos
    if (cantidad <= 0) {
      debugPrint('❌ CANTIDAD INVÁLIDA: $cantidad (debe ser > 0)');
      return false;
    }
    
    if (costoUnitario < 0 || precioVenta < 0) {
      debugPrint('❌ PRECIOS INVÁLIDOS: Costo=$costoUnitario, Venta=$precioVenta (no pueden ser negativos)');
      return false;
    }
    
    if (precioVenta < costoUnitario) {
      debugPrint('⚠️  ADVERTENCIA: Precio de venta (${precioVenta}) es menor al costo ($costoUnitario)');
      // No abortamos, es una advertencia solamente
    }
    
    try {
      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        // Actualizar stock, costo y precio de venta
        await txn.rawUpdate(
          'UPDATE productos SET stock = stock + ?, costo = ?, precio_venta = ? WHERE id = ?',
          [cantidad, costoUnitario, precioVenta, productoId],
        );

        // Registrar en surtidos
        await txn.insert('surtidos', {
          'turno_id': turnoId,
          'producto_id': productoId,
          'cantidad': cantidad,
          'costo_unitario': costoUnitario,
          'costo_total': costoUnitario * cantidad,
          'fecha': DateTime.now().toIso8601String(),
        });
      });

      await cargarProductos();
      return true;
    } catch (e) {
      debugPrint('Error al resurtir: $e');
      return false;
    }
  }
}