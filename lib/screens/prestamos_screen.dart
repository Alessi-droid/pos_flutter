// lib/screens/prestamos_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/producto.dart';
import '../providers/prestamos_provider.dart';
import '../providers/turno_provider.dart';
import '../widgets/search_dropdown.dart';
import '../widgets/cantidad_dialog.dart';
import '../widgets/venta_granel_dialog.dart';

class PrestamosScreen extends StatefulWidget {
  const PrestamosScreen({super.key});

  @override
  State<PrestamosScreen> createState() => _PrestamosScreenState();
}

class _PrestamosScreenState extends State<PrestamosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FocusNode _mainScreenFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrestamosProvider>().cargarDatos();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mainScreenFocus.dispose();
    super.dispose();
  }

  void _cambiarTab(int index) {
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _mainScreenFocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && HardwareKeyboard.instance.isControlPressed) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) { _cambiarTab(0); return KeyEventResult.handled; }
          if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) { _cambiarTab(1); return KeyEventResult.handled; }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: const Text('Gestor de Créditos y Cobranza', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.indigo.shade100,
            indicatorColor: Colors.orange,
            indicatorWeight: 4,
            tabs: const [
              Tab(icon: Icon(Icons.grid_view), text: 'CUENTAS ACTIVAS (Ctrl+1)'),
              Tab(icon: Icon(Icons.add_shopping_cart), text: 'NUEVO PRÉSTAMO (Ctrl+2)'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            const _PestanaCuentasGrid(),
            _PestanaNuevoPrestamo(onCambiarTab: _cambiarTab),
          ],
        ),
      ),
    );
  }
}

class _PestanaCuentasGrid extends StatefulWidget {
  const _PestanaCuentasGrid();
  @override State<_PestanaCuentasGrid> createState() => _PestanaCuentasGridState();
}

class _PestanaCuentasGridState extends State<_PestanaCuentasGrid> {
  final FocusNode _gridFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) FocusScope.of(context).requestFocus(_gridFocus);
    });
  }

  @override
  void dispose() { _gridFocus.dispose(); _scrollController.dispose(); super.dispose(); }

  void _scrollToIndex(int index) {
    if (_scrollController.hasClients) {
      final double cardHeight = 260.0; // Altura aproximada de la tarjeta
      int columns = (MediaQuery.of(context).size.width - 32) ~/ 260;
      if (columns < 1) columns = 1;

      int row = index ~/ columns;
      double offset = row * cardHeight;
      _scrollController.animateTo(offset, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrestamosProvider>();
    final NumberFormat currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    if (provider.isLoading) return const Center(child: CircularProgressIndicator());

    // Usamos las cuentas filtradas en lugar de cuentasAgrupadas directamente
    final cuentasMostradas = provider.cuentasFiltradas;

    return Column(
      children: [
        // BARRA DE BÚSQUEDA Y BOTÓN DE FILTROS SUPERIOR
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar deudor por nombre...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (val) {
                    provider.setFiltroBusqueda(val);
                    setState(() => _selectedIndex = 0); // Resetear selección al buscar
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.tune),
                label: const Text('ORDEN Y FILTROS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const _DialogoFiltrosDeudores(),
                  ).then((_) {
                    setState(() => _selectedIndex = 0); // Resetear selección tras filtrar
                    FocusScope.of(context).requestFocus(_gridFocus);
                  });
                },
              ),
            ],
          ),
        ),

        // GRID VIEW
        Expanded(
          child: cuentasMostradas.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sentiment_satisfied_alt, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(provider.cuentasAgrupadas.isEmpty
                    ? '¡Excelente! Nadie te debe dinero en este momento.'
                    : 'No se encontraron deudores con esos filtros.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
              ],
            ),
          )
              : Focus(
            focusNode: _gridFocus,
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                final key = event.logicalKey;
                int columns = (MediaQuery.of(context).size.width - 32) ~/ 260;
                if (columns < 1) columns = 1;

                int totalItems = cuentasMostradas.length;

                if (key == LogicalKeyboardKey.arrowRight) {
                  if (_selectedIndex < totalItems - 1) { setState(() => _selectedIndex++); _scrollToIndex(_selectedIndex); }
                  return KeyEventResult.handled;
                } else if (key == LogicalKeyboardKey.arrowLeft) {
                  if (_selectedIndex > 0) { setState(() => _selectedIndex--); _scrollToIndex(_selectedIndex); }
                  return KeyEventResult.handled;
                } else if (key == LogicalKeyboardKey.arrowDown) {
                  if (_selectedIndex + columns < totalItems) { setState(() => _selectedIndex += columns); _scrollToIndex(_selectedIndex); }
                  else { setState(() => _selectedIndex = totalItems - 1); _scrollToIndex(_selectedIndex); }
                  return KeyEventResult.handled;
                } else if (key == LogicalKeyboardKey.arrowUp) {
                  if (_selectedIndex - columns >= 0) { setState(() => _selectedIndex -= columns); _scrollToIndex(_selectedIndex); }
                  else { setState(() => _selectedIndex = 0); _scrollToIndex(_selectedIndex); }
                  return KeyEventResult.handled;
                } else if (key == LogicalKeyboardKey.enter && _selectedIndex >= 0 && _selectedIndex < totalItems) {
                  _mostrarEstadoDeCuenta(context, cuentasMostradas[_selectedIndex]);
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.builder(
                controller: _scrollController,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  childAspectRatio: 0.95,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: cuentasMostradas.length,
                itemBuilder: (context, index) {
                  final cuenta = cuentasMostradas[index];
                  final double deudaTotal = cuenta['deuda_total'];
                  final bool isSelected = index == _selectedIndex;

                  return Card(
                    elevation: isSelected ? 12 : 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isSelected ? const BorderSide(color: Colors.orange, width: 3) : BorderSide.none,
                    ),
                    child: Stack(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() => _selectedIndex = index);
                            _gridFocus.requestFocus();
                            _mostrarEstadoDeCuenta(context, cuenta);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(radius: 35, backgroundColor: isSelected ? Colors.orange.shade100 : Colors.indigo.shade50, child: Icon(Icons.person, size: 40, color: isSelected ? Colors.orange : Colors.indigo)),
                                  const SizedBox(height: 12),
                                  Text(cuenta['nombre'], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  const Text('Deuda Total:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text(currencyFormat.format(deudaTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.red)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) {
                              if (value == 'editar') _editarCliente(context, cuenta);
                              if (value == 'eliminar') _eliminarCliente(context, cuenta);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, size: 20, color: Colors.blue), SizedBox(width: 8), Text('Editar Nombre')])),
                              PopupMenuItem(value: 'eliminar', enabled: true, child: Row(children: [Icon(Icons.delete, size: 20, color: deudaTotal > 0 ? Colors.grey : Colors.red), SizedBox(width: 8), Text('Eliminar Cliente', style: TextStyle(color: deudaTotal > 0 ? Colors.grey : Colors.red))])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarEstadoDeCuenta(BuildContext context, Map<String, dynamic> cuenta) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => _DialogoEstadoDeCuenta(clienteId: cuenta['cliente_id'], nombre: cuenta['nombre'], deudaTotal: cuenta['deuda_total'])).then((_) {
      // Al cerrar la ventana, recuperamos el control del grid
      Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_gridFocus); });
    });
  }

  void _editarCliente(BuildContext context, Map<String, dynamic> cuenta) {
    final TextEditingController ctrl = TextEditingController(text: cuenta['nombre']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Nombre'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              final exito = await context.read<PrestamosProvider>().editarNombreCliente(cuenta['cliente_id'], ctrl.text);
              if (exito && ctx.mounted) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Nombre actualizado'), backgroundColor: AppColors.success)); Navigator.pop(ctx); }
            },
            child: const Text('GUARDAR'),
          )
        ],
      ),
    ).then((_) => Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_gridFocus); }));
  }

  void _eliminarCliente(BuildContext context, Map<String, dynamic> cuenta) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar cliente?'),
        content: Text('¿Estás seguro de eliminar a ${cuenta['nombre']} del catálogo? Esta acción borrará su historial.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final exito = await context.read<PrestamosProvider>().eliminarCliente(cuenta['cliente_id'], cuenta['deuda_total']);
              if (ctx.mounted) {
                if (exito) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Cliente eliminado'), backgroundColor: AppColors.success)); }
                else { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No se puede eliminar un cliente con deuda pendiente'), backgroundColor: AppColors.error)); }
                Navigator.pop(ctx);
              }
            },
            child: const Text('ELIMINAR'),
          )
        ],
      ),
    ).then((_) => Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_gridFocus); }));
  }
}

class _DialogoEstadoDeCuenta extends StatefulWidget {
  final int clienteId;
  final String nombre;
  final double deudaTotal;

  const _DialogoEstadoDeCuenta({required this.clienteId, required this.nombre, required this.deudaTotal});

  @override
  State<_DialogoEstadoDeCuenta> createState() => _DialogoEstadoDeCuentaState();
}

class _DialogoEstadoDeCuentaState extends State<_DialogoEstadoDeCuenta> {
  final TextEditingController _abonoController = TextEditingController();
  final TextEditingController _prestamoController = TextEditingController(); // ⭐ NUEVO CONTROLADOR
  final NumberFormat _cFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  bool _isProcessing = false;
  List<Map<String, dynamic>> _historial = [];
  bool _isLoadingHistorial = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _abonoController.dispose();
    _prestamoController.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    final hist = await context.read<PrestamosProvider>().obtenerHistorialCliente(widget.clienteId);
    if (mounted) setState(() { _historial = hist; _isLoadingHistorial = false; });
  }

  Future<void> _procesarAbono() async {
    final montoStr = _abonoController.text;
    final monto = double.tryParse(montoStr);
    if (monto == null || monto <= 0 || monto > widget.deudaTotal) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monto inválido'))); return; }

    final turnoId = context.read<TurnoProvider>().turnoActivo?.id;
    if (turnoId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abre un turno primero'))); return; }

    setState(() => _isProcessing = true);
    final exito = await context.read<PrestamosProvider>().abonarAClienteGlobal(clienteId: widget.clienteId, turnoId: turnoId, montoPago: monto);

    if (mounted) {
      setState(() => _isProcessing = false);
      if (exito) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Abono registrado correctamente'), backgroundColor: AppColors.success)); Navigator.pop(context); }
    }
  }

  // ⭐ NUEVA FUNCIÓN PARA PROCESAR EL PRÉSTAMO FÍSICO
  Future<void> _procesarPrestamoEfectivo() async {
    final montoStr = _prestamoController.text;
    final monto = double.tryParse(montoStr);
    if (monto == null || monto <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monto inválido'))); return; }

    final turnoId = context.read<TurnoProvider>().turnoActivo?.id;
    if (turnoId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abre un turno primero'))); return; }

    setState(() => _isProcessing = true);
    final exito = await context.read<PrestamosProvider>().prestarEfectivoGlobal(clienteId: widget.clienteId, nombreCliente: widget.nombre, turnoId: turnoId, montoPrestado: monto);

    if (mounted) {
      setState(() => _isProcessing = false);
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Préstamo otorgado. El dinero se descontó de tu caja.'), backgroundColor: AppColors.success));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al procesar el préstamo'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600, height: 750, padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.indigo.shade100, child: const Icon(Icons.person, color: Colors.indigo)),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('Deuda Actual: ${_cFormat.format(widget.deudaTotal)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))]),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 24),

            // CAJA VERDE: RECIBIR DINERO
            Container(
              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
              child: Row(
                children: [
                  const Text('Recibir Abono:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _abonoController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(prefixText: '\$ ', border: OutlineInputBorder(), filled: true, fillColor: Colors.white, hintText: '0.00', isDense: true), onSubmitted: (_) => _procesarAbono())),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(onPressed: _isProcessing ? null : _procesarAbono, icon: _isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.payment, size: 18), label: const Text('COBRAR'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ⭐ CAJA NARANJA: PRESTAR DINERO FÍSICO
            Container(
              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
              child: Row(
                children: [
                  const Text('Prestar Efectivo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.deepOrange)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _prestamoController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(prefixText: '\$ ', border: OutlineInputBorder(), filled: true, fillColor: Colors.white, hintText: '0.00', isDense: true), onSubmitted: (_) => _procesarPrestamoEfectivo())),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(onPressed: _isProcessing ? null : _procesarPrestamoEfectivo, icon: _isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.outbox, size: 18), label: const Text('ENTREGAR'), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white)),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Historial de Movimientos:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            const SizedBox(height: 8),

            Expanded(
              child: _isLoadingHistorial
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                itemCount: _historial.length,
                itemBuilder: (context, index) {
                  final item = _historial[index];
                  final prestamo = item['prestamo'];
                  final detalles = item['detalles'] as List;
                  final abonos = item['abonos'] as List;
                  final fecha = DateTime.parse(prestamo['fecha']);
                  final bool estaPagado = prestamo['estado'] == 'pagado';

                  // ⭐ Si no hay detalles, asumimos que fue un préstamo en efectivo puro
                  final bool esPrestamoEfectivo = detalles.isEmpty;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12), color: estaPagado ? Colors.grey.shade50 : Colors.white,
                    child: ExpansionTile(
                      leading: Icon(estaPagado ? Icons.check_circle : Icons.warning, color: estaPagado ? Colors.green : Colors.orange),
                      title: Text(esPrestamoEfectivo ? 'Préstamo en Efectivo del ${DateFormat('dd/MM/yy').format(fecha)}' : 'Préstamo del ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}', style: TextStyle(fontWeight: estaPagado ? FontWeight.normal : FontWeight.bold)),
                      subtitle: Text('Total: ${_cFormat.format(prestamo['total'])} | Pendiente: ${_cFormat.format(prestamo['saldo_pendiente'])}'),
                      children: [
                        if (!esPrestamoEfectivo) ...[
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerLeft, child: Text('Productos llevados:', style: TextStyle(fontWeight: FontWeight.bold)))),
                          ...detalles.map((d) => ListTile(dense: true, title: Text('${d['cantidad']}x ${d['producto_nombre']}'), trailing: Text(_cFormat.format(d['subtotal'])))),
                        ],
                        if (abonos.isNotEmpty) ...[
                          const Divider(),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerLeft, child: Text('Abonos a esta cuenta:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)))),
                          ...abonos.map((a) => ListTile(dense: true, leading: const Icon(Icons.arrow_downward, color: Colors.green, size: 16), title: Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(a['fecha']))), trailing: Text(_cFormat.format(a['monto']), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))),
                        ]
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
class _PestanaNuevoPrestamo extends StatefulWidget {
  final Function(int) onCambiarTab;

  const _PestanaNuevoPrestamo({required this.onCambiarTab});

  @override
  State<_PestanaNuevoPrestamo> createState() => _PestanaNuevoPrestamoState();
}

class _PestanaNuevoPrestamoState extends State<_PestanaNuevoPrestamo> {
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocus;
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _cFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

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

        if (event is KeyDownEvent) {
          if (HardwareKeyboard.instance.isControlPressed) {
            if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) { widget.onCambiarTab(0); return KeyEventResult.handled; }
            else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) { widget.onCambiarTab(1); return KeyEventResult.handled; }
          }
          if (key == LogicalKeyboardKey.f12) { _procesarPrestamo(context); return KeyEventResult.handled; }
        }

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
          final provider = context.read<PrestamosProvider>();

          if (provider.carrito.isNotEmpty) {
            if (isArrow) {
              if (event is KeyDownEvent) {
                if (key == LogicalKeyboardKey.arrowDown) { setState(() => _selectedRowIndex = (_selectedRowIndex < provider.carrito.length - 1) ? _selectedRowIndex + 1 : _selectedRowIndex); Future.delayed(Duration.zero, _scrollToSelected); }
                else if (key == LogicalKeyboardKey.arrowUp) { setState(() => _selectedRowIndex = (_selectedRowIndex > 0) ? _selectedRowIndex - 1 : 0); Future.delayed(Duration.zero, _scrollToSelected); }
              }
              return KeyEventResult.handled;
            }

            if (event is KeyDownEvent) {
              if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
                if (_selectedRowIndex >= 0 && _selectedRowIndex < provider.carrito.length) { provider.eliminarItem(_selectedRowIndex); setState(() { if (_selectedRowIndex >= provider.carrito.length) _selectedRowIndex = provider.carrito.length - 1; }); }
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
    final resultados = context.read<PrestamosProvider>().buscarProductos(query);
    setState(() { _sugerencias = resultados; _mostrarSugerencias = _sugerencias.isNotEmpty; _selectedSuggestionIndex = _sugerencias.isNotEmpty ? 0 : -1; _selectedRowIndex = -1; });
  }

  Future<void> _agregar(Producto producto) async {
    // Ya no reseteamos el _selectedRowIndex a -1 aquí
    setState(() { _mostrarSugerencias = false; _searchController.clear(); });

    double cantidad;
    if (producto.aGranel) {
      final cantidadGranel = await showDialog<double>(context: context, barrierDismissible: false, builder: (context) => VentaGranelDialog(producto: producto));
      if (cantidadGranel == null) { Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_searchFocus); }); return; }
      cantidad = cantidadGranel;
    } else {
      cantidad = 1.0;
    }

    final provider = context.read<PrestamosProvider>();
    provider.agregarProducto(producto, cantidad);

    // ⭐ NUEVO: Detectar en qué índice quedó el producto
    final indexActualizado = provider.carrito.indexWhere((item) => item.producto.id == producto.id);

    // ⭐ NUEVO: Actualizar el selector visual a ese índice
    setState(() {
      _selectedRowIndex = indexActualizado >= 0 ? indexActualizado : provider.carrito.length - 1;
    });

    // ⭐ NUEVO: Dar tiempo a que el Frame se dibuje y hacer scroll hacia ese elemento
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _scrollToSelected();
        FocusScope.of(context).requestFocus(_searchFocus);
      }
    });
  }

  Future<void> _editarCantidadItem(int index) async {
    final provider = context.read<PrestamosProvider>();
    final item = provider.carrito[index];
    double? nuevaCantidad;

    if (item.producto.aGranel) { nuevaCantidad = await showDialog<double>(context: context, barrierDismissible: false, builder: (context) => VentaGranelDialog(producto: item.producto)); }
    else { nuevaCantidad = await showDialog<double>(context: context, builder: (context) => CantidadDialog(producto: item.producto)); }

    if (nuevaCantidad != null && nuevaCantidad > 0) provider.actualizarCantidad(index, nuevaCantidad);
    Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_searchFocus); });
  }

  void _procesarPrestamo(BuildContext context) {
    if (context.read<PrestamosProvider>().carritoVacio) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const _DialogoAsignarCliente()).then((_) { Future.delayed(const Duration(milliseconds: 100), () { if (mounted) FocusScope.of(context).requestFocus(_searchFocus); }); });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrestamosProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && ModalRoute.of(context)?.isCurrent == true) { FocusScope.of(context).requestFocus(_searchFocus); } });

    return Column(
      children: [
        Container(
          color: Colors.white, padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController, focusNode: _searchFocus, autofocus: true,
            decoration: InputDecoration(hintText: 'Buscar producto para fiar...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.indigo.shade50),
            onChanged: _buscar,
            onSubmitted: (v) {
              if (_mostrarSugerencias && _sugerencias.isNotEmpty && _selectedSuggestionIndex != -1) { _agregar(_sugerencias[_selectedSuggestionIndex]); }
              else if (_sugerencias.length == 1) { _agregar(_sugerencias.first); }
            },
          ),
        ),
        if (_mostrarSugerencias)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchDropdown<Producto>(
              items: _sugerencias, maxHeight: 250, selectedIndex: _selectedSuggestionIndex,
              onDismiss: () => setState(() => _mostrarSugerencias = false),
              itemBuilder: (ctx, p, isSelected) => ListTile(leading: Icon(Icons.inventory_2, color: isSelected ? Colors.indigo : Colors.grey), title: Text(p.nombreConUnidad, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), trailing: Text(_cFormat.format(p.precioVenta), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
              onItemSelected: _agregar,
            ),
          ),
        Expanded(
          child: provider.carritoVacio
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey.shade300), const Text('Agrega los productos que se van a llevar a crédito', style: TextStyle(color: Colors.grey))]))
              : Container(
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium, vertical: AppSizes.paddingSmall),
                  decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), border: const Border(bottom: BorderSide(color: AppColors.divider))),
                  child: Row(
                    children: const [
                      Expanded(flex: 4, child: Text('PRODUCTO', style: AppTextStyles.tableHeader)),
                      Expanded(flex: 2, child: Text('CANT', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('PRECIO', style: AppTextStyles.tableHeader, textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text('TOTAL', style: AppTextStyles.tableHeader, textAlign: TextAlign.right)),
                      SizedBox(width: 50),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: _scrollController, itemCount: provider.carrito.length, separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = provider.carrito[index];
                      final isSelectedRow = index == _selectedRowIndex;

                      return Container(
                        decoration: BoxDecoration(color: isSelectedRow ? Colors.orange.withOpacity(0.15) : (index % 2 == 0 ? Colors.indigo.shade50 : Colors.white), border: isSelectedRow ? Border.all(color: Colors.orange, width: 1.5) : null),
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium, vertical: AppSizes.paddingSmall),
                        child: Row(
                          children: [
                            Expanded(flex: 4, child: Text(item.producto.nombreConUnidad, style: const TextStyle(fontSize: AppSizes.bodyMedium, fontWeight: FontWeight.w500))),
                            Expanded(flex: 2, child: InkWell(onTap: () => _editarCantidadItem(index), child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(item.producto.aGranel ? item.cantidad.toStringAsFixed(2) : item.cantidad.toInt().toString(), style: const TextStyle(fontSize: AppSizes.bodyMedium, fontWeight: FontWeight.bold, color: Colors.indigo), textAlign: TextAlign.center)))),
                            Expanded(flex: 2, child: Text(_cFormat.format(item.producto.precioVenta), style: const TextStyle(fontSize: AppSizes.bodyMedium), textAlign: TextAlign.right)),
                            Expanded(flex: 2, child: Text(_cFormat.format(item.subtotal), style: const TextStyle(fontSize: AppSizes.bodyMedium, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                            SizedBox(width: 50, child: IconButton(icon: const Icon(Icons.delete, color: AppColors.error), onPressed: () { provider.eliminarItem(index); _searchFocus.requestFocus(); })),
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('TOTAL A FIAR:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), Text(_cFormat.format(provider.totalCarrito), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.indigo))])),
              SizedBox(height: 60, width: 280, child: ElevatedButton.icon(onPressed: provider.carritoVacio ? null : () => _procesarPrestamo(context), icon: const Icon(Icons.person_add_alt_1, size: 28), label: const Text('ASIGNAR A CLIENTE (F12)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogoAsignarCliente extends StatefulWidget {
  const _DialogoAsignarCliente();
  @override State<_DialogoAsignarCliente> createState() => _DialogoAsignarClienteState();
}

class _DialogoAsignarClienteState extends State<_DialogoAsignarCliente> {
  final TextEditingController _clienteController = TextEditingController();
  final FocusNode _clienteFocus = FocusNode();
  Map<String, dynamic>? _clienteSeleccionado;
  bool _isProcessing = false;

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) FocusScope.of(context).requestFocus(_clienteFocus); }); }
  @override void dispose() { _clienteController.dispose(); _clienteFocus.dispose(); super.dispose(); }

  Future<void> _guardar() async {
    final provider = context.read<PrestamosProvider>();
    final turnoId = context.read<TurnoProvider>().turnoActivo?.id;
    final nombreEscrito = _clienteController.text.trim();

    if (turnoId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abre un turno primero'))); return; }
    if (_clienteSeleccionado == null && nombreEscrito.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona o escribe un nombre'))); return; }

    setState(() => _isProcessing = true);
    final exito = await provider.registrarPrestamo(turnoId: turnoId, clienteId: _clienteSeleccionado?['id'], nombreNuevoCliente: _clienteSeleccionado == null ? nombreEscrito : null);
    if (mounted) { setState(() => _isProcessing = false); if (exito) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Préstamo registrado y asignado correctamente'), backgroundColor: AppColors.success)); Navigator.pop(context); } }
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<PrestamosProvider>().catalogoClientes;
    return AlertDialog(
      title: const Text('¿A la cuenta de quién?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Busca un cliente existente o escribe un nombre nuevo para crearle su perfil oficial.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            RawAutocomplete<Map<String, dynamic>>(
              focusNode: _clienteFocus, textEditingController: _clienteController,
              optionsBuilder: (TextEditingValue textEditingValue) { if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty(); return catalogo.where((c) => c['nombre'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase())); },
              displayStringForOption: (option) => option['nombre'],
              onSelected: (option) { setState(() => _clienteSeleccionado = option); _guardar(); },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller, focusNode: focusNode, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre del Cliente', prefixIcon: Icon(Icons.person_search), border: OutlineInputBorder()),
                  onChanged: (val) { if (_clienteSeleccionado != null && val != _clienteSeleccionado!['nombre']) { setState(() => _clienteSeleccionado = null); } },
                  onSubmitted: (_) { onFieldSubmitted(); Future.delayed(const Duration(milliseconds: 50), () { if (mounted && _clienteSeleccionado == null) { _guardar(); } }); },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      width: 350, height: 200,
                      child: ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          final bool isHighlighted = AutocompleteHighlightedOption.of(context) == index;
                          return Container(color: isHighlighted ? Colors.orange.withOpacity(0.2) : Colors.transparent, child: ListTile(leading: Icon(Icons.person, color: isHighlighted ? Colors.orange : Colors.indigo), title: Text(option['nombre'], style: TextStyle(fontWeight: FontWeight.bold, color: isHighlighted ? Colors.orange.shade800 : Colors.black)), onTap: () => onSelected(option)));
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_clienteSeleccionado == null && _clienteController.text.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8.0), child: Row(children: const [Icon(Icons.new_releases, color: Colors.orange, size: 16), SizedBox(width: 4), Text('Se creará un NUEVO cliente', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))])),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
        ElevatedButton(onPressed: _isProcessing ? null : _guardar, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('GUARDAR PRÉSTAMO')),
      ],
    );
  }
}

class _DialogoFiltrosDeudores extends StatefulWidget {
  const _DialogoFiltrosDeudores();

  @override
  State<_DialogoFiltrosDeudores> createState() => _DialogoFiltrosDeudoresState();
}

class _DialogoFiltrosDeudoresState extends State<_DialogoFiltrosDeudores> {
  final TextEditingController _minController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<PrestamosProvider>();
    if (provider.montoMinimoActual != null) _minController.text = provider.montoMinimoActual.toString();
    if (provider.montoMaximoActual != null) _maxController.text = provider.montoMaximoActual.toString();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrestamosProvider>();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune, color: Colors.indigo),
          SizedBox(width: 8),
          Text('Ordenar y Filtrar'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ordenar por:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),

              // Botones de Ordenamiento
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Deuda: Mayor a Menor'),
                    selected: provider.criterioOrdenActual == 'deuda_desc',
                    onSelected: (val) => provider.setCriterioOrden('deuda_desc'),
                  ),
                  ChoiceChip(
                    label: const Text('Deuda: Menor a Mayor'),
                    selected: provider.criterioOrdenActual == 'deuda_asc',
                    onSelected: (val) => provider.setCriterioOrden('deuda_asc'),
                  ),
                  ChoiceChip(
                    label: const Text('Antigüedad: Más Viejas Primero'),
                    selected: provider.criterioOrdenActual == 'antiguedad_asc',
                    onSelected: (val) => provider.setCriterioOrden('antiguedad_asc'),
                  ),
                  ChoiceChip(
                    label: const Text('Antigüedad: Más Nuevas Primero'),
                    selected: provider.criterioOrdenActual == 'antiguedad_desc',
                    onSelected: (val) => provider.setCriterioOrden('antiguedad_desc'),
                  ),
                ],
              ),
              const Divider(height: 32),

              const Text('Filtrar por Rango de Deuda:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 16),

              // Rango de Precios
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Mínimo \$', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('a')),
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Máximo \$', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            provider.limpiarFiltrosAvanzados();
            _minController.clear();
            _maxController.clear();
          },
          child: const Text('LIMPIAR FILTROS', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          onPressed: () {
            double? min = double.tryParse(_minController.text);
            double? max = double.tryParse(_maxController.text);
            provider.setRangoMontos(min, max);
            Navigator.pop(context);
          },
          child: const Text('APLICAR'),
        ),
      ],
    );
  }
}