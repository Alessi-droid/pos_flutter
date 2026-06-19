// lib/utils/backup_helper.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class BackupHelper {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Exporta TODA la base de datos a un archivo JSON y lo comparte
  Future<bool> exportarDatabase(BuildContext context) async {
    try {
      // NOTA: En Android 11+ no se requieren permisos de almacenamiento 
      // si usamos getTemporaryDirectory() y share_plus.
      
      final db = await _dbHelper.database;

      // Obtener todas las tablas de la base de datos
      List<Map<String, dynamic>> tablas = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );

      Map<String, dynamic> backupData = {};

      for (var tabla in tablas) {
        String nombreTabla = tabla['name'] as String;
        List<Map<String, dynamic>> registros = await db.query(nombreTabla);
        backupData[nombreTabla] = registros;
      }

      // Agregar metadatos
      backupData['_metadata'] = {
        'version': 3,
        'fecha': DateTime.now().toIso8601String(),
        'app': 'POS Tablet v7',
      };

      String jsonString = jsonEncode(backupData);

      // Guardar en archivo temporal en la carpeta privada de la app
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'backup_pos_${DateTime.now().millisecondsSinceEpoch}.json';
      final File file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString, flush: true);

      // Compartir archivo (el usuario elige dónde guardarlo: Drive, Descargas, etc.)
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Respaldo de base de datos POS',
      );

      return true;
    } catch (e) {
      debugPrint('Error al exportar: $e');
      if (context.mounted) {
        _mostrarError(context, 'Error al exportar: $e');
      }
      return false;
    }
  }

  /// Importa un archivo JSON y reemplaza la base de datos actual
  Future<bool> importarDatabase(BuildContext context) async {
    try {
      // NOTA: En Android 11+ file_picker usa el Storage Access Framework, 
      // por lo que el sistema otorga permisos temporalmente de forma automática.

      // Seleccionar archivo JSON
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null) {
        debugPrint('No se seleccionó ningún archivo');
        return false;
      }

      final String filePath = result.files.single.path!;
      final File file = File(filePath);
      
      if (!await file.exists()) {
        if (context.mounted) _mostrarError(context, 'El archivo no existe');
        return false;
      }

      final String jsonString = await file.readAsString();
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      // Validar metadata
      if (!backupData.containsKey('_metadata')) {
        if (context.mounted) _mostrarError(context, 'Archivo de respaldo inválido (sin metadatos)');
        return false;
      }

      // Verificar versión (opcional)
      final int versionBackup = backupData['_metadata']['version'] ?? 0;
      if (versionBackup < 3) {
        if (context.mounted) {
          final confirmar = await _mostrarConfirmacion(
            context,
            'Versión antigua',
            'El respaldo es de una versión anterior (v$versionBackup). ¿Continuar de todos modos?',
          );
          if (!confirmar) return false;
        }
      }

      // Cerrar conexión actual y resetear BD
      await _dbHelper.close();
      await _dbHelper.resetDatabase();

      // Pequeña pausa para asegurar que el archivo de BD se libere
      await Future.delayed(const Duration(milliseconds: 500));

      // Abrir nueva conexión
      final db = await _dbHelper.database;

      // Ejecutar en transacción
      await db.transaction((txn) async {
        // Obtener tablas del backup (excluir metadata)
        List<String> tablasBackup = backupData.keys
            .where((key) => key != '_metadata')
            .toList();

        for (String tabla in tablasBackup) {
          // Eliminar registros actuales
          await txn.delete(tabla);

          // Insertar registros del backup
          List registros = backupData[tabla] as List;
          for (var registro in registros) {
            try {
              await txn.insert(tabla, registro);
            } catch (e) {
              debugPrint('Error insertando en $tabla: $e');
              // Continuar con el siguiente registro
            }
          }
        }
      });

      return true;
    } catch (e) {
      debugPrint('Error al importar: $e');
      if (context.mounted) {
        _mostrarError(context, 'Error al importar: $e');
      }
      return false;
    }
  }

  void _mostrarError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<bool> _mostrarConfirmacion(
    BuildContext context,
    String titulo,
    String mensaje,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(titulo),
            content: Text(mensaje),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('CONTINUAR'),
              ),
            ],
          ),
        ) ??
        false;
  }
}