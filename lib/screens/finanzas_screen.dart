// lib/screens/finanzas_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/finanzas_provider.dart';
import '../providers/turno_provider.dart';
import '../database/database_helper.dart';
import '../widgets/gasto_dialog.dart';

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({super.key});

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FocusNode _mainFocus = FocusNode();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('HH:mm');
  final DateFormat _dayFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _monthFormat = DateFormat('MMMM yyyy');

  DateTime _fechaSeleccionada = DateTime.now();
  bool _verPorMes = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seleccionarDiaActual();
      FocusScope.of(context).requestFocus(_mainFocus);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mainFocus.dispose();
    super.dispose();
  }

  Future<void> _seleccionarDiaActual() async {
    final turnoProvider = context.read<TurnoProvider>();
    final finanzas = context.read<FinanzasProvider>();
    if (turnoProvider.hayTurnoActivo) {
      await finanzas.cargarBalance(turnoProvider.turnoActivo!.id!);
    }
    await finanzas.cargarHistorialMixto(_fechaSeleccionada, _verPorMes);
  }

  Future<void> _seleccionarDia() async {
    DateTime? picked = await showDatePicker(context: context, initialDate: _fechaSeleccionada, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) {
      setState(() { _fechaSeleccionada = picked; _verPorMes = false; });
      _seleccionarDiaActual();
    }
    FocusScope.of(context).requestFocus(_mainFocus);
  }

  Future<void> _seleccionarMes() async {
    DateTime? picked = await showDialog<DateTime>(context: context, builder: (context) => _MonthPickerDialog(initialDate: _fechaSeleccionada));
    if (picked != null) {
      setState(() { _fechaSeleccionada = picked; _verPorMes = true; });
      final finanzas = context.read<FinanzasProvider>();
      await finanzas.cargarResumenMensual(picked);
      await finanzas.cargarHistorialMixto(picked, true);
    }
    FocusScope.of(context).requestFocus(_mainFocus);
  }

  Future<void> _realizarCorte() async {
    final turnoProvider = context.read<TurnoProvider>();
    if (!turnoProvider.hayTurnoActivo) return;
    final montoReal = await showDialog<double>(context: context, builder: (context) => _CorteDialog());
    if (montoReal != null) {
      final exito = await turnoProvider.cerrarCaja(montoReal);
      if (exito && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turno cerrado exitosamente'), backgroundColor: AppColors.success));
    }
    FocusScope.of(context).requestFocus(_mainFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _mainFocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && HardwareKeyboard.instance.isControlPressed) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) { _tabController.animateTo(0); return KeyEventResult.handled; }
          if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) { _tabController.animateTo(1); return KeyEventResult.handled; }
          if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) { _tabController.animateTo(2); return KeyEventResult.handled; }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.financeBlue,
          title: const Text('Finanzas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            controller: _tabController, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70,
            tabs: const [Tab(text: 'VENTAS Y ABONOS (Ctrl+1)'), Tab(text: 'GASTOS E INVERSIÓN (Ctrl+2)'), Tab(text: 'DASHBOARD (Ctrl+3)')],
          ),
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.today, color: AppColors.financeBlue), label: Text('DÍA: ${_dayFormat.format(_fechaSeleccionada)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.financeBlue)),
              style: ElevatedButton.styleFrom(backgroundColor: !_verPorMes ? Colors.white : Colors.white70, padding: const EdgeInsets.symmetric(horizontal: 16)), onPressed: _seleccionarDia,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.calendar_month, color: AppColors.financeBlue), label: Text('MES: ${_monthFormat.format(_fechaSeleccionada).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.financeBlue)),
              style: ElevatedButton.styleFrom(backgroundColor: _verPorMes ? Colors.white : Colors.white70, padding: const EdgeInsets.symmetric(horizontal: 16)), onPressed: _seleccionarMes,
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Consumer2<FinanzasProvider, TurnoProvider>(
          builder: (context, finanzas, turno, child) {
            if (finanzas.isLoading) return const Center(child: CircularProgressIndicator());
            if (!turno.hayTurnoActivo && !_verPorMes) return const Center(child: Text('No hay turno activo', style: TextStyle(fontSize: AppSizes.titleMedium)));

            return TabBarView(
              controller: _tabController,
              children: [
                _buildVentasTab(finanzas, turno),
                _buildGastosTab(finanzas, turno),
                _verPorMes ? _buildMonthlyDashboard(finanzas) : _buildDailyDashboard(finanzas, turno),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==================== DASHBOARDS ====================
  Widget _buildDailyDashboard(FinanzasProvider finanzas, TurnoProvider turno) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildBigCard(title: 'DINERO FÍSICO EN CAJA', amount: finanzas.dineroEnCaja, icon: Icons.point_of_sale, color: AppColors.primaryBlue, subtitle: 'Efectivo esperado en el cajón')),
              const SizedBox(width: AppSizes.paddingLarge),
              Expanded(child: _buildBigCard(title: 'GANANCIA DEL TURNO', amount: finanzas.gananciaReal, icon: Icons.trending_up, color: AppColors.success, subtitle: 'Utilidad libre de hoy')),
            ],
          ),
          const SizedBox(height: AppSizes.paddingLarge),
          const Text('INGRESOS DEL DÍA', style: TextStyle(fontSize: AppSizes.titleSmall, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: AppSizes.paddingMedium),
          Row(
            children: [
              Expanded(child: _buildVentasTotalesCard(finanzas.ventasHoy, finanzas.ventasEfectivo, finanzas.ventasTarjeta)),
              const SizedBox(width: AppSizes.paddingMedium),
              Expanded(
                child: Column(
                  children: [
                    _buildSmallCard(title: 'Abonos de Préstamos', amount: finanzas.totalAbonos, icon: Icons.handshake, color: Colors.green.shade700),
                    const SizedBox(height: 8),
                    _buildSmallCard(title: 'Fondo Inicial de Caja', amount: finanzas.cajaInicial, icon: Icons.account_balance_wallet, color: Colors.grey.shade700),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingLarge),
          const Text('SALIDAS Y GASTOS DEL DÍA', style: TextStyle(fontSize: AppSizes.titleSmall, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: AppSizes.paddingMedium),
          Row(
            children: [
              Expanded(child: _buildSmallCard(title: 'Gastos Operativos', amount: finanzas.gastosOperativos, icon: Icons.receipt_long, color: AppColors.error, isNegative: true)),
              const SizedBox(width: AppSizes.paddingMedium),
              Expanded(child: _buildSmallCard(title: 'Pérdidas por Merma', amount: finanzas.totalMerma, icon: Icons.delete_sweep, color: Colors.deepOrange, isNegative: true)),
              const SizedBox(width: AppSizes.paddingMedium),
              Expanded(child: _buildSmallCard(title: 'Inversión y Resurtido', amount: finanzas.inversionInicial + finanzas.totalSurtido, icon: Icons.inventory, color: Colors.orange.shade700, isNegative: true)),
            ],
          ),
          if (finanzas.gastosAgrupados.isNotEmpty || finanzas.mermasAgrupadas.isNotEmpty) ...[
            const SizedBox(height: AppSizes.paddingLarge),
            const Text('DESGLOSE DE CATEGORÍAS', style: TextStyle(fontSize: AppSizes.titleSmall, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2)),
            const SizedBox(height: AppSizes.paddingMedium),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (finanzas.gastosAgrupados.isNotEmpty) Expanded(child: _buildCategoriasBox('GASTOS', finanzas.gastosAgrupados, AppColors.error)),
                if (finanzas.gastosAgrupados.isNotEmpty && finanzas.mermasAgrupadas.isNotEmpty) const SizedBox(width: 16),
                if (finanzas.mermasAgrupadas.isNotEmpty) Expanded(child: _buildCategoriasBox('MERMAS (MOTIVOS)', finanzas.mermasAgrupadas, Colors.deepOrange)),
              ],
            ),
          ],
          const SizedBox(height: AppSizes.paddingLarge * 2),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _realizarCorte, icon: const Icon(Icons.cut, size: AppSizes.iconMedium), label: const Text('REALIZAR CORTE DEL DÍA', style: TextStyle(fontSize: AppSizes.bodyLarge, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingLarge), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 4))),
        ],
      ),
    );
  }

  Widget _buildMonthlyDashboard(FinanzasProvider finanzas) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildBigCard(title: 'UTILIDAD NETA MENSUAL', amount: finanzas.gananciaNetaMensual, icon: Icons.emoji_events, color: Colors.amber.shade700, subtitle: 'Tu ganancia 100% limpia del mes')),
              const SizedBox(width: AppSizes.paddingLarge),
              Expanded(child: _buildBigCard(title: 'INGRESOS TOTALES', amount: finanzas.ventasMesTotal + finanzas.abonosMes, icon: Icons.storefront, color: AppColors.primaryBlue, subtitle: 'Ventas brutas + Abonos recuperados')),
            ],
          ),
          const SizedBox(height: AppSizes.paddingLarge),
          const Text('ESTADO DE RESULTADOS MENSUAL', style: TextStyle(fontSize: AppSizes.titleSmall, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: AppSizes.paddingMedium),
          Row(
            children: [
              Expanded(child: _buildVentasTotalesCard(finanzas.ventasMesTotal, finanzas.ventasMesEfectivo, finanzas.ventasMesTarjeta)),
              const SizedBox(width: AppSizes.paddingMedium),
              Expanded(
                child: Column(
                  children: [
                    _buildSmallCard(title: 'Abonos Recuperados', amount: finanzas.abonosMes, icon: Icons.handshake, color: Colors.green.shade700),
                    const SizedBox(height: 8),
                    _buildSmallCard(title: 'Costo de lo Vendido', amount: finanzas.costoVendidoMes, icon: Icons.inventory_2, color: Colors.blueGrey, isNegative: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingMedium),
          Row(
            children: [
              Expanded(child: _buildSmallCard(title: 'Gastos Operativos', amount: finanzas.gastosMes, icon: Icons.receipt_long, color: AppColors.error, isNegative: true)),
              const SizedBox(width: AppSizes.paddingMedium),
              Expanded(child: _buildSmallCard(title: 'Pérdidas por Merma', amount: finanzas.mermasMes, icon: Icons.delete_sweep, color: Colors.deepOrange, isNegative: true)),
            ],
          ),
          if (finanzas.gastosAgrupadosMes.isNotEmpty || finanzas.mermasAgrupadasMes.isNotEmpty) ...[
            const SizedBox(height: AppSizes.paddingLarge),
            const Text('DESGLOSE MENSUAL DE CATEGORÍAS', style: TextStyle(fontSize: AppSizes.titleSmall, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2)),
            const SizedBox(height: AppSizes.paddingMedium),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (finanzas.gastosAgrupadosMes.isNotEmpty) Expanded(child: _buildCategoriasBox('GASTOS', finanzas.gastosAgrupadosMes, AppColors.error)),
                if (finanzas.gastosAgrupadosMes.isNotEmpty && finanzas.mermasAgrupadasMes.isNotEmpty) const SizedBox(width: 16),
                if (finanzas.mermasAgrupadasMes.isNotEmpty) Expanded(child: _buildCategoriasBox('MERMAS', finanzas.mermasAgrupadasMes, Colors.deepOrange)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==================== TARJETAS UI ====================
  Widget _buildCategoriasBox(String titulo, List<Map<String, dynamic>> datos, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingMedium), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12, letterSpacing: 1.5)), const Divider(),
          ...datos.map((d) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(d['categoria'].toString(), style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)), Text(_currencyFormat.format(d['total']), style: const TextStyle(fontWeight: FontWeight.bold))]))),
        ],
      ),
    );
  }

  Widget _buildBigCard({required String title, required double amount, required IconData icon, required Color color, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingLarge), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))], border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 28)), const SizedBox(width: 12), Expanded(child: Text(title, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)))]),
          const SizedBox(height: 20),
          Text(_currencyFormat.format(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 36)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildVentasTotalesCard(double total, double efec, double tarj) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingMedium), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))], border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [CircleAvatar(radius: 18, backgroundColor: Colors.blueGrey.withOpacity(0.1), child: const Icon(Icons.storefront, color: Colors.blueGrey, size: 18)), const SizedBox(width: 8), Text('Ventas Directas', style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 8),
          Text(_currencyFormat.format(total), style: const TextStyle(color: Colors.blueGrey, fontSize: 20, fontWeight: FontWeight.bold)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(Icons.money, size: 16, color: AppColors.financeGreen), const SizedBox(width: 4), Text(_currencyFormat.format(efec), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.financeGreen))]), Row(children: [const Icon(Icons.credit_card, size: 16, color: AppColors.accentBlue), const SizedBox(width: 4), Text(_currencyFormat.format(tarj), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentBlue))])])
        ],
      ),
    );
  }

  Widget _buildSmallCard({required String title, required double amount, required IconData icon, required Color color, bool isNegative = false}) {
    final sign = isNegative ? '-' : '';
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingMedium), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))], border: Border.all(color: Colors.grey.shade200)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text('$sign${_currencyFormat.format(amount)}', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold))]))]),
    );
  }

  // ==================== LISTA DE VENTAS ====================
  Widget _buildVentasTab(FinanzasProvider finanzas, TurnoProvider turno) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _obtenerVentasPorFecha(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final operaciones = snapshot.data ?? [];
        if (operaciones.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]), const SizedBox(height: AppSizes.paddingMedium), const Text('No hay ventas ni abonos en este período', style: TextStyle(fontSize: AppSizes.bodyLarge, color: AppColors.textSecondary))]));

        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.paddingMedium), itemCount: operaciones.length,
          itemBuilder: (context, index) {
            final op = operaciones[index];
            final esAbono = op['tipo_registro'] == 'abono';
            final color = esAbono ? Colors.green.shade700 : (op['metodo_pago'] == 'efectivo' ? AppColors.financeGreen : AppColors.accentBlue);

            return Card(
              margin: const EdgeInsets.only(bottom: AppSizes.paddingSmall), clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(esAbono ? Icons.handshake : (op['metodo_pago'] == 'efectivo' ? Icons.money : Icons.credit_card), color: color)),
                  title: Row(children: [Text(esAbono ? 'Abono de Préstamo' : 'Venta #${op['folio']}', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: AppSizes.paddingSmall), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text(esAbono ? 'ABONO' : op['metodo_pago'].toString().toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)))]),
                  subtitle: Text(_dateFormat.format(DateTime.parse(op['fecha']))),
                  trailing: Text('+ ${_currencyFormat.format(op['total'])}', style: TextStyle(fontSize: AppSizes.bodyLarge, fontWeight: FontWeight.bold, color: color)),
                  children: [
                    if (!esAbono)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingLarge, vertical: AppSizes.paddingSmall), decoration: BoxDecoration(color: Colors.grey[50], border: const Border(top: BorderSide(color: AppColors.divider))),
                        child: Column(children: (op['detalles'] as List).map((d) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 60, child: Text('${d['a_granel'] == 1 ? d['cantidad'].toStringAsFixed(2) : d['cantidad'].toInt()} ${d['a_granel'] == 1 ? (d['unidad_medida'] ?? 'kg') : 'pz'}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentBlue))), const SizedBox(width: 8), Expanded(child: Text(d['nombre'])), Text(_currencyFormat.format(d['subtotal']), style: const TextStyle(fontWeight: FontWeight.bold))]))).toList()),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _obtenerVentasPorFecha() async {
    final db = await DatabaseHelper().database;
    String fecha = _verPorMes ? DateFormat('yyyy-MM').format(_fechaSeleccionada) : DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
    final ventas = await db.query('ventas', where: 'fecha LIKE ?', whereArgs: ['$fecha%']);
    List<Map<String, dynamic>> result = [];
    for (var v in ventas) {
      final det = await db.rawQuery('SELECT vd.cantidad, p.nombre, p.a_granel, p.unidad_medida, vd.subtotal FROM venta_detalle vd JOIN productos p ON vd.producto_id = p.id WHERE vd.venta_id = ?', [v['id']]);
      result.add({...v, 'tipo_registro': 'venta', 'detalles': det});
    }
    final abonos = await db.rawQuery('SELECT id, monto as total, fecha FROM abonos WHERE fecha LIKE ?', ['$fecha%']);
    for (var a in abonos) { result.add({...a, 'tipo_registro': 'abono'}); }
    result.sort((a, b) => b['fecha'].compareTo(a['fecha']));
    return result;
  }

  // ==================== LISTA DE GASTOS Y CANCELACIÓN ====================
  Widget _buildGastosTab(FinanzasProvider finanzas, TurnoProvider turno) {
    final gastos = finanzas.historialMixtoFiltrado;

    return Column(
      children: [
        // ⭐ BARRA DE BÚSQUEDA Y FILTROS
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por producto o categoría...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: Colors.white,
                  ),
                  onChanged: (val) => finanzas.setFiltrosListaMixta(val, finanzas.filtroTipoActual, finanzas.ordenListaActual),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.filter_list), label: const Text('FILTRAR Y ORDENAR'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  showDialog(context: context, builder: (context) => const _DialogoFiltrosGastos()).then((_) => FocusScope.of(context).requestFocus(_mainFocus));
                },
              ),
            ],
          ),
        ),

        // ⭐ LISTA DE MOVIMIENTOS
        Expanded(
          child: gastos.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt, size: 80, color: Colors.grey[300]), const SizedBox(height: AppSizes.paddingMedium), const Text('No hay salidas de dinero que coincidan', style: TextStyle(fontSize: AppSizes.bodyLarge, color: AppColors.textSecondary))]))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium), itemCount: gastos.length,
            itemBuilder: (context, index) {
              final g = gastos[index];
              final color = g['tipo'] == 'surtido' ? Colors.orange : (g['tipo'] == 'operativo' ? AppColors.financeRed : (g['tipo'] == 'devolucion' ? AppColors.success : Colors.deepOrange));
              final icon = g['tipo'] == 'surtido' ? Icons.add_shopping_cart : (g['tipo'] == 'operativo' ? Icons.receipt : (g['tipo'] == 'devolucion' ? Icons.assignment_return : Icons.delete_forever));

              // Validación crucial: ¿Este registro se hizo en el turno abierto actualmente?
              final esDelTurnoActual = turno.hayTurnoActivo && g['turno_id'] == turno.turnoActivo!.id;

              return Card(
                margin: const EdgeInsets.only(bottom: AppSizes.paddingSmall), clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
                    title: Text(g['tipo'] == 'surtido' ? 'Inversión/Resurtido' : (g['tipo'] == 'operativo' ? 'Gasto Operativo' : (g['tipo'] == 'devolucion' ? 'Devolución' : 'Merma')), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_dateFormat.format(DateTime.parse(g['fecha'])), style: const TextStyle(fontSize: 12)),
                    trailing: Text('- ${_currencyFormat.format(g['monto'])}', style: TextStyle(fontSize: AppSizes.bodyLarge, fontWeight: FontWeight.bold, color: color)),
                    children: [
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(AppSizes.paddingMedium), color: Colors.grey[50],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (g['tipo'] == 'merma') ...[Text('Producto: ${g['texto_busqueda']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)), Text('Descontado: ${g['cantidad']} unidades')],
                            if (g['tipo'] == 'surtido') ...[Text('Resurtido: ${g['texto_busqueda']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentBlue)), Text('Agregado: ${g['cantidad']} | Costo Un: ${_currencyFormat.format(g['costo_unitario'])}')],
                            if (g['tipo'] == 'operativo' || g['tipo'] == 'devolucion') Text('Categoría: ${g['texto_busqueda'].toString().toUpperCase()}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),

                            // ⭐ BOTÓN DE CANCELACIÓN (Solo visible si es del turno actual)
                            if (esDelTurnoActual) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.cancel, size: 18), label: const Text('CANCELAR REGISTRO'),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  onPressed: () => _procesarCancelacion(g, finanzas, turno.turnoActivo!.id!),
                                ),
                              )
                            ]
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ⭐ BOTÓN FLOTANTE INFERIOR PARA AGREGAR GASTO
        if (!_verPorMes)
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingLarge), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await showDialog(context: context, builder: (context) => GastoDialog(turnoId: turno.turnoActivo!.id!));
                  if (result == true) { await _seleccionarDiaActual(); }
                  FocusScope.of(context).requestFocus(_mainFocus);
                },
                icon: const Icon(Icons.add), label: const Text('AGREGAR GASTO MANUAL AL TURNO'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingLarge)),
              ),
            ),
          ),
      ],
    );
  }

  // ⭐ LÓGICA DEL BLINDAJE DE CANCELACIÓN
  Future<void> _procesarCancelacion(Map<String, dynamic> registro, FinanzasProvider finanzas, int turnoId) async {
    bool confirmar = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar Cancelación'),
          content: Text('¿Estás seguro de cancelar este ${registro['tipo']} de ${_currencyFormat.format(registro['monto'])}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('NO')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('SÍ, CANCELAR')),
          ],
        )
    ) ?? false;

    if (!confirmar) return;

    if (registro['tipo'] == 'surtido') {
      final errorInfo = await finanzas.cancelarSurtido(registro['id'], registro['producto_id'], registro['cantidad'], turnoId);
      if (errorInfo != null && mounted) {
        // Bloqueo exitoso: El stock ya bajó
        showDialog(context: context, builder: (ctx) => AlertDialog(title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width:8), Text('No se puede cancelar')]), content: Text(errorInfo), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ENTENDIDO'))]));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resurtido cancelado. Stock devuelto a la normalidad.'), backgroundColor: AppColors.success));
      }
    } else if (registro['tipo'] == 'operativo') {
      await finanzas.cancelarGastoOperativo(registro['id'], turnoId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gasto eliminado exitosamente.'), backgroundColor: AppColors.success));
    } else if (registro['tipo'] == 'merma') {
      await finanzas.cancelarMerma(registro['id'], registro['producto_id'], registro['cantidad'], turnoId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merma cancelada. Producto devuelto al inventario.'), backgroundColor: AppColors.success));
    }

    // Refrescar listas visuales
    await finanzas.cargarHistorialMixto(_fechaSeleccionada, _verPorMes);
  }
}

// ==================== WIDGET DE FILTROS AVANZADOS ====================
class _DialogoFiltrosGastos extends StatelessWidget {
  const _DialogoFiltrosGastos();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanzasProvider>();

    return AlertDialog(
      title: const Row(children: [Icon(Icons.filter_list, color: AppColors.financeBlue), SizedBox(width: 8), Text('Ordenar y Filtrar Movimientos')]),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tipo de Movimiento:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  ChoiceChip(label: const Text('Todos'), selected: provider.filtroTipoActual == 'todos', onSelected: (_) => provider.setFiltrosListaMixta(provider.searchQueryActual, 'todos', provider.ordenListaActual)),
                  ChoiceChip(label: const Text('Resurtidos'), selected: provider.filtroTipoActual == 'surtido', onSelected: (_) => provider.setFiltrosListaMixta(provider.searchQueryActual, 'surtido', provider.ordenListaActual)),
                  ChoiceChip(label: const Text('Gastos Operativos'), selected: provider.filtroTipoActual == 'operativo', onSelected: (_) => provider.setFiltrosListaMixta(provider.searchQueryActual, 'operativo', provider.ordenListaActual)),
                  ChoiceChip(label: const Text('Mermas'), selected: provider.filtroTipoActual == 'merma', onSelected: (_) => provider.setFiltrosListaMixta(provider.searchQueryActual, 'merma', provider.ordenListaActual)),
                ],
              ),
              const Divider(height: 32),
              const Text('Ordenar por:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  ChoiceChip(label: const Text('Más recientes'), selected: provider.ordenListaActual == 'fecha_desc', onSelected: (_) => provider.setFiltrosListaMixta(provider.searchQueryActual, provider.filtroTipoActual, 'fecha_desc')),
                  ChoiceChip(label: const Text('Más antiguos'), selected: provider.ordenListaActual == 'fecha_asc', onSelected: (_) => provider.setFiltrosListaMixta(provider.searchQueryActual, provider.filtroTipoActual, 'fecha_asc')),
                  ChoiceChip(label: const Text('Monto: Mayor a Menor'), selected: provider.ordenListaActual == 'monto_desc', onSelected: (_) => provider.setFiltrosListaMixta(provider.searchQueryActual, provider.filtroTipoActual, 'monto_desc')),
                  ChoiceChip(label: const Text('Monto: Menor a Mayor'), selected: provider.ordenListaActual == 'monto_asc', onSelected: (_) => provider.setFiltrosListaMixta(provider.searchQueryActual, provider.filtroTipoActual, 'monto_asc')),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeBlue, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text('CERRAR')),
      ],
    );
  }
}

// ==================== UTILIDADES EXISTENTES ====================
class _MonthPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  const _MonthPickerDialog({required this.initialDate});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int selectedYear;
  final List<String> meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  @override
  void initState() { super.initState(); selectedYear = widget.initialDate.year; }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => selectedYear--)),
          Text(selectedYear.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => selectedYear++)),
        ],
      ),
      content: SizedBox(
        width: 320, height: 240,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 1.0, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: 12,
          itemBuilder: (context, index) {
            bool isSelected = selectedYear == widget.initialDate.year && (index + 1) == widget.initialDate.month;
            return InkWell(
              onTap: () => Navigator.pop(context, DateTime(selectedYear, index + 1, 1)),
              child: Container(decoration: BoxDecoration(color: isSelected ? AppColors.primaryBlue : Colors.grey[200], borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Text(meses[index], style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
            );
          },
        ),
      ),
    );
  }
}

class _CorteDialog extends StatefulWidget {
  @override
  State<_CorteDialog> createState() => _CorteDialogState();
}

class _CorteDialogState extends State<_CorteDialog> {
  final TextEditingController _montoController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Corte de Caja', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ingresa el dinero físico en el cajón:'),
          const SizedBox(height: AppSizes.paddingMedium),
          TextField(controller: _montoController, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: '\$ ', hintText: '0.00', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), autofocus: true),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
        ElevatedButton(onPressed: () { final m = double.tryParse(_montoController.text); if (m != null && m >= 0) Navigator.pop(context, m); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white), child: const Text('CONFIRMAR CORTE')),
      ],
    );
  }
}