// lib/widgets/cantidad_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import '../models/producto.dart';

class CantidadDialog extends StatefulWidget {
  final Producto producto;
  
  const CantidadDialog({
    super.key,
    required this.producto,
  });

  @override
  State<CantidadDialog> createState() => _CantidadDialogState();
}

class _CantidadDialogState extends State<CantidadDialog> {
  final TextEditingController _cantidadController = TextEditingController(text: '1');
  final FocusNode _cantidadFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      _cantidadFocus.requestFocus();
      _cantidadController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _cantidadController.text.length,
      );
    });
  }

  void _confirmar() {
    final cantidad = double.tryParse(_cantidadController.text);
    if (cantidad != null && cantidad > 0) {
      Navigator.of(context).pop(cantidad);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una cantidad válida'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _cancelar() {
    Navigator.of(context).pop(null);
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _cantidadFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool esGranel = widget.producto.aGranel;
    final String unidad = widget.producto.unidadMedida ?? (esGranel ? 'kg' : 'pz');
    final String titulo = esGranel ? 'Peso ($unidad)' : 'Cantidad';
    final String ayuda = esGranel ? 'Ingresa el peso en $unidad' : 'Ingresa la cantidad';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Producto seleccionado
            Text(
              widget.producto.nombreConUnidad,
              style: const TextStyle(
                fontSize: AppSizes.titleSmall,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppSizes.paddingMedium),
            
            // Instrucción
            Text(
              ayuda,
              style: const TextStyle(
                fontSize: AppSizes.bodyLarge,
                color: AppColors.textSecondary,
              ),
            ),
            
            const SizedBox(height: AppSizes.paddingMedium),
            
            // Campo de cantidad
            TextField(
              controller: _cantidadController,
              focusNode: _cantidadFocus,
              keyboardType: TextInputType.numberWithOptions(
                decimal: esGranel,
              ),
              inputFormatters: esGranel
                  ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]
                  : [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.primaryBlue.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                suffix: Text(
                  unidad,
                  style: const TextStyle(
                    fontSize: AppSizes.bodyMedium,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              onSubmitted: (_) => _confirmar(),
            ),
            
            const SizedBox(height: AppSizes.paddingLarge),
            
            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelar,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingMedium),
                    ),
                    child: const Text('CANCELAR'),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingMedium),
                    ),
                    child: const Text('AGREGAR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}