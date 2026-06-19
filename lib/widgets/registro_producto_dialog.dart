// lib/widgets/registro_producto_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import '../models/producto.dart';
import '../database/database_helper.dart';

class RegistroProductoDialog extends StatefulWidget {
  final String codigoBusqueda;

  const RegistroProductoDialog({
    super.key,
    required this.codigoBusqueda,
  });

  @override
  State<RegistroProductoDialog> createState() => _RegistroProductoDialogState();
}

class _RegistroProductoDialogState extends State<RegistroProductoDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _costoController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _stockController = TextEditingController(text: '0');

  bool _aGranel = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _codigoController.text = widget.codigoBusqueda;
  }

  void _calcularPrecioSugerido() {
    final costo = double.tryParse(_costoController.text);
    if (costo != null && costo > 0) {
      final precioSugerido = Producto.calcularPrecioSugerido(costo);
      _precioController.text = precioSugerido.toStringAsFixed(2);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final producto = Producto(
        codigo: _codigoController.text.trim(),
        nombre: _nombreController.text.trim(),
        costo: double.parse(_costoController.text),
        precioVenta: double.parse(_precioController.text),
        // ⭐ CORRECCIÓN DEL ERROR ROJO: Ahora lo lee como decimal (double)
        stock: double.parse(_stockController.text.isEmpty ? '0' : _stockController.text),
        aGranel: _aGranel,
      );

      final db = await DatabaseHelper().database;
      final id = await db.insert('productos', producto.toMap());

      if (mounted) {
        Navigator.of(context).pop(producto.copyWith(id: id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nombreController.dispose();
    _costoController.dispose();
    _precioController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.paddingMedium),
                      decoration: BoxDecoration(
                        // ⭐ CORRECCIÓN DEL WARNING AMARILLO: withValues en lugar de withOpacity
                        color: AppColors.inventoryOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                      ),
                      child: const Icon(
                        Icons.add_shopping_cart,
                        color: AppColors.inventoryOrange,
                        size: AppSizes.iconLarge,
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingMedium),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Producto no encontrado',
                            style: TextStyle(
                              fontSize: AppSizes.titleSmall,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Registra el producto para continuar',
                            style: TextStyle(
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

                // Código
                TextFormField(
                  controller: _codigoController,
                  decoration: const InputDecoration(
                    labelText: 'Código *',
                    hintText: 'Código de barras o SKU',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El código es requerido';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSizes.paddingMedium),

                // Nombre
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Nombre del producto',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es requerido';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSizes.paddingMedium),

                // Costo y Precio
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costoController,
                        decoration: const InputDecoration(
                          labelText: 'Costo *',
                          prefixText: '\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        onChanged: (_) => _calcularPrecioSugerido(),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Requerido';
                          final costo = double.tryParse(value);
                          if (costo == null || costo <= 0) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingMedium),
                    Expanded(
                      child: TextFormField(
                        controller: _precioController,
                        decoration: const InputDecoration(
                          labelText: 'Precio Venta *',
                          prefixText: '\$ ',
                          helperText: '+25% sugerido',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Requerido';
                          final precio = double.tryParse(value);
                          if (precio == null || precio <= 0) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.paddingMedium),

                // Stock inicial
                TextFormField(
                  controller: _stockController,
                  decoration: InputDecoration(
                    labelText: 'Stock Inicial',
                    helperText: _aGranel ? 'Cantidad en kg/lt' : 'Cantidad en piezas',
                  ),
                  // ⭐ PERMITIMOS DECIMALES EN EL STOCK SI ES NECESARIO
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                  ],
                ),

                const SizedBox(height: AppSizes.paddingMedium),

                // Switch A Granel
                SwitchListTile(
                  title: const Text('Producto a Granel'),
                  subtitle: const Text('Se vende por peso o volumen (kg/lt)'),
                  value: _aGranel,
                  onChanged: (value) {
                    setState(() {
                      _aGranel = value;
                      // Si cambia a piezas y el stock tenía decimales, lo limpiamos un poco
                      if (!value && _stockController.text.contains('.')) {
                        _stockController.text = double.tryParse(_stockController.text)?.toInt().toString() ?? '0';
                      }
                    });
                  },
                  // ⭐ CORRECCIÓN DEL WARNING AMARILLO: activeThumbColor en lugar de activeColor
                  activeThumbColor: AppColors.inventoryOrange,
                ),

                const SizedBox(height: AppSizes.paddingLarge),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('CANCELAR'),
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingMedium),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.inventoryOrange,
                          foregroundColor: Colors.white,
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}