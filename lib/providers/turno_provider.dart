// lib/providers/turno_provider.dart

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/turno.dart';

class TurnoProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Turno? _turnoActivo;
  bool _isLoading = false;
  int _siguienteFolioVenta = 1;

  Turno? get turnoActivo => _turnoActivo;
  bool get isLoading => _isLoading;
  bool get hayTurnoActivo => _turnoActivo != null;
  int get siguienteFolioVenta => _siguienteFolioVenta;

  Future<void> cargarTurnoActivo() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'turnos',
        where: 'activo = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        _turnoActivo = Turno.fromMap(maps.first);
        await _calcularSiguienteFolio();
      } else {
        _turnoActivo = null;
        _siguienteFolioVenta = 1;
      }
    } catch (e) {
      debugPrint('Error al cargar turno activo: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _calcularSiguienteFolio() async {
    if (_turnoActivo == null) return;
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as total FROM ventas WHERE turno_id = ?',
        [_turnoActivo!.id],
      );
      final total = result.first['total'] as int;
      _siguienteFolioVenta = total + 1;
    } catch (e) {
      debugPrint('Error al calcular folio: $e');
      _siguienteFolioVenta = 1;
    }
  }

  Future<bool> abrirCaja(double montoInicial) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'turnos',
        {'activo': 0},
        where: 'activo = ?',
        whereArgs: [1],
      );

      final turno = Turno(
        montoInicial: montoInicial,
        fechaApertura: DateTime.now(),
        activo: true,
      );

      final id = await db.insert('turnos', turno.toMap());
      _turnoActivo = turno.copyWith(id: id);
      _siguienteFolioVenta = 1;

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error al abrir caja: $e');
      return false;
    }
  }

  Future<bool> cerrarCaja(double montoCierreReal) async {
    if (_turnoActivo == null) return false;

    try {
      final db = await _dbHelper.database;
      await db.update(
        'turnos',
        {
          'fecha_cierre': DateTime.now().toIso8601String(),
          'activo': 0,
          'monto_cierre': montoCierreReal,
        },
        where: 'id = ?',
        whereArgs: [_turnoActivo!.id],
      );

      _turnoActivo = null;
      _siguienteFolioVenta = 1;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error al cerrar caja: $e');
      return false;
    }
  }

  Future<int> obtenerYAvanzarFolio() async {
    final folio = _siguienteFolioVenta;
    _siguienteFolioVenta++;
    notifyListeners();
    return folio;
  }

  Future<void> refrescarFolio() async {
    await _calcularSiguienteFolio();
  }
}