// lib/widgets/pago_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class PagoDialog extends StatelessWidget {
  final double total;
  
  PagoDialog({super.key, required this.total});
  
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  void _seleccionarMetodo(BuildContext context, String metodo) {
    Navigator.of(context).pop(metodo);
  }

  void _cancelar(BuildContext context) {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: Container(
        width: 600, // Aumentado ligeramente para que los botones tengan buen espacio horizontal
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono y Total en una disposición horizontal (ahorra espacio vertical)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingMedium),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.payment,
                    size: 45, // Ícono un poco más pequeño
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingLarge),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total a pagar:',
                      style: TextStyle(
                        fontSize: AppSizes.bodyLarge,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(total),
                      style: const TextStyle(
                        fontSize: 40, // Texto un poco más pequeño para encajar mejor
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: AppSizes.paddingLarge),
            
            // Título
            const Text(
              'Selecciona método de pago:',
              style: TextStyle(
                fontSize: AppSizes.titleSmall,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: AppSizes.paddingLarge),
            
            // Botones de pago UNO AL LADO DEL OTRO
            Row(
              children: [
                // Botón Efectivo
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _seleccionarMetodo(context, 'efectivo'),
                    icon: const Icon(Icons.money, size: AppSizes.iconLarge),
                    label: const Text(
                      'EFECTIVO',
                      style: TextStyle(
                        fontSize: AppSizes.bodyLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingLarge),
                    ),
                  ),
                ),
                
                const SizedBox(width: AppSizes.paddingMedium),
                
                // Botón Tarjeta
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _seleccionarMetodo(context, 'tarjeta'),
                    icon: const Icon(Icons.credit_card, size: AppSizes.iconLarge),
                    label: const Text(
                      'TARJETA',
                      style: TextStyle(
                        fontSize: AppSizes.bodyLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingLarge),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSizes.paddingLarge),
            
            // Botón cancelar
            TextButton(
              onPressed: () => _cancelar(context),
              child: const Text(
                'CANCELAR',
                style: TextStyle(
                  fontSize: AppSizes.bodyMedium,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}