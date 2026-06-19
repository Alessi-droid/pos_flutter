// lib/screens/venta_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../providers/venta_provider.dart';
import '../providers/turno_provider.dart';
import '../providers/finanzas_provider.dart';
import '../providers/config_provider.dart';
import '../models/producto.dart';
import '../widgets/cantidad_dialog.dart';
import '../widgets/pago_dialog.dart';
import '../widgets/producto_form_dialog.dart';
import '../widgets/devolucion_dialog.dart';
import '../widgets/venta_granel_dialog.dart';
import '../widgets/search_dropdown.dart';
import '../widgets/text_scale_dialog.dart';

class VentaScreen extends StatefulWidget {
  const VentaScreen({super.key});

  @override
  State<VentaScreen> createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocus;
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  List<Producto> _sugerencias = [];
  bool _mostrarSugerencias = false;
  int _selectedSuggestionIndex = -1;
  int _selectedRowIndex = -1;

  @override
  void initState() {
    super.initState();

    _searchFocus = FocusNode(
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        final isArrow = key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight;

        if (HardwareKeyboard.instance.isControlPressed) {
          if (event is KeyDownEvent) {
            if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) { context.read<VentaProvider>().cambiarCarrito(0); setState(() => _selectedRowIndex = -1); }
            else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) { context.read<VentaProvider>().cambiarCarrito(1); setState(() => _selectedRowIndex = -1); }
            else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) { context.read<VentaProvider>().cambiarCarrito(2); setState(() => _selectedRowIndex = -1); }
          }
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.f12) { if (event is KeyDownEvent) _cobrar(); return KeyEventResult.handled; }

        if (_mostrarSugerencias) {
          if (isArrow) {
            if (event is KeyDownEvent) {
              if (key == LogicalKeyboardKey.arrowDown) { setState(() => _selectedSuggestionIndex = (_selectedSuggestionIndex < _sugerencias.length - 1) ? _selectedSuggestionIndex + 1 : _selectedSuggestionIndex); }
              else if (key == LogicalKeyboardKey.arrowUp) { setState(() => _selectedSuggestionIndex = (_selectedSuggestionIndex > 0) ? _selectedSuggestionIndex - 1 : 0); }
            }
            return KeyEventResult.handled;
          }
        }
        else if (_searchController.text.isEmpty) {
          final provider = context.read<VentaProvider>();

          if (provider.items.isNotEmpty) {
            if (isArrow) {
              if (event is KeyDownEvent) {
                if (key == LogicalKeyboardKey.arrowDown) { setState(() => _selectedRowIndex = (_selectedRowIndex < provider.items.length - 1) ? _selectedRowIndex + 1 : _selectedRowIndex); Future.delayed(Duration.zero, _scrollToSelected); }
                else if (key == LogicalKeyboardKey.arrowUp) { setState(() => _selectedRowIndex = (_selectedRowIndex > 0) ? _selectedRowIndex - 1 : 0); Future.delayed(Duration.zero, _scrollToSelected); }
              }
              return KeyEventResult.handled;
            }

            if (event is KeyDownEvent) {
              if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
                if (_selectedRowIndex >= 0 && _selectedRowIndex < provider.items.length) { provider.eliminarItem(_selectedRowIndex); setState(() { if (_selectedRowIndex >= provider.items.length) _selectedRowIndex = provider.items.length - 1; }); }
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.enter && _selectedRowIndex >= 0) {
                _editarCantidadItem(_selectedRowIndex);
                return KeyEventResult.handled;
              }
            }
          }
        }

        if (isArrow) return KeyEventResult.handled;
        return KeyEventResult.ignored;
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) { context.read<VentaProvider>().cargarProductos(); });
    _searchController.addListener(_onSearchChanged);
    Future.delayed(const Duration(milliseconds: 100), () => _searchFocus.requestFocus());
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      final offset = _selectedRowIndex * 65.0;
      _scrollController.animateTo(offset, duration: const Duration(milliseconds: 150), curve: Curves.easeInOut);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final ventaProvider = context.read<VentaProvider>();

    if (query.isEmpty) {
      setState(() { _sugerencias = []; _mostrarSugerencias = false; _selectedSuggestionIndex = -1; });
    } else {
      setState(() {
        _sugerencias = ventaProvider.buscarProductos(query);
        _mostrarSugerencias = _sugerencias.isNotEmpty;
        _selectedSuggestionIndex = _sugerencias.isNotEmpty ? 0 : -1;
        _selectedRowIndex = -1;
      });
    }
  }

  Future<void> _seleccionarProducto(Producto producto) async {
    setState(() { _mostrarSugerencias = false; _searchController.clear(); _selectedRowIndex = -1; });

    double cantidad;
    if (producto.aGranel) {
      final cantidadGranel = await showDialog<double>(context: context, barrierDismissible: false, builder: (context) => VentaGranelDialog(producto: producto));
      if (cantidadGranel == null) { Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_searchFocus); }); return; }
      cantidad = cantidadGranel;
    } else {
      cantidad = 1.0;
    }

    final ventaProvider = context.read<VentaProvider>();
    ventaProvider.agregarProducto(producto, cantidad);

    // ⭐ AUTO-SCROLL MÁGICO: Buscamos dónde quedó el producto y bajamos la pantalla
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        final index = ventaProvider.items.indexWhere((item) => item.producto.id == producto.id);
        if (index >= 0) {
          setState(() => _selectedRowIndex = index);
          _scrollToSelected();
        }
        FocusScope.of(context).requestFocus(_searchFocus);
      }
    });
  }

  Future<void> _editarCantidadItem(int index) async {
    final ventaProvider = context.read<VentaProvider>();
    final item = ventaProvider.items[index];
    double? nuevaCantidad;

    if (item.producto.aGranel) { nuevaCantidad = await showDialog<double>(context: context, barrierDismissible: false, builder: (context) => VentaGranelDialog(producto: item.producto)); }
    else { nuevaCantidad = await showDialog<double>(context: context, builder: (context) => CantidadDialog(producto: item.producto)); }

    if (nuevaCantidad != null && nuevaCantidad > 0) ventaProvider.actualizarCantidad(index, nuevaCantidad);
    Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_searchFocus); });
  }

  Future<void> _cobrar() async {
    final ventaProvider = context.read<VentaProvider>();
    final turnoProvider = context.read<TurnoProvider>();
    final finanzasProvider = context.read<FinanzasProvider>();

    if (ventaProvider.carritoVacio) return;
    if (!turnoProvider.hayTurnoActivo) { _mostrarError('No hay turno activo'); return; }

    final folio = await turnoProvider.obtenerYAvanzarFolio();
    final metodoPago = await showDialog<String>(context: context, barrierDismissible: false, builder: (context) => PagoDialog(total: ventaProvider.total));

    if (metodoPago != null) {
      final exito = await ventaProvider.procesarVenta(turnoId: turnoProvider.turnoActivo!.id!, metodoPago: metodoPago, folio: folio);
      if (exito) {
        _mostrarExito('Venta registrada exitosamente');
        await Future.delayed(const Duration(milliseconds: 200));
        try { await finanzasProvider.cargarBalance(turnoProvider.turnoActivo!.id!); } catch (e) { debugPrint('Error al refrescar balance: $e'); }
        ventaProvider.limpiarCarrito();
        setState(() => _selectedRowIndex = -1);
      } else {
        _mostrarError('Error al procesar la venta');
      }
    }
    Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_searchFocus); });
  }

  void _mostrarError(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: AppColors.error));
  void _mostrarExito(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: AppColors.success));

  @override
  void dispose() { _searchController.dispose(); _searchFocus.dispose(); _scrollController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && ModalRoute.of(context)?.isCurrent == true) { FocusScope.of(context).requestFocus(_searchFocus); } });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false, backgroundColor: AppColors.primaryBlue,
        title: const Text('Punto de Venta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.cleaning_services, color: Colors.white), onPressed: () { context.read<VentaProvider>().limpiarCarrito(); setState(() => _selectedRowIndex = -1); _searchFocus.requestFocus(); }),
          IconButton(icon: const Icon(Icons.text_increase, color: Colors.white), onPressed: () => showDialog(context: context, builder: (context) => const TextScaleDialog())),
        ],
      ),
      body: Column(
        children: [
          Consumer<VentaProvider>(
            builder: (context, ventaProvider, child) {
              return Container(
                color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium, vertical: 8),
                child: Row(
                  children: [
                    _buildTab(ventaProvider, 0, 'Cuenta 1 (Ctrl+1)'),
                    const SizedBox(width: 8),
                    _buildTab(ventaProvider, 1, 'Cuenta 2 (Ctrl+2)'),
                    const SizedBox(width: 8),
                    _buildTab(ventaProvider, 2, 'Cuenta 3 (Ctrl+3)'),
                  ],
                ),
              );
            },
          ),
          Container(
            color: Colors.white, padding: const EdgeInsets.all(AppSizes.paddingMedium),
            child: TextField(
              controller: _searchController, focusNode: _searchFocus, autofocus: true,
              decoration: InputDecoration(
                hintText: 'Escanear o buscar producto...', prefixIcon: const Icon(Icons.search, size: AppSizes.iconMedium),
                suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() { _mostrarSugerencias = false; _selectedRowIndex = -1; }); _searchFocus.requestFocus(); }) : null,
              ),
              onSubmitted: (value) async {
                if (_mostrarSugerencias && _selectedSuggestionIndex != -1 && _sugerencias.isNotEmpty) { _seleccionarProducto(_sugerencias[_selectedSuggestionIndex]); }
                else if (_sugerencias.length == 1) { _seleccionarProducto(_sugerencias.first); }
                else if (_sugerencias.isEmpty && value.trim().isNotEmpty) {
                  final nuevoProducto = await showDialog<Producto>(context: context, barrierDismissible: false, builder: (context) => ProductoFormDialog(codigoInicial: value.trim()));
                  if (nuevoProducto != null) { await context.read<VentaProvider>().cargarProductos(); _seleccionarProducto(nuevoProducto); }
                  else { _searchController.clear(); setState(() => _mostrarSugerencias = false); Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_searchFocus); }); }
                }
              },
            ),
          ),
          if (_mostrarSugerencias)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium),
              child: SearchDropdown<Producto>(
                items: _sugerencias, maxHeight: 300, selectedIndex: _selectedSuggestionIndex,
                onDismiss: () => setState(() => _mostrarSugerencias = false),
                itemBuilder: (context, producto, isSelected) {
                  return ListTile(
                    leading: Icon(Icons.inventory_2, color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary),
                    title: Text(producto.nombreConUnidad, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text('Código: ${producto.codigo} • Stock: ${producto.aGranel ? producto.stock.toStringAsFixed(2) : producto.stock.toInt()}'),
                    trailing: Text(_currencyFormat.format(producto.precioVenta), style: TextStyle(fontSize: AppSizes.bodyLarge, fontWeight: FontWeight.bold, color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary)),
                  );
                },
                onItemSelected: (producto) { setState(() => _selectedSuggestionIndex = _sugerencias.indexOf(producto)); _seleccionarProducto(producto); },
              ),
            ),
          Expanded(child: _buildCarrito()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildTab(VentaProvider provider, int index, String titulo) {
    final isSelected = provider.carritoActivoIndex == index;
    final tieneItems = provider.getCantidadItemsEnCarrito(index) > 0;
    return Expanded(
      child: InkWell(
        onTap: () { provider.cambiarCarrito(index); setState(() => _selectedRowIndex = -1); Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_searchFocus); }); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? AppColors.primaryBlue : Colors.grey[200], borderRadius: BorderRadius.circular(8), border: isSelected ? null : Border.all(color: Colors.grey[300]!)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(titulo, style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
              if (tieneItems) ...[
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isSelected ? Colors.white : AppColors.primaryBlue, shape: BoxShape.circle), child: Text('${provider.getCantidadItemsEnCarrito(index)}', style: TextStyle(color: isSelected ? AppColors.primaryBlue : Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarrito() {
    return Consumer2<VentaProvider, ConfigProvider>(
      builder: (context, ventaProvider, configProvider, child) {
        if (ventaProvider.carritoVacio) return const Center(child: Text('Escanea productos para comenzar', style: TextStyle(fontSize: AppSizes.titleMedium, color: AppColors.textSecondary)));
        final scaleFactor = configProvider.textScaleFactor;

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium, vertical: AppSizes.paddingSmall),
                decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), border: const Border(bottom: BorderSide(color: AppColors.divider))),
                child: Row(
                  children: const [
                    Expanded(flex: 4, child: Text('PRODUCTO', style: AppTextStyles.tableHeader)),
                    Expanded(flex: 2, child: Text('AL COSTO', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('CANT', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('PRECIO', style: AppTextStyles.tableHeader, textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('STOCK', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('TOTAL', style: AppTextStyles.tableHeader, textAlign: TextAlign.right)),
                    SizedBox(width: 50),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: ventaProvider.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = ventaProvider.items[index];
                    final stockDisponible = item.producto.stock - item.cantidad;
                    final stockInsuficiente = stockDisponible < 0;
                    final isSelectedRow = index == _selectedRowIndex;

                    return Container(
                      decoration: BoxDecoration(color: isSelectedRow ? Colors.orange.withOpacity(0.15) : (index % 2 == 0 ? Colors.blue[50] : Colors.white), border: isSelectedRow ? Border.all(color: Colors.orange, width: 1.5) : null),
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium, vertical: AppSizes.paddingSmall),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text(item.producto.nombreConUnidad, style: TextStyle(fontSize: AppSizes.bodyMedium * scaleFactor, fontWeight: FontWeight.w500))),
                          Expanded(flex: 2, child: Align(alignment: Alignment.center, child: Transform.scale(scale: 0.8, child: Switch(value: item.venderAlCosto, onChanged: (val) { ventaProvider.toggleVenderAlCosto(index, val); _searchFocus.requestFocus(); }, activeColor: Colors.purple)))),
                          Expanded(flex: 2, child: InkWell(onTap: () => _editarCantidadItem(index), child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), decoration: BoxDecoration(color: AppColors.accentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(item.producto.aGranel ? item.cantidad.toStringAsFixed(2) : item.cantidad.toInt().toString(), style: TextStyle(fontSize: AppSizes.bodyMedium * scaleFactor, fontWeight: FontWeight.bold, color: AppColors.accentBlue), textAlign: TextAlign.center)))),
                          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(_currencyFormat.format(item.venderAlCosto ? item.producto.costo : item.producto.precioVenta), style: TextStyle(fontSize: AppSizes.bodyMedium * scaleFactor, color: item.venderAlCosto ? Colors.purple : AppColors.textPrimary, fontWeight: item.venderAlCosto ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.right), if (item.venderAlCosto) Text(_currencyFormat.format(item.producto.precioVenta), style: TextStyle(fontSize: 10 * scaleFactor, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough), textAlign: TextAlign.right)])),
                          Expanded(flex: 2, child: Text(item.producto.aGranel ? stockDisponible.toStringAsFixed(2) : stockDisponible.toInt().toString(), style: TextStyle(fontSize: AppSizes.bodyMedium * scaleFactor, color: stockInsuficiente ? AppColors.error : (stockDisponible < item.producto.stockMinimo ? AppColors.error : AppColors.textPrimary), fontWeight: stockInsuficiente || stockDisponible < item.producto.stockMinimo ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text(_currencyFormat.format(item.subtotal), style: TextStyle(fontSize: AppSizes.bodyMedium * scaleFactor, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                          SizedBox(width: 50, child: IconButton(icon: const Icon(Icons.delete, color: AppColors.error), onPressed: () { ventaProvider.eliminarItem(index); _searchFocus.requestFocus(); })),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Consumer<VentaProvider>(
      builder: (context, ventaProvider, child) {
        return Container(
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          decoration: BoxDecoration(color: AppColors.cardWhite, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))]),
          child: Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text('TOTAL', style: AppTextStyles.tableHeader.copyWith(fontSize: AppSizes.bodyLarge)), Text(_currencyFormat.format(ventaProvider.total), style: AppTextStyles.currency.copyWith(color: AppColors.primaryBlue))])),
              const SizedBox(width: AppSizes.paddingMedium),
              SizedBox(width: 200, child: OutlinedButton.icon(onPressed: () async {
                final turnoProvider = context.read<TurnoProvider>();
                if (!turnoProvider.hayTurnoActivo) { _mostrarError('No hay turno activo'); return; }
                final resultado = await showDialog(context: context, builder: (context) => DevolucionDialog(turnoId: turnoProvider.turnoActivo!.id!));
                if (resultado == true) { await context.read<VentaProvider>().cargarProductos(); await context.read<FinanzasProvider>().cargarBalance(turnoProvider.turnoActivo!.id!); }
                Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_searchFocus); });
              }, icon: const Icon(Icons.assignment_return), label: const Text('DEVOLVER'), style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange, width: 2), padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingLarge)))),
              const SizedBox(width: AppSizes.paddingMedium),
              SizedBox(width: 250, child: ElevatedButton.icon(onPressed: ventaProvider.carritoVacio ? null : _cobrar, icon: const Icon(Icons.payment, size: AppSizes.iconMedium), label: const Text('COBRAR (F12)'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.textSecondary, padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingLarge)))),
            ],
          ),
        );
      },
    );
  }
}