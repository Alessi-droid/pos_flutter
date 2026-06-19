import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

class AperturaCajaDialog extends StatefulWidget {
  const AperturaCajaDialog({super.key});

  @override
  State<AperturaCajaDialog> createState() => _AperturaCajaDialogState();
}

class _AperturaCajaDialogState extends State<AperturaCajaDialog> {
  final TextEditingController _montoController = TextEditingController(text: '0.00');
  final FocusNode _montoFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      _montoFocus.requestFocus();
      _montoController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _montoController.text.length,
      );
    });
  }

  void _confirmar() {
    final monto = double.tryParse(_montoController.text);
    if (monto != null && monto >= 0) {
      Navigator.of(context).pop(monto);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un monto válido'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _montoFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppSizes.paddingLarge * 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono
            Container(
              padding: const EdgeInsets.all(AppSizes.paddingLarge),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront,
                size: 60,
                color: AppColors.accentBlue,
              ),
            ),
            
            const SizedBox(height: AppSizes.paddingLarge),
            
            // Título
            const Text(
              '¡BUENOS DÍAS!',
              style: TextStyle(
                fontSize: AppSizes.titleLarge,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: AppSizes.paddingSmall),
            
            // Subtítulo
            const Text(
              'Apertura de Caja',
              style: TextStyle(
                fontSize: AppSizes.bodyLarge,
                color: AppColors.textSecondary,
              ),
            ),
            
            const SizedBox(height: AppSizes.paddingMedium),
            
            // Instrucciones
            const Text(
              'Ingresa el dinero en efectivo con el que\ninicias operaciones hoy:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.bodyMedium,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: AppSizes.paddingLarge),
            
            // Campo de monto
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '\$',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingSmall),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _montoController,
                    focusNode: _montoFocus,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                    ),
                    onSubmitted: (_) => _confirmar(),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSizes.paddingLarge * 1.5),
            
            // Botón confirmar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingLarge),
                ),
                child: const Text(
                  'ABRIR CAJA',
                  style: TextStyle(
                    fontSize: AppSizes.bodyLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
