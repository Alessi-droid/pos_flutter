// lib/widgets/text_scale_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../constants/app_constants.dart';

class TextScaleDialog extends StatelessWidget {
  const TextScaleDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tamaño del texto de listas'),
      content: Consumer<ConfigProvider>(
        builder: (context, config, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ajusta el tamaño del contenido de las tablas para facilitar la lectura.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.paddingLarge),
              Text(
                'Tamaño actual: ${(config.textScaleFactor * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: config.textScaleFactor,
                min: 0.8, // 80% del tamaño original
                max: 2.0, // 200% del tamaño original (el doble)
                divisions: 12,
                activeColor: AppColors.primaryBlue,
                label: '${(config.textScaleFactor * 100).toInt()}%',
                onChanged: (value) {
                  config.setTextScaleFactor(value);
                },
              ),
              // Un texto de prueba para que veas cómo queda
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey[200],
                child: Text(
                  'Texto de ejemplo',
                  style: TextStyle(fontSize: AppSizes.bodyMedium * config.textScaleFactor),
                ),
              )
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CERRAR'),
        ),
      ],
    );
  }
}