// lib/widgets/gasto_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/producto.dart';
import '../providers/finanzas_provider.dart';
import '../providers/inventario_provider.dart';

enum GastoType { operativo, merma }

class GastoDialog extends StatefulWidget {
  final int turnoId;
  final GastoType initialType;

  const GastoDialog({
    super.key,
    required this.turnoId,
    this.initialType = GastoType.operativo,
  });

  @override
  State<GastoDialog> createState() => _GastoDialogState();
}

class _GastoDialogState extends State<GastoDialog> {
  late GastoType _selectedType;

  String? _conceptoSeleccionado;
  String? _motivoSeleccionado;
  final TextEditingController _montoController = TextEditingController();

  final TextEditingController _buscarController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController(text: '1');

  Producto? _productoSeleccionado;
  List<Producto> _sugerencias = [];
  bool _mostrarSugerencias = false;

  final FocusNode _montoFocus = FocusNode();
  final FocusNode _buscarFocus = FocusNode();
  final FocusNode _cantidadFocus = FocusNode();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _buscarController.addListener(_onBuscarChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventarioProvider>().cargarProductos();
      context.read<FinanzasProvider>().cargarCatalogoCategorias();
      if (_selectedType == GastoType.merma) _buscarFocus.requestFocus();
    });
  }

  void _onBuscarChanged() {
    final query = _buscarController.text;
    final provider = context.read<InventarioProvider>();

    if (query.isEmpty) {
      setState(() { _sugerencias = []; _mostrarSugerencias = false; });
    } else {
      setState(() {
        _sugerencias = provider.buscarProductos(query).take(5).toList();
        _mostrarSugerencias = _sugerencias.isNotEmpty;
      });
    }
  }

  void _seleccionarProducto(Producto producto) {
    setState(() {
      _productoSeleccionado = producto;
      _buscarController.text = producto.nombre;
      _mostrarSugerencias = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () => _cantidadFocus.requestFocus());
  }

  Future<void> _guardar() async {
    if (_selectedType == GastoType.operativo) {
      if (_conceptoSeleccionado == null) { _mostrarError('Selecciona una categoría'); return; }
      final monto = double.tryParse(_montoController.text);
      if (monto == null || monto <= 0) { _mostrarError('Monto inválido'); return; }

      setState(() => _isLoading = true);
      final exito = await context.read<FinanzasProvider>().registrarGastoOperativo(turnoId: widget.turnoId, concepto: _conceptoSeleccionado!, monto: monto);

      if (mounted) {
        setState(() => _isLoading = false);
        if (exito) Navigator.pop(context, true); else _mostrarError('Error al guardar gasto');
      }
    } else {
      if (_productoSeleccionado == null) { _mostrarError('Selecciona un producto'); return; }
      final cantidad = double.tryParse(_cantidadController.text);
      if (cantidad == null || cantidad <= 0) { _mostrarError('Cantidad inválida'); return; }
      if (_motivoSeleccionado == null) { _mostrarError('Selecciona el motivo de la merma'); return; }

      setState(() => _isLoading = true);
      final valorPerdido = _productoSeleccionado!.precioVenta * cantidad;

      final exito = await context.read<FinanzasProvider>().registrarMerma(turnoId: widget.turnoId, productoId: _productoSeleccionado!.id!, cantidad: cantidad, motivo: _motivoSeleccionado!, valorPerdido: valorPerdido);

      if (mounted) {
        setState(() => _isLoading = false);
        if (exito) Navigator.pop(context, true); else _mostrarError('Error al registrar merma');
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: AppColors.error));
  }

  void _abrirGestorCategorias() {
    showDialog(
      context: context,
      builder: (context) => _GestorCategoriasDialog(tipo: _selectedType == GastoType.operativo ? 'gasto' : 'merma'),
    ).then((_) {
      // Al cerrar el gestor, verificamos si la selección actual sigue existiendo
      final finanzas = context.read<FinanzasProvider>();
      setState(() {
        if (_selectedType == GastoType.operativo && _conceptoSeleccionado != null) {
          if (!finanzas.categoriasGasto.any((c) => c['nombre'] == _conceptoSeleccionado)) _conceptoSeleccionado = null;
        } else if (_motivoSeleccionado != null) {
          if (!finanzas.categoriasMerma.any((c) => c['nombre'] == _motivoSeleccionado)) _motivoSeleccionado = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    _buscarController.dispose();
    _cantidadController.dispose();
    _montoFocus.dispose();
    _buscarFocus.dispose();
    _cantidadFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<FinanzasProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(AppSizes.paddingMedium), decoration: BoxDecoration(color: AppColors.financeRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppSizes.radiusSmall)), child: const Icon(Icons.receipt, color: AppColors.financeRed, size: AppSizes.iconLarge)),
                const SizedBox(width: AppSizes.paddingMedium),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Registrar Gasto', style: TextStyle(fontSize: AppSizes.titleSmall, fontWeight: FontWeight.bold)), Text('Gasto operativo o merma', style: TextStyle(fontSize: AppSizes.bodyMedium, color: AppColors.textSecondary))])),
              ],
            ),
            const SizedBox(height: AppSizes.paddingLarge),

            Center(
              child: SegmentedButton<GastoType>(
                segments: const [
                  ButtonSegment(value: GastoType.operativo, icon: Icon(Icons.money_off), label: Text('Gasto Operativo')),
                  ButtonSegment(value: GastoType.merma, icon: Icon(Icons.delete_forever), label: Text('Merma')),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<GastoType> newSelection) => setState(() {
                  _selectedType = newSelection.first;
                  _conceptoSeleccionado = null;
                  _motivoSeleccionado = null;
                }),
                style: ButtonStyle(backgroundColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) => states.contains(WidgetState.selected) ? AppColors.financeBlue : null)),
              ),
            ),
            const SizedBox(height: AppSizes.paddingLarge),

            if (_selectedType == GastoType.operativo) ...[
              // ⭐ DROPDOWN ESTRICTO PARA GASTOS + BOTÓN DE ADMINISTRAR
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Categoría del Gasto', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                      value: _conceptoSeleccionado,
                      items: finanzas.categoriasGasto.map((c) => DropdownMenuItem(value: c['nombre'].toString(), child: Text(c['nombre']))).toList(),
                      onChanged: (val) { setState(() => _conceptoSeleccionado = val); _montoFocus.requestFocus(); },
                      hint: const Text('Selecciona una categoría...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.blueGrey, size: 32),
                    tooltip: 'Administrar Categorías',
                    onPressed: _abrirGestorCategorias,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingMedium),
              TextField(
                controller: _montoController, focusNode: _montoFocus,
                decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$ ', prefixIcon: Icon(Icons.attach_money)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                onSubmitted: (_) => _guardar(),
              ),
            ] else ...[
              TextField(
                controller: _buscarController, focusNode: _buscarFocus,
                decoration: const InputDecoration(labelText: 'Buscar Producto', hintText: 'Código o nombre...', prefixIcon: Icon(Icons.search)),
              ),
              const SizedBox(height: AppSizes.paddingSmall),
              if (_mostrarSugerencias)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200), decoration: BoxDecoration(border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(AppSizes.radiusSmall)),
                  child: ListView.separated(
                    shrinkWrap: true, itemCount: _sugerencias.length, separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final producto = _sugerencias[index];
                      return ListTile(
                        dense: true, title: Text(producto.nombre),
                        subtitle: Text('Stock: ${producto.aGranel ? producto.stock.toStringAsFixed(2) : producto.stock} • Precio: ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(producto.precioVenta)}'),
                        onTap: () => _seleccionarProducto(producto),
                      );
                    },
                  ),
                ),
              if (_productoSeleccionado != null) ...[
                const SizedBox(height: AppSizes.paddingMedium),
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingSmall), decoration: BoxDecoration(color: AppColors.financeBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppSizes.radiusSmall)),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory, size: AppSizes.iconSmall), const SizedBox(width: AppSizes.paddingSmall),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_productoSeleccionado!.nombre, style: const TextStyle(fontWeight: FontWeight.bold)), Text('Precio venta: ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(_productoSeleccionado!.precioVenta)}', style: const TextStyle(fontSize: 12))])),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.paddingMedium),
                TextField(
                  controller: _cantidadController, focusNode: _cantidadFocus,
                  decoration: InputDecoration(labelText: 'Cantidad a descontar', suffixText: _productoSeleccionado!.aGranel ? 'kg' : 'pz', prefixIcon: const Icon(Icons.numbers)),
                  keyboardType: TextInputType.numberWithOptions(decimal: _productoSeleccionado!.aGranel),
                  inputFormatters: _productoSeleccionado!.aGranel ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))] : [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: AppSizes.paddingMedium),

                // ⭐ DROPDOWN ESTRICTO PARA MERMAS + BOTÓN DE ADMINISTRAR
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Motivo de la merma', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                        value: _motivoSeleccionado,
                        items: finanzas.categoriasMerma.map((c) => DropdownMenuItem(value: c['nombre'].toString(), child: Text(c['nombre']))).toList(),
                        onChanged: (val) => setState(() => _motivoSeleccionado = val),
                        hint: const Text('Selecciona el motivo...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.blueGrey, size: 32),
                      tooltip: 'Administrar Motivos',
                      onPressed: _abrirGestorCategorias,
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: AppSizes.paddingLarge * 1.5),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _isLoading ? null : () => Navigator.pop(context, false), child: const Text('CANCELAR'))),
                const SizedBox(width: AppSizes.paddingMedium),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _guardar,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeRed, foregroundColor: Colors.white),
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('GUARDAR'),
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

// ============================================================================
// EL SUB-DIÁLOGO: ADMINISTRADOR DE CATEGORÍAS
// ============================================================================
class _GestorCategoriasDialog extends StatefulWidget {
  final String tipo; // 'gasto' o 'merma'
  const _GestorCategoriasDialog({required this.tipo});

  @override
  State<_GestorCategoriasDialog> createState() => _GestorCategoriasDialogState();
}

class _GestorCategoriasDialogState extends State<_GestorCategoriasDialog> {
  final TextEditingController _nuevaController = TextEditingController();

  Future<void> _agregar() async {
    final text = _nuevaController.text.trim();
    if (text.isEmpty) return;
    await context.read<FinanzasProvider>().agregarCategoria(text, widget.tipo);
    _nuevaController.clear();
  }

  Future<void> _editar(Map<String, dynamic> categoria) async {
    final ctrl = TextEditingController(text: categoria['nombre']);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Categoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 8),
            const Text('⚠️ IMPORTANTE: Editar este nombre corregirá automáticamente todos los tickets pasados que usaban este nombre.', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('GUARDAR CAMBIOS')),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && result != categoria['nombre'] && mounted) {
      await context.read<FinanzasProvider>().editarCategoria(categoria['id'], categoria['nombre'], result, widget.tipo);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoría e historial actualizados.'), backgroundColor: AppColors.success));
    }
  }

  Future<void> _eliminar(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar categoría'),
        content: const Text('¿Borrar esta categoría del menú? (Los gastos pasados no se borrarán)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('BORRAR')),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await context.read<FinanzasProvider>().eliminarCategoria(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<FinanzasProvider>();
    final lista = widget.tipo == 'gasto' ? finanzas.categoriasGasto : finanzas.categoriasMerma;

    return Dialog(
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.tipo == 'gasto' ? 'Administrar Gastos' : 'Administrar Mermas', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(child: TextField(controller: _nuevaController, decoration: const InputDecoration(hintText: 'Nueva categoría...', isDense: true, border: OutlineInputBorder()), onSubmitted: (_) => _agregar())),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 32), onPressed: _agregar),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: lista.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cat = lista[index];
                  return ListTile(
                    title: Text(cat['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: 'Editar e impactar historial', onPressed: () => _editar(cat)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Quitar del menú', onPressed: () => _eliminar(cat['id'])),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}