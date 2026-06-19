// lib/screens/inventario_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../providers/inventario_provider.dart';
import '../providers/turno_provider.dart';
import '../providers/finanzas_provider.dart';
import '../providers/config_provider.dart';
import '../models/producto.dart';
import '../widgets/producto_form_dialog.dart';
import '../widgets/search_dropdown.dart';
import '../widgets/text_scale_dialog.dart';
import '../screens/merma_screen.dart';
import '../utils/backup_helper.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocus;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  List<Producto> _sugerencias = [];
  bool _mostrarSugerencias = false;
  int _selectedSuggestionIndex = -1;
  List<Producto> _productosFiltrados = [];

  @override
  void initState() {
    super.initState();
    _searchFocus = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (_mostrarSugerencias) {
            if (key == LogicalKeyboardKey.arrowDown) {
              setState(() { if (_selectedSuggestionIndex < _sugerencias.length - 1) _selectedSuggestionIndex++; });
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.arrowUp) {
              setState(() { if (_selectedSuggestionIndex > 0) _selectedSuggestionIndex--; });
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventarioProvider>().cargarProductos();
      _searchFocus.requestFocus();
    });
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final provider = context.read<InventarioProvider>();

    if (query.isEmpty) {
      setState(() {
        _sugerencias = [];
        _mostrarSugerencias = false;
        _selectedSuggestionIndex = -1;
        _productosFiltrados = provider.productos;
      });
    } else {
      final resultados = provider.buscarProductos(query);
      setState(() {
        _sugerencias = resultados.take(10).toList();
        _mostrarSugerencias = _sugerencias.isNotEmpty;
        _selectedSuggestionIndex = _sugerencias.isNotEmpty ? 0 : -1;
        _productosFiltrados = resultados;
      });
    }
  }

  Future<void> _mostrarFormularioProducto({Producto? producto, String? codigoInicial}) async {
    final resultado = await showDialog<dynamic>(
      context: context,
      builder: (context) => ProductoFormDialog(producto: producto, codigoInicial: codigoInicial),
    );

    _searchController.clear();
    setState(() => _mostrarSugerencias = false);

    if (resultado != null && resultado != false) {
      context.read<InventarioProvider>().cargarProductos();
    }

    _searchFocus.requestFocus();
  }

  Future<void> _mostrarMerma() async {
    final turnoProvider = context.read<TurnoProvider>();
    if (!turnoProvider.hayTurnoActivo) { _mostrarError('No hay turno activo'); return; }
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const MermaScreen()));
    if (mounted) {
      await context.read<InventarioProvider>().cargarProductos();
      if (turnoProvider.hayTurnoActivo) await context.read<FinanzasProvider>().cargarBalance(turnoProvider.turnoActivo!.id!);
    }
    _searchFocus.requestFocus();
  }

  Future<void> _exportarBackup() async {
    final backupHelper = BackupHelper();
    final exito = await backupHelper.exportarDatabase(context);
    if (exito) _mostrarExito('Respaldo exportado correctamente');
    else _mostrarError('Error al exportar respaldo');
  }

  Future<void> _importarBackup() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar respaldo'),
        content: const Text('Esta acción reemplazará TODA la base de datos actual.\n¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('IMPORTAR')),
        ],
      ),
    );
    if (confirmar != true) return;
    final backupHelper = BackupHelper();
    final exito = await backupHelper.importarDatabase(context);
    if (exito) {
      await context.read<InventarioProvider>().cargarProductos();
      final turnoProvider = context.read<TurnoProvider>();
      await turnoProvider.cargarTurnoActivo();
      if (turnoProvider.hayTurnoActivo) await context.read<FinanzasProvider>().cargarBalance(turnoProvider.turnoActivo!.id!);
      _mostrarExito('Base de datos restaurada correctamente');
    } else {
      _mostrarError('Error al importar respaldo');
    }
    _searchFocus.requestFocus();
  }

  void _mostrarStockBajo() {
    final provider = context.read<InventarioProvider>();
    final productosBajoStock = provider.productos.where((p) => p.stock < p.stockMinimo).toList();
    if (productosBajoStock.isEmpty) { _mostrarExito('No hay productos con stock bajo'); return; }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Productos con Stock Bajo'),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: productosBajoStock.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final p = productosBajoStock[index];
              return ListTile(
                title: Text(p.nombreConUnidad),
                subtitle: Text('Stock: ${p.aGranel ? p.stock.toStringAsFixed(2) : p.stock.toInt()} / Mínimo: ${p.aGranel ? p.stockMinimo.toStringAsFixed(2) : p.stockMinimo.toInt()}'),
                trailing: Text(_currencyFormat.format(p.costo), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(context); _mostrarFormularioProducto(producto: p); },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR'))],
      ),
    );
  }

  void _mostrarError(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: AppColors.error));
  void _mostrarExito(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: AppColors.success));

  Future<void> _confirmarEliminar(Producto producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar "${producto.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('ELIMINAR')),
        ],
      ),
    );

    if (confirmar == true) {
      final exito = await context.read<InventarioProvider>().eliminarProducto(producto.id!);
      if (mounted) {
        if (exito) {
          _searchController.clear();
          setState(() { _mostrarSugerencias = false; _selectedSuggestionIndex = -1; });
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exito ? 'Producto eliminado' : 'Error al eliminar'), backgroundColor: exito ? AppColors.success : AppColors.error));
      }
    }
  }

  @override
  void dispose() { _searchController.dispose(); _searchFocus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inventoryOrange,
      appBar: AppBar(
        automaticallyImplyLeading: false, backgroundColor: AppColors.inventoryOrange, elevation: 0,
        title: Row(
          children: [
            const Text('Inventario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: AppSizes.titleLarge)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _mostrarFormularioProducto(),
              icon: const Icon(Icons.add, color: Colors.white), label: const Text('NUEVO PRODUCTO', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.inventoryOrange, foregroundColor: Colors.white, elevation: 0),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.text_increase, color: Colors.white), onPressed: () => showDialog(context: context, builder: (context) => const TextScaleDialog())),
          IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.white), onPressed: _mostrarMerma, tooltip: 'Registrar Merma'),
          IconButton(icon: const Icon(Icons.upload, color: Colors.white), onPressed: _exportarBackup, tooltip: 'Exportar respaldo'),
          IconButton(icon: const Icon(Icons.download, color: Colors.white), onPressed: _importarBackup, tooltip: 'Importar respaldo'),
          IconButton(icon: const Icon(Icons.warning_amber, color: Colors.white), onPressed: _mostrarStockBajo, tooltip: 'Productos con stock bajo'),
          IconButton(icon: const Icon(Icons.clear, color: Colors.white), onPressed: () { _searchController.clear(); setState(() { _mostrarSugerencias = false; _selectedSuggestionIndex = -1; }); _searchFocus.requestFocus(); }, tooltip: 'Limpiar búsqueda'),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(AppSizes.paddingLarge), padding: const EdgeInsets.all(AppSizes.paddingLarge),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSizes.radiusMedium), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Consumer<InventarioProvider>(
              builder: (context, provider, child) {
                return Row(
                  children: [
                    Container(padding: const EdgeInsets.all(AppSizes.paddingMedium), decoration: BoxDecoration(color: AppColors.inventoryOrangeLight, borderRadius: BorderRadius.circular(AppSizes.radiusSmall)), child: const Icon(Icons.attach_money, size: AppSizes.iconLarge, color: AppColors.inventoryOrange)),
                    const SizedBox(width: AppSizes.paddingMedium),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total Invertido', style: TextStyle(fontSize: AppSizes.bodyMedium, color: AppColors.textSecondary)), Text(_currencyFormat.format(provider.totalInvertido), style: const TextStyle(fontSize: AppSizes.titleLarge, fontWeight: FontWeight.bold, color: AppColors.textPrimary))]),
                  ],
                );
              },
            ),
          ),
          Container(
            color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingLarge, vertical: AppSizes.paddingMedium),
            child: TextField(
              controller: _searchController, focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o código...', prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() { _mostrarSugerencias = false; _selectedSuggestionIndex = -1; }); _searchFocus.requestFocus(); }) : null,
              ),
              onSubmitted: (value) {
                if (_mostrarSugerencias && _selectedSuggestionIndex != -1 && _sugerencias.isNotEmpty) {
                  _mostrarFormularioProducto(producto: _sugerencias[_selectedSuggestionIndex]);
                } else if (_sugerencias.length == 1) {
                  _mostrarFormularioProducto(producto: _sugerencias.first);
                } else if (_sugerencias.isEmpty && value.trim().isNotEmpty) {
                  _mostrarFormularioProducto(codigoInicial: value.trim());
                }
              },
            ),
          ),
          if (_mostrarSugerencias)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingLarge),
              child: SearchDropdown<Producto>(
                items: _sugerencias, maxHeight: 300, selectedIndex: _selectedSuggestionIndex,
                onDismiss: () => setState(() => _mostrarSugerencias = false),
                itemBuilder: (context, producto, isSelected) {
                  return ListTile(
                    leading: Icon(Icons.inventory_2, color: isSelected ? AppColors.inventoryOrange : AppColors.textSecondary),
                    title: Text(producto.nombreConUnidad, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text('Código: ${producto.codigo} • Stock: ${producto.aGranel ? producto.stock.toStringAsFixed(2) : producto.stock}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_currencyFormat.format(producto.precioVenta), style: TextStyle(fontSize: AppSizes.bodyLarge, fontWeight: FontWeight.bold, color: isSelected ? AppColors.inventoryOrange : AppColors.textPrimary)),
                        IconButton(icon: const Icon(Icons.delete, color: AppColors.error), onPressed: () { setState(() => _mostrarSugerencias = false); _confirmarEliminar(producto); }, tooltip: 'Eliminar producto'),
                      ],
                    ),
                    onTap: () => _mostrarFormularioProducto(producto: producto),
                  );
                },
                onItemSelected: (producto) { setState(() => _selectedSuggestionIndex = _sugerencias.indexOf(producto)); _mostrarFormularioProducto(producto: producto); },
              ),
            ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: Consumer2<InventarioProvider, ConfigProvider>(
                builder: (context, provider, configProvider, child) {
                  final productos = _searchController.text.isEmpty ? provider.productos : _productosFiltrados;
                  final scaleFactor = configProvider.textScaleFactor;

                  if (provider.isLoading) return const Center(child: CircularProgressIndicator());
                  if (productos.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]), const SizedBox(height: AppSizes.paddingMedium), Text(_searchController.text.isEmpty ? 'No hay productos registrados' : 'No se encontraron productos', style: const TextStyle(fontSize: AppSizes.bodyLarge, color: AppColors.textSecondary))]));

                  return Column(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium, vertical: AppSizes.paddingSmall), decoration: BoxDecoration(color: AppColors.inventoryOrange.withOpacity(0.1), border: const Border(bottom: BorderSide(color: AppColors.divider))), child: Row(children: const [Expanded(flex: 2, child: Text('CÓDIGO', style: AppTextStyles.tableHeader)), Expanded(flex: 4, child: Text('PRODUCTO', style: AppTextStyles.tableHeader)), Expanded(flex: 2, child: Text('COSTO', style: AppTextStyles.tableHeader, textAlign: TextAlign.right)), Expanded(flex: 2, child: Text('VENTA', style: AppTextStyles.tableHeader, textAlign: TextAlign.right)), Expanded(flex: 2, child: Text('STOCK', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)), Expanded(flex: 2, child: Text('ACCIÓN', style: AppTextStyles.tableHeader, textAlign: TextAlign.center))])),
                      Expanded(
                        child: ListView.separated(
                          itemCount: productos.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final producto = productos[index];
                            final stockBajo = producto.stock < producto.stockMinimo;

                            return InkWell(
                              onTap: () => _mostrarFormularioProducto(producto: producto),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium, vertical: AppSizes.paddingSmall),
                                color: index % 2 == 0 ? Colors.orange[50] : Colors.white,
                                child: Row(
                                  children: [
                                    Expanded(flex: 2, child: Text(producto.codigo, style: TextStyle(fontSize: AppSizes.bodyMedium * scaleFactor, fontFamily: 'monospace'))),
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(producto.nombreConUnidad, style: TextStyle(fontSize: AppSizes.bodyMedium * scaleFactor, fontWeight: FontWeight.w500)),
                                          if (producto.aGranel || producto.esSuelto) Wrap(spacing: 4, children: [if (producto.aGranel) Chip(label: Text(producto.unidadMedida ?? 'Granel', style: const TextStyle(fontSize: 10)), backgroundColor: Colors.blue[100], padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap), if (producto.esSuelto) Chip(label: const Text('Suelto', style: TextStyle(fontSize: 10)), backgroundColor: Colors.purple[100], padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)]),
                                        ],
                                      ),
                                    ),
                                    Expanded(flex: 2, child: Text(_currencyFormat.format(producto.costo), style: TextStyle(fontSize: AppSizes.bodyMedium * scaleFactor), textAlign: TextAlign.right)),
                                    Expanded(flex: 2, child: Text(_currencyFormat.format(producto.precioVenta), style: TextStyle(fontSize: AppSizes.bodyMedium * scaleFactor, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                                    Expanded(flex: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: stockBajo ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(producto.aGranel ? producto.stock.toStringAsFixed(2) : producto.stock.toInt().toString(), style: TextStyle(fontSize: AppSizes.bodyMedium * scaleFactor, fontWeight: FontWeight.bold, color: stockBajo ? AppColors.error : AppColors.success), textAlign: TextAlign.center))),
                                    Expanded(flex: 2, child: IconButton(icon: const Icon(Icons.delete, color: AppColors.error), onPressed: () => _confirmarEliminar(producto), tooltip: 'Eliminar')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}