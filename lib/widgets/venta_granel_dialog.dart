import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/producto.dart';

class VentaGranelDialog extends StatefulWidget {
  final Producto producto;

  const VentaGranelDialog({super.key, required this.producto});

  @override
  State<VentaGranelDialog> createState() => _VentaGranelDialogState();
}

class _VentaGranelDialogState extends State<VentaGranelDialog> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  
  bool _porPrecio = true; // true = por precio, false = por cantidad
  double? _cantidadCalculada;
  double? _precioCalculado;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      _inputFocus.requestFocus();
    });
    _inputController.addListener(_calcular);
  }

  void _calcular() {
    final input = double.tryParse(_inputController.text);
    if (input == null || input <= 0) {
      setState(() {
        _cantidadCalculada = null;
        _precioCalculado = null;
      });
      return;
    }

    if (_porPrecio) {
      // Usuario ingresó precio → calcular cantidad en kg
      final cantidad = input / widget.producto.precioVenta;
      setState(() {
        _cantidadCalculada = cantidad;
        _precioCalculado = input;
      });
    } else {
      // Usuario ingresó cantidad en gramos → calcular precio
      final cantidadKg = input / 1000; // convertir gramos a kg
      final precio = cantidadKg * widget.producto.precioVenta;
      setState(() {
        _cantidadCalculada = cantidadKg;
        _precioCalculado = precio;
      });
    }
  }

  void _confirmar() {
    if (_cantidadCalculada != null && _cantidadCalculada! > 0) {
      Navigator.of(context).pop(_cantidadCalculada);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingMedium),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.scale,
                    color: AppColors.accentBlue,
                    size: AppSizes.iconLarge,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.producto.nombre,
                        style: const TextStyle(
                          fontSize: AppSizes.titleSmall,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Precio: ${_currencyFormat.format(widget.producto.precioVenta)}/kg',
                        style: const TextStyle(
                          fontSize: AppSizes.bodyMedium,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.paddingLarge),

            // Selector: Por Precio / Por Cantidad
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Por Precio'),
                  icon: Icon(Icons.attach_money),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Por Gramos'),
                  icon: Icon(Icons.monitor_weight),
                ),
              ],
              selected: {_porPrecio},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _porPrecio = newSelection.first;
                  _inputController.clear();
                  _cantidadCalculada = null;
                  _precioCalculado = null;
                });
                Future.delayed(const Duration(milliseconds: 100), () {
                  _inputFocus.requestFocus();
                });
              },
            ),

            const SizedBox(height: AppSizes.paddingLarge),

            // Input
            TextField(
              controller: _inputController,
              focusNode: _inputFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: _porPrecio ? 'Ingresa el precio' : 'Ingresa los gramos',
                hintText: _porPrecio ? 'Ej: 10.00' : 'Ej: 500',
                prefixIcon: Icon(_porPrecio ? Icons.attach_money : Icons.scale),
                suffix: Text(
                  _porPrecio ? 'pesos' : 'g',
                  style: const TextStyle(
                    fontSize: AppSizes.bodyMedium,
                    color: AppColors.textSecondary,
                  ),
                ),
                filled: true,
                fillColor: AppColors.accentBlue.withOpacity(0.05),
              ),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.accentBlue,
              ),
              textAlign: TextAlign.center,
              onSubmitted: (_) => _confirmar(),
            ),

            const SizedBox(height: AppSizes.paddingLarge),

            // Resultado calculado
            if (_cantidadCalculada != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingMedium),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  border: Border.all(color: AppColors.success),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cantidad:',
                          style: TextStyle(fontSize: AppSizes.bodyLarge),
                        ),
                        Text(
                          '${_cantidadCalculada!.toStringAsFixed(3)} kg',
                          style: const TextStyle(
                            fontSize: AppSizes.bodyLarge,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total a cobrar:',
                          style: TextStyle(
                            fontSize: AppSizes.titleSmall,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(_precioCalculado),
                          style: const TextStyle(
                            fontSize: AppSizes.titleSmall,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSizes.paddingLarge),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCELAR'),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_cantidadCalculada != null && _cantidadCalculada! > 0)
                        ? _confirmar
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
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
