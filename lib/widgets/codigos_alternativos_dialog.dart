// lib/widgets/codigos_alternativos_dialog.dart - NUEVO DIALOG PARA AGREGAR CÓDIGOS ALTERNATIVOS

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import '../models/producto.dart';
import '../database/database_helper.dart';

class CodigosAlternativosDialog extends StatefulWidget {
  final Producto producto;
  
  const CodigosAlternativosDialog({super.key, required this.producto});

  @override
  State<CodigosAlternativosDialog> createState() => _CodigosAlternativosDialogState();
}

class _CodigosAlternativosDialogState extends State<CodigosAlternativosDialog> {
  late TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final codigos = widget.producto.codigosAlternativosLista.join(', ');
    _controller = TextEditingController(text: codigos);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _guardar() async {
    final nuevoCodigos = _controller.text
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .join(',');

    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper().database;
      await (await db).update(
        'productos',
        {'codigos_alternativos': nuevoCodigos.isEmpty ? null : nuevoCodigos},
        where: 'id = ?',
        whereArgs: [widget.producto.id],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Códigos alternativos guardados'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true); // Retorna true para indicar que se guardó
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Códigos Alternativos'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Producto: ${widget.producto.nombre}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Text('Código Principal: ${widget.producto.codigo}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            const Text('Códigos Alternativos:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 3,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'Ejemplo: 654321, 111111, 222222',
                helperText: 'Separados por comas',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💡 Los códigos alternativos permiten que este producto se venda con múltiples códigos de barras (de diferentes distribuidores). Todos comparten el MISMO stock.',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('GUARDAR'),
        ),
      ],
    );
  }
}
