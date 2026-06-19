// lib/screens/metricas_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../providers/turno_provider.dart';
import '../database/database_helper.dart';

class MetricasScreen extends StatefulWidget {
  const MetricasScreen({super.key});

  @override
  State<MetricasScreen> createState() => _MetricasScreenState();
}

class _MetricasScreenState extends State<MetricasScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final NumberFormat _percentFormat = NumberFormat.percentPattern();
  
  Map<String, dynamic> _metricas = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarMetricas();
  }

  Future<void> _cargarMetricas() async {
    setState(() => _isLoading = true);
    
    final turnoProvider = context.read<TurnoProvider>();
    if (!turnoProvider.hayTurnoActivo) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final db = await DatabaseHelper().database;
      final turnoId = turnoProvider.turnoActivo!.id!;

      // Ventas del turno
      final ventas = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_ventas,
          SUM(total) as ingresos_totales,
          AVG(total) as ticket_promedio,
          SUM(CASE WHEN metodo_pago = 'efectivo' THEN total ELSE 0 END) as ventas_efectivo,
          SUM(CASE WHEN metodo_pago = 'tarjeta' THEN total ELSE 0 END) as ventas_tarjeta
        FROM ventas
        WHERE turno_id = ?
      ''', [turnoId]);

      // Productos más vendidos
      final topProductos = await db.rawQuery('''
        SELECT 
          p.nombre,
          SUM(vd.cantidad) as cantidad_vendida,
          SUM(vd.subtotal) as ingresos
        FROM venta_detalle vd
        JOIN productos p ON vd.producto_id = p.id
        JOIN ventas v ON vd.venta_id = v.id
        WHERE v.turno_id = ?
        GROUP BY p.id
        ORDER BY cantidad_vendida DESC
        LIMIT 5
      ''', [turnoId]);

      // Inventario
      final inventario = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_productos,
          SUM(stock) as unidades_totales,
          SUM(costo * stock) as valor_inventario,
          COUNT(CASE WHEN stock < stock_minimo THEN 1 END) as productos_bajo_stock
        FROM productos
      ''');

      // Gastos
      final gastos = await db.rawQuery('''
        SELECT SUM(monto) as total_gastos
        FROM gastos_operativos
        WHERE turno_id = ?
      ''', [turnoId]);

      final surtidos = await db.rawQuery('''
        SELECT SUM(costo_total) as total_surtidos
        FROM surtidos
        WHERE turno_id = ?
      ''', [turnoId]);

      final mermas = await db.rawQuery('''
        SELECT SUM(valor_perdido) as total_mermas
        FROM mermas
        WHERE turno_id = ?
      ''', [turnoId]);

      setState(() {
        _metricas = {
          'ventas': ventas.first,
          'topProductos': topProductos,
          'inventario': inventario.first,
          'gastos': gastos.first,
          'surtidos': surtidos.first,
          'mermas': mermas.first,
        };
      });
    } catch (e) {
      debugPrint('Error al cargar métricas: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final turnoProvider = context.watch<TurnoProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primaryBlue,
        title: const Text(
          'Métricas del Negocio',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarMetricas,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: !turnoProvider.hayTurnoActivo
          ? const Center(
              child: Text(
                'No hay turno activo',
                style: TextStyle(fontSize: AppSizes.titleMedium),
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _cargarMetricas,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSizes.paddingLarge),
                    children: [
                      _buildVentasSection(),
                      const SizedBox(height: AppSizes.paddingLarge),
                      _buildTopProductosSection(),
                      const SizedBox(height: AppSizes.paddingLarge),
                      _buildInventarioSection(),
                      const SizedBox(height: AppSizes.paddingLarge),
                      _buildGastosSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildVentasSection() {
    final ventas = _metricas['ventas'] as Map<String, dynamic>? ?? {};
    final totalVentas = (ventas['total_ventas'] as num?)?.toInt() ?? 0;
    final ingresosTotales = (ventas['ingresos_totales'] as num?)?.toDouble() ?? 0.0;
    final ticketPromedio = (ventas['ticket_promedio'] as num?)?.toDouble() ?? 0.0;
    final ventasEfectivo = (ventas['ventas_efectivo'] as num?)?.toDouble() ?? 0.0;
    final ventasTarjeta = (ventas['ventas_tarjeta'] as num?)?.toDouble() ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingSmall),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                  child: const Icon(Icons.trending_up, color: AppColors.success, size: 32),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                const Text(
                  'Ventas del Turno',
                  style: TextStyle(
                    fontSize: AppSizes.titleMedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingLarge),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Ventas',
                    totalVentas.toString(),
                    Icons.receipt_long,
                    AppColors.accentBlue,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                Expanded(
                  child: _buildMetricCard(
                    'Ingresos',
                    _currencyFormat.format(ingresosTotales),
                    Icons.attach_money,
                    AppColors.success,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSizes.paddingMedium),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Ticket Promedio',
                    _currencyFormat.format(ticketPromedio),
                    Icons.shopping_cart,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                Expanded(
                  child: Column(
                    children: [
                      _buildSmallMetric('Efectivo', ventasEfectivo, AppColors.success),
                      const SizedBox(height: 4),
                      _buildSmallMetric('Tarjeta', ventasTarjeta, AppColors.accentBlue),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductosSection() {
    final topProductos = _metricas['topProductos'] as List<Map<String, dynamic>>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingSmall),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                  child: const Icon(Icons.star, color: Colors.orange, size: 32),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                const Text(
                  'Productos Más Vendidos',
                  style: TextStyle(
                    fontSize: AppSizes.titleMedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingMedium),
            
            if (topProductos.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.paddingLarge),
                  child: Text('No hay ventas registradas'),
                ),
              )
            else
              ...topProductos.asMap().entries.map((entry) {
                final index = entry.key;
                final producto = entry.value;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getColorForRank(index),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(producto['nombre'] as String),
                  subtitle: Text(
                    '${(producto['cantidad_vendida'] as num).toDouble().toStringAsFixed(2)} unidades',
                  ),
                  trailing: Text(
                    _currencyFormat.format((producto['ingresos'] as num).toDouble()),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.bodyLarge,
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInventarioSection() {
    final inventario = _metricas['inventario'] as Map<String, dynamic>? ?? {};
    final totalProductos = (inventario['total_productos'] as num?)?.toInt() ?? 0;
    final unidadesTotales = (inventario['unidades_totales'] as num?)?.toDouble() ?? 0.0;
    final valorInventario = (inventario['valor_inventario'] as num?)?.toDouble() ?? 0.0;
    final productosBajoStock = (inventario['productos_bajo_stock'] as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingSmall),
                  decoration: BoxDecoration(
                    color: AppColors.inventoryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                  child: const Icon(Icons.inventory, color: AppColors.inventoryOrange, size: 32),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                const Text(
                  'Estado del Inventario',
                  style: TextStyle(
                    fontSize: AppSizes.titleMedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingLarge),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Productos',
                    totalProductos.toString(),
                    Icons.category,
                    AppColors.inventoryOrange,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                Expanded(
                  child: _buildMetricCard(
                    'Unidades',
                    unidadesTotales.toStringAsFixed(2),
                    Icons.inventory_2,
                    AppColors.accentBlue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSizes.paddingMedium),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Valor Total',
                    _currencyFormat.format(valorInventario),
                    Icons.attach_money,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                Expanded(
                  child: _buildMetricCard(
                    'Stock Bajo',
                    productosBajoStock.toString(),
                    Icons.warning,
                    productosBajoStock > 0 ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGastosSection() {
    final gastos = (_metricas['gastos'] as Map<String, dynamic>?)?['total_gastos'] as num? ?? 0;
    final surtidos = (_metricas['surtidos'] as Map<String, dynamic>?)?['total_surtidos'] as num? ?? 0;
    final mermas = (_metricas['mermas'] as Map<String, dynamic>?)?['total_mermas'] as num? ?? 0;
    final totalGastos = gastos.toDouble() + surtidos.toDouble() + mermas.toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingSmall),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: AppColors.error, size: 32),
                ),
                const SizedBox(width: AppSizes.paddingMedium),
                const Text(
                  'Gastos del Turno',
                  style: TextStyle(
                    fontSize: AppSizes.titleMedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingLarge),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Gastos',
                    _currencyFormat.format(totalGastos),
                    Icons.receipt,
                    AppColors.error,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSizes.paddingMedium),
            
            _buildSmallMetric('Operativos', gastos.toDouble(), AppColors.financeRed),
            const SizedBox(height: 4),
            _buildSmallMetric('Surtidos', surtidos.toDouble(), AppColors.accentBlue),
            const SizedBox(height: 4),
            _buildSmallMetric('Mermas', mermas.toDouble(), Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSizes.paddingSmall),
          Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.bodySmall,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppSizes.titleSmall,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetric(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingMedium,
        vertical: AppSizes.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: AppSizes.bodyMedium),
          ),
          Text(
            _currencyFormat.format(value),
            style: TextStyle(
              fontSize: AppSizes.bodyMedium,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForRank(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey[400]!;
      case 2:
        return Colors.brown[300]!;
      default:
        return AppColors.primaryBlue;
    }
  }
}