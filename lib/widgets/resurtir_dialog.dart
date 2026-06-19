// lib/widgets/resurtir_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../providers/inventario_provider.dart';
import '../providers/turno_provider.dart';
import '../providers/finanzas_provider.dart';
import '../models/producto.dart';
import 'search_dropdown.dart';

class ResurtirDialog extends StatefulWidget {
  const ResurtirDialog({super.key});

  @override
  State<ResurtirDialog> createState() => _ResurtirDialogState();
}

class _ResurtirDialogState extends State<ResurtirDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController(text: '1');
  final TextEditingController _costoController = TextEditingController();
  final TextEditingController _nuevoPrecioController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  Producto? _productoSeleccionado;
  List<Producto> _sugerencias = [];
  bool _mostrarSugerencias = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    Future.delayed(const Duration(milliseconds: 200), () {
      _searchFocus.requestFocus();
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final provider = context.read<InventarioProvider>();

    if (query.isEmpty) {
      setState(() {
        _sugerencias = [];
        _mostrarSugerencias = false;
      });
    } else {
      setState(() {
        _sugerencias = provider.buscarProductos(query).take(10).toList();
        _mostrarSugerencias = _sugerencias.isNotEmpty;
      });
    }
  }

  void _seleccionarProducto(Producto producto) {
    setState(() {
      _productoSeleccionado = producto;
      _searchController.text = producto.nombre;
      _costoController.text = producto.costo.toStringAsFixed(2);
      _nuevoPrecioController.text = producto.precioVenta.toStringAsFixed(2);
      _mostrarSugerencias = false;
    });
  }

  Future<void> _confirmar() async {
    if (_productoSeleccionado == null) {
      _mostrarError('Selecciona un producto');
      return;
    }

    // 👈 CAMBIADO A DOUBLE PARA PERMITIR 1.500 KG
    final cantidad = double.tryParse(_cantidadController.text);
    final costo = double.tryParse(_costoController.text);
    final nuevoPrecio = double.tryParse(_nuevoPrecioController.text);

    if (cantidad == null || cantidad <= 0) {
      _mostrarError('Cantidad inválida');
      return;
    }
    if (costo == null || costo <= 0) {
      _mostrarError('Costo inválido');
      return;
    }
    if (nuevoPrecio == null || nuevoPrecio <= 0) {
      _mostrarError('Precio de venta inválido');
      return;
    }

    final turnoProvider = context.read<TurnoProvider>();
    if (!turnoProvider.hayTurnoActivo) {
      _mostrarError('No hay turno activo');
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<InventarioProvider>();
    final exito = await provider.resurtirProducto(
      productoId: _productoSeleccionado!.id!,
      cantidad: cantidad, // 👈 Si marca error en rojo en VS Code, cambia "int" por "double" en tu inventario_provider
      costoUnitario: costo,
      precioVenta: nuevoPrecio,
      turnoId: turnoProvider.turnoActivo!.id!,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (exito) {
        final finanzasProvider = context.read<FinanzasProvider>();
        await finanzasProvider.cargarBalance(turnoProvider.turnoActivo!.id!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto resurtido exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      } else {
        _mostrarError('Error al resurtir');
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cantidadController.dispose();
    _costoController.dispose();
    _nuevoPrecioController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
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
                    color: AppColors.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart,
                    color: AppColors.accentBlue,
                    size: AppSizes.iconLarge,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resurtir Producto',
                        style: TextStyle(
                          fontSize: AppSizes.titleSmall,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Escanea o busca el producto a resurtir',
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

            // Búsqueda de producto
            TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: const InputDecoration(
                labelText: 'Buscar Producto',
                hintText: 'Código o nombre...',
                prefixIcon: Icon(Icons.search),
              ),
            ),

            // Dropdown de sugerencias
            if (_mostrarSugerencias) ...[
              const SizedBox(height: AppSizes.paddingSmall),
              SearchDropdown<Producto>(
                items: _sugerencias,
                maxHeight: 200,
                onDismiss: () {
                  setState(() {
                    _mostrarSugerencias = false;
                  });
                },
                itemBuilder: (context, producto, isSelected) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      producto.nombreConUnidad,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'Stock actual: ${producto.aGranel ? producto.stock.toStringAsFixed(2) : producto.stock}',
                    ),
                    trailing: Text(
                      _currencyFormat.format(producto.precioVenta),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () => _seleccionarProducto(producto),
                  );
                },
                onItemSelected: _seleccionarProducto,
              ),
            ],

            const SizedBox(height: AppSizes.paddingLarge),

            // Campos de cantidad, costo y nuevo precio
            if (_productoSeleccionado != null) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cantidadController,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        helperText: 'Uds / Kgs',
                      ),
                      // 👈 CAMBIADO A DECIMAL CON 3 DÍGITOS PERMITIDOS
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingSmall),
                  Expanded(
                    child: TextField(
                      controller: _costoController,
                      decoration: const InputDecoration(
                        labelText: 'Costo unitario',
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingSmall),
                  Expanded(
                    child: TextField(
                      controller: _nuevoPrecioController,
                      decoration: const InputDecoration(
                        labelText: 'Nuevo Precio Venta',
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingLarge),
            ],

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
                    onPressed: (_productoSeleccionado != null && !_isLoading) ? _confirmar : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
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
                        : const Text('CONFIRMAR'),
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