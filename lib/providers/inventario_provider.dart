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

  // ⭐ MEJORADO: Busca en código, nombre y códigos alternativos
  List<Producto> buscarProductos(String query) {
    if (query.isEmpty) return _productos;

    final queryLower = query.toLowerCase();
    return _productos.where((p) {
      // Búsqueda en nombre
      if (p.nombre.toLowerCase().contains(queryLower)) return true;
      
      // Búsqueda en código principal
      if (p.codigo.toLowerCase().contains(queryLower)) return true;
      
      // ⭐ NUEVO: Búsqueda en códigos alternativos
      final codigosAlternos = p.codigosAlternativosLista;
      if (codigosAlternos.any((c) => c.toLowerCase().contains(queryLower))) return true;
      
      return false;
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

  // ⭐ MEJORADO: Busca en código principal y alternativos
  Future<Producto?> buscarProductoPorCodigo(String codigo) async {
    try {
      final db = await _dbHelper.database;
      
      // Primero busca en código principal
      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: 'codigo = ?',
        whereArgs: [codigo],
      );
      
      if (maps.isNotEmpty) {
        return Producto.fromMap(maps.first);
      }
      
      // ⭐ NUEVO: Si no encuentra, busca en códigos alternativos
      final todosProductos = await db.query('productos');
      for (var map in todosProductos) {
        final producto = Producto.fromMap(map);
        final codigosAlternos = producto.codigosAlternativosLista;
        
        if (codigosAlternos.contains(codigo)) {
          // Encontró el código alternativo
          // Si tiene productoPadreId, devuelve el padre
          if (producto.productoPadreId != null) {
            final padreMapList = await db.query(
              'productos',
              where: 'id = ?',
              whereArgs: [producto.productoPadreId],
            );
            if (padreMapList.isNotEmpty) {
              return Producto.fromMap(padreMapList.first);
            }
          }
          // Si no tiene padre, devuelve él mismo
          return producto;
        }
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
    required double cantidad, // 👈 ¡CORREGIDO! AHORA ACEPTA DOUBLE (EJ: 1.500)
    required double costoUnitario,
    required double precioVenta,
    required int turnoId,
  }) async {
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

  // ⭐ NUEVO: Cargar productos relacionados (variantes del mismo producto)
  Future<List<Producto>> cargarProductosRelacionados(int productoPadreId) async {
    try {
      final db = await _dbHelper.database;
      
      final mapList = await db.query(
        'productos',
        where: 'producto_padre_id = ?',
        whereArgs: [productoPadreId],
      );
      
      return mapList.map((map) => Producto.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error al cargar productos relacionados: $e');
      return [];
    }
  }
}