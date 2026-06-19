// lib/widgets/devolucion_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/producto.dart';
import '../providers/inventario_provider.dart';

class DevolucionDialog extends StatefulWidget {
  final int turnoId;

  const DevolucionDialog({super.key, required this.turnoId});

  @override
  State<DevolucionDialog> createState() => _DevolucionDialogState();
}

class _DevolucionDialogState extends State<DevolucionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController(text: '1');
  final FocusNode _searchFocus = FocusNode();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  Producto? _productoEncontrado;
  List<Producto> _sugerencias = [];
  bool _mostrarSugerencias = false;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Cargar productos al abrir por si acaso
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventarioProvider>().cargarProductos();
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      _searchFocus.requestFocus();
    });
  }

  // ⭐ NUEVO: Buscador inteligente idéntico al de ventas/mermas
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
        _sugerencias = provider.buscarProductos(query).take(6).toList();
        _mostrarSugerencias = _sugerencias.isNotEmpty;
      });
    }
  }

  void _seleccionarProducto(Producto producto) {
    setState(() {
      _productoEncontrado = producto;
      _searchController.text = producto.nombre;
      _mostrarSugerencias = false;
    });
  }

  Future<void> _procesarDevolucion() async {
    if (_productoEncontrado == null) {
      _mostrarError('Primero escanea o selecciona un producto');
      return;
    }

    final cantidad = double.tryParse(_cantidadController.text);
    if (cantidad == null || cantidad <= 0) {
      _mostrarError('Cantidad inválida');
      return;
    }

    setState(() => _procesando = true);

    try {
      final db = await DatabaseHelper().database;

      await db.transaction((txn) async {
        // 1. Buscar última venta de este producto en este turno (Se mantiene tu lógica intacta)
        final ultimaVenta = await txn.rawQuery('''
          SELECT vd.*, v.metodo_pago, v.folio
          FROM venta_detalle vd
          JOIN ventas v ON vd.venta_id = v.id
          WHERE vd.producto_id = ? AND v.turno_id = ?
          ORDER BY v.fecha DESC
          LIMIT 1
        ''', [_productoEncontrado!.id, widget.turnoId]);

        if (ultimaVenta.isEmpty) {
          throw Exception('No has vendido este producto durante este turno');
        }

        final detalleVenta = ultimaVenta.first;
        final cantidadVendida = (detalleVenta['cantidad'] as num).toDouble();
        final precioUnitario = (detalleVenta['precio_unitario'] as num).toDouble();
        final montoDevolver = precioUnitario * cantidad;

        if (cantidad > cantidadVendida) {
          throw Exception('Intentas devolver más cantidad de la que vendiste en ese ticket');
        }

        // 2. Devolver stock
        await txn.rawUpdate(
          'UPDATE productos SET stock = stock + ? WHERE id = ?',
          [cantidad, _productoEncontrado!.id],
        );

        // 3. Actualizar cantidad en venta_detalle (restar devuelto)
        final nuevaCantidad = cantidadVendida - cantidad;
        if (nuevaCantidad > 0) {
          await txn.rawUpdate(
            'UPDATE venta_detalle SET cantidad = ?, subtotal = ? WHERE id = ?',
            [nuevaCantidad, precioUnitario * nuevaCantidad, detalleVenta['id']],
          );
        } else {
          await txn.delete('venta_detalle', where: 'id = ?', whereArgs: [detalleVenta['id']]);
        }

        // 4. Actualizar total de la venta
        await txn.rawUpdate(
          'UPDATE ventas SET total = total - ? WHERE id = ?',
          [montoDevolver, detalleVenta['venta_id']],
        );

        // 5. Registrar devolución como gasto negativo (ingreso)
        await txn.insert('gastos_operativos', {
          'turno_id': widget.turnoId,
          'tipo': 'devolucion',
          'concepto': 'Devolución: ${_productoEncontrado!.nombre} (Folio: ${detalleVenta['folio']})',
          'monto': -montoDevolver,
          'fecha': DateTime.now().toIso8601String(),
        });
      });

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Devolución procesada: ${_currencyFormat.format(_productoEncontrado!.precioVenta * cantidad)}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: AppColors.error));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cantidadController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
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
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(AppSizes.radiusSmall)),
                  child: const Icon(Icons.assignment_return, color: Colors.orange, size: AppSizes.iconLarge),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Devolución de Producto', style: TextStyle(fontSize: AppSizes.titleSmall, fontWeight: FontWeight.bold)),
                      Text('Busca el producto a devolver del turno actual', style: TextStyle(fontSize: AppSizes.bodyMedium, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingLarge),

            // ⭐ NUEVO: Buscador inteligente en devoluciones
            TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                labelText: 'Buscar Producto',
                hintText: 'Escanea o escribe el nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _productoEncontrado = null); _searchFocus.requestFocus(); })
                    : null,
              ),
            ),

            // Sugerencias
            if (_mostrarSugerencias)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(AppSizes.radiusSmall), color: Colors.white),
                child: ListView.separated(
                  shrinkWrap: true, itemCount: _sugerencias.length, separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = _sugerencias[index];
                    return ListTile(
                      dense: true, title: Text(p.nombre),
                      trailing: Text(_currencyFormat.format(p.precioVenta), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      onTap: () => _seleccionarProducto(p),
                    );
                  },
                ),
              ),

            const SizedBox(height: AppSizes.paddingMedium),

            // Producto encontrado
            if (_productoEncontrado != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingMedium),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(AppSizes.radiusSmall), border: Border.all(color: AppColors.success)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success),
                        const SizedBox(width: AppSizes.paddingSmall),
                        Expanded(child: Text(_productoEncontrado!.nombre, style: const TextStyle(fontSize: AppSizes.bodyLarge, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: AppSizes.paddingSmall),
                    Text('Se devolverá al inventario: ${_currencyFormat.format(_productoEncontrado!.precioVenta)} / ud', style: const TextStyle(fontSize: AppSizes.bodyMedium)),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.paddingMedium),

              // Cantidad
              TextField(
                controller: _cantidadController,
                decoration: InputDecoration(
                  labelText: 'Cantidad a devolver',
                  suffix: Text(_productoEncontrado!.aGranel ? 'kg' : 'pz', style: const TextStyle(fontSize: AppSizes.bodyMedium, color: AppColors.textSecondary)),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: _productoEncontrado!.aGranel),
                inputFormatters: _productoEncontrado!.aGranel ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))] : [FilteringTextInputFormatter.digitsOnly],
              ),
            ],

            const SizedBox(height: AppSizes.paddingLarge),

            // Botones
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _procesando ? null : () => Navigator.of(context).pop(), child: const Text('CANCELAR'))),
                const SizedBox(width: AppSizes.paddingMedium),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_procesando || _productoEncontrado == null) ? null : _procesarDevolucion,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    child: _procesando ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('DEVOLVER'),
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