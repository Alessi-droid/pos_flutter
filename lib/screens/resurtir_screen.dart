// lib/screens/resurtir_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/producto.dart';
import '../providers/inventario_provider.dart';
import '../providers/turno_provider.dart';
import '../providers/finanzas_provider.dart';
import '../widgets/search_dropdown.dart';

class ItemResurtir {
  final Producto producto;
  double cantidad;
  double costoUnitario;
  double precioVenta;

  ItemResurtir({
    required this.producto,
    required this.cantidad,
    required this.costoUnitario,
    required this.precioVenta,
  });

  double get subtotal => cantidad * costoUnitario;
}

class ResurtirScreen extends StatefulWidget {
  const ResurtirScreen({super.key});

  @override
  State<ResurtirScreen> createState() => _ResurtirScreenState();
}

class _ResurtirScreenState extends State<ResurtirScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocus;
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _cFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  List<ItemResurtir> _items = [];
  List<Producto> _sugerencias = [];
  bool _mostrarSugerencias = false;
  int _selectedSuggestionIndex = -1;

  int _selectedRowIndex = -1;
  int _selectedColIndex = 0;
  bool _isProcessing = false;

  double get totalInversion => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _searchFocus = FocusNode(
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        final isArrow = key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight;

        if (_mostrarSugerencias) {
          if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
            if (event is KeyDownEvent) {
              if (key == LogicalKeyboardKey.arrowDown) { setState(() => _selectedSuggestionIndex = (_selectedSuggestionIndex < _sugerencias.length - 1) ? _selectedSuggestionIndex + 1 : _selectedSuggestionIndex); }
              else { setState(() => _selectedSuggestionIndex = (_selectedSuggestionIndex > 0) ? _selectedSuggestionIndex - 1 : 0); }
            }
            return KeyEventResult.handled;
          }
        }
        else if (_searchController.text.isEmpty && _items.isNotEmpty) {

          if (isArrow) {
            if (event is KeyDownEvent) {
              if (key == LogicalKeyboardKey.arrowDown) { setState(() => _selectedRowIndex = (_selectedRowIndex < _items.length - 1) ? _selectedRowIndex + 1 : _selectedRowIndex); Future.delayed(Duration.zero, _scrollToSelected); }
              else if (key == LogicalKeyboardKey.arrowUp) { setState(() => _selectedRowIndex = (_selectedRowIndex > 0) ? _selectedRowIndex - 1 : 0); Future.delayed(Duration.zero, _scrollToSelected); }
              else if (key == LogicalKeyboardKey.arrowRight) { if (_selectedRowIndex >= 0 && _selectedColIndex < 2) setState(() => _selectedColIndex++); }
              else if (key == LogicalKeyboardKey.arrowLeft) { if (_selectedRowIndex >= 0 && _selectedColIndex > 0) setState(() => _selectedColIndex--); }
            }
            return KeyEventResult.handled;
          }

          if (event is KeyDownEvent) {
            if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
              if (_selectedRowIndex >= 0 && _selectedRowIndex < _items.length) { setState(() { _items.removeAt(_selectedRowIndex); if (_selectedRowIndex >= _items.length) _selectedRowIndex = _items.length - 1; }); }
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.enter && _selectedRowIndex >= 0) {
              _editarCeldaActual(_selectedRowIndex, _selectedColIndex);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) { context.read<InventarioProvider>().cargarProductos(); });
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      final offset = _selectedRowIndex * 65.0;
      _scrollController.animateTo(offset, duration: const Duration(milliseconds: 150), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() { _searchController.dispose(); _searchFocus.dispose(); _scrollController.dispose(); super.dispose(); }

  void _buscar(String query) {
    if (query.isEmpty) { setState(() { _sugerencias = []; _mostrarSugerencias = false; _selectedSuggestionIndex = -1; }); return; }
    final resultados = context.read<InventarioProvider>().buscarProductos(query);
    setState(() { _sugerencias = resultados; _mostrarSugerencias = _sugerencias.isNotEmpty; _selectedSuggestionIndex = _sugerencias.isNotEmpty ? 0 : -1; _selectedRowIndex = -1; });
  }

  void _agregarRapido(Producto producto) {
    setState(() {
      _mostrarSugerencias = false;
      _searchController.clear();

      final indiceExistente = _items.indexWhere((item) => item.producto.id == producto.id);

      if (indiceExistente >= 0) {
        _items[indiceExistente].cantidad += 1.0;
        _selectedRowIndex = indiceExistente;
      } else {
        _items.add(ItemResurtir(producto: producto, cantidad: 1.0, costoUnitario: producto.costo, precioVenta: producto.precioVenta));
        _selectedRowIndex = _items.length - 1;
      }
      _selectedColIndex = 0;
    });

    _scrollToSelected();
    Future.delayed(const Duration(milliseconds: 100), () => _searchFocus.requestFocus());
  }

  Future<void> _editarCeldaActual(int fila, int columna) async {
    final item = _items[fila];
    String titulo = ''; String valorActual = ''; bool esMoneda = false;

    if (columna == 0) { titulo = 'Modificar Cantidad'; valorActual = item.producto.aGranel ? item.cantidad.toStringAsFixed(2) : item.cantidad.toInt().toString(); }
    else if (columna == 1) { titulo = 'Modificar Costo Unitario'; valorActual = item.costoUnitario.toStringAsFixed(2); esMoneda = true; }
    else if (columna == 2) { titulo = 'Modificar Precio Venta'; valorActual = item.precioVenta.toStringAsFixed(2); esMoneda = true; }

    final nuevoValor = await showDialog<double>(
      context: context, barrierDismissible: false,
      builder: (context) => _MiniDialogoEdicion(titulo: titulo, valorInicial: valorActual, esMoneda: esMoneda),
    );

    if (nuevoValor != null) {
      setState(() {
        if (columna == 0) { item.cantidad = nuevoValor; }
        else if (columna == 1) { item.costoUnitario = nuevoValor; item.precioVenta = (nuevoValor * 1.25).roundToDouble(); }
        else if (columna == 2) { item.precioVenta = nuevoValor; }
      });
    }
    _searchFocus.requestFocus();
  }

  Future<void> _procesarResurtido() async {
    final turnoId = context.read<TurnoProvider>().turnoActivo?.id;
    if (turnoId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abre un turno primero'), backgroundColor: Colors.red)); return; }

    setState(() => _isProcessing = true);
    final inventario = context.read<InventarioProvider>();

    try {
      for (var item in _items) {
        await inventario.resurtirProducto(productoId: item.producto.id!, cantidad: item.cantidad, costoUnitario: item.costoUnitario, precioVenta: item.precioVenta, turnoId: turnoId);
      }
      if (mounted) {
        await context.read<FinanzasProvider>().cargarBalance(turnoId);
        setState(() { _items.clear(); _selectedRowIndex = -1; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Inventario actualizado correctamente'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      _searchFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && ModalRoute.of(context)?.isCurrent == true) FocusScope.of(context).requestFocus(_searchFocus); });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false, backgroundColor: Colors.teal.shade700,
        title: const Text('Resurtir Inventario / Compras', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.cleaning_services, color: Colors.white), onPressed: () { setState(() { _items.clear(); _selectedRowIndex = -1; }); _searchFocus.requestFocus(); })],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white, padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController, focusNode: _searchFocus, autofocus: true,
              decoration: InputDecoration(
                hintText: 'Escanea o busca el producto...', prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.teal.shade50,
              ),
              onChanged: _buscar,
              onSubmitted: (v) {
                if (_mostrarSugerencias && _sugerencias.isNotEmpty && _selectedSuggestionIndex != -1) { _agregarRapido(_sugerencias[_selectedSuggestionIndex]); }
                else if (_sugerencias.length == 1) { _agregarRapido(_sugerencias.first); }
              },
            ),
          ),
          if (_mostrarSugerencias)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SearchDropdown<Producto>(
                items: _sugerencias, maxHeight: 250, selectedIndex: _selectedSuggestionIndex,
                onDismiss: () => setState(() => _mostrarSugerencias = false),
                itemBuilder: (ctx, p, isSelected) => ListTile(leading: Icon(Icons.inventory_2, color: isSelected ? Colors.teal : Colors.grey), title: Text(p.nombreConUnidad, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), trailing: Text('Stock: ${p.stock}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                onItemSelected: _agregarRapido,
              ),
            ),
          Expanded(
            child: _items.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey.shade300), const Text('Escanea la mercancía nueva para ingresarla', style: TextStyle(color: Colors.grey))]))
                : Container(
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium, vertical: AppSizes.paddingSmall),
                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), border: const Border(bottom: BorderSide(color: AppColors.divider))),
                    child: Row(
                      children: const [
                        Expanded(flex: 3, child: Text('PRODUCTO', style: AppTextStyles.tableHeader)),
                        Expanded(flex: 1, child: Text('CANT', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
                        Expanded(flex: 1, child: Text('STOCK', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text('COSTO U.', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text('NVO. PRECIO', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text('TOTAL INV.', style: AppTextStyles.tableHeader, textAlign: TextAlign.right)),
                        SizedBox(width: 50),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: _scrollController, itemCount: _items.length, separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final isSelectedRow = index == _selectedRowIndex;

                        return Container(
                          decoration: BoxDecoration(color: isSelectedRow ? Colors.orange.withOpacity(0.1) : (index % 2 == 0 ? Colors.teal.shade50 : Colors.white)),
                          padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(item.producto.nombreConUnidad, style: const TextStyle(fontSize: AppSizes.bodyMedium, fontWeight: FontWeight.w500))),

                              _buildCeldaInteractiva(indexFil: index, indexCol: 0, isSelectedRow: isSelectedRow, texto: item.producto.aGranel ? item.cantidad.toStringAsFixed(2) : item.cantidad.toInt().toString(), colorTexto: Colors.teal.shade700, flex: 1),

                              // ⭐ COLUMNA DE STOCK ACTUAL (Informativa, no editable)
                              Expanded(flex: 1, child: Text(item.producto.aGranel ? item.producto.stock.toStringAsFixed(2) : item.producto.stock.toInt().toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: AppSizes.bodyMedium, color: Colors.blueGrey, fontWeight: FontWeight.bold))),

                              _buildCeldaInteractiva(indexFil: index, indexCol: 1, isSelectedRow: isSelectedRow, texto: _cFormat.format(item.costoUnitario), colorTexto: Colors.orange.shade700, flex: 2),
                              _buildCeldaInteractiva(indexFil: index, indexCol: 2, isSelectedRow: isSelectedRow, texto: _cFormat.format(item.precioVenta), colorTexto: Colors.green.shade700, flex: 2),

                              Expanded(flex: 2, child: Text(_cFormat.format(item.subtotal), style: const TextStyle(fontSize: AppSizes.bodyMedium, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                              SizedBox(width: 50, child: IconButton(icon: const Icon(Icons.delete, color: AppColors.error), onPressed: () { setState(() { _items.removeAt(index); }); _searchFocus.requestFocus(); })),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]),
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('TOTAL INVERSIÓN:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), Text(_cFormat.format(totalInversion), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.teal.shade700))])),
                SizedBox(height: 60, width: 280, child: ElevatedButton.icon(onPressed: (_items.isEmpty || _isProcessing) ? null : _procesarResurtido, icon: _isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save, size: 28), label: const Text('GUARDAR RESURTIDO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCeldaInteractiva({required int indexFil, required int indexCol, required bool isSelectedRow, required String texto, required Color colorTexto, required int flex}) {
    bool isSelectedCell = isSelectedRow && _selectedColIndex == indexCol;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () { setState(() { _selectedRowIndex = indexFil; _selectedColIndex = indexCol; }); _editarCeldaActual(indexFil, indexCol); },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: isSelectedCell ? Colors.orange.withOpacity(0.2) : Colors.transparent, border: Border.all(color: isSelectedCell ? Colors.orange : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(6)),
          child: Text(texto, textAlign: TextAlign.center, style: TextStyle(fontSize: AppSizes.bodyMedium, fontWeight: isSelectedCell ? FontWeight.bold : FontWeight.normal, color: colorTexto)),
        ),
      ),
    );
  }
}

class _MiniDialogoEdicion extends StatefulWidget {
  final String titulo; final String valorInicial; final bool esMoneda;
  const _MiniDialogoEdicion({required this.titulo, required this.valorInicial, required this.esMoneda});
  @override State<_MiniDialogoEdicion> createState() => _MiniDialogoEdicionState();
}

class _MiniDialogoEdicionState extends State<_MiniDialogoEdicion> {
  late TextEditingController _ctrl; final FocusNode _focus = FocusNode();
  @override void initState() {
    super.initState(); _ctrl = TextEditingController(text: widget.valorInicial);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) { FocusScope.of(context).requestFocus(_focus); _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length); } });
  }
  @override void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }
  void _guardar() { final val = double.tryParse(_ctrl.text); if (val != null && val >= 0) { Navigator.pop(context, val); } }
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo, style: const TextStyle(fontSize: 18)),
      content: TextField(controller: _ctrl, focusNode: _focus, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(prefixText: widget.esMoneda ? '\$ ' : '', border: const OutlineInputBorder()), onSubmitted: (_) => _guardar()),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')), ElevatedButton(onPressed: _guardar, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white), child: const Text('OK (Enter)'))],
    );
  }
}