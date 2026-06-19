// lib/screens/historial_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../database/database_helper.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');
  
  DateTime? _fechaSeleccionada;
  String? _mesSeleccionado; // Formato: "2026-02"
  List<Map<String, dynamic>> _turnos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fechaSeleccionada = DateTime.now();
    _mesSeleccionado = DateFormat('yyyy-MM').format(DateTime.now());
    _cargarTurnos();
  }

  Future<void> _cargarTurnos() async {
    setState(() => _isLoading = true);
    
    try {
      final db = await DatabaseHelper().database;
      
      if (_tabController.index == 0) {
        // Vista por DÍA
        final fecha = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada!);
        _turnos = await db.rawQuery('''
          SELECT * FROM turnos
          WHERE DATE(fecha_apertura) = ?
          ORDER BY fecha_apertura DESC
        ''', [fecha]);
      } else {
        // Vista por MES
        _turnos = await db.rawQuery('''
          SELECT * FROM turnos
          WHERE strftime('%Y-%m', fecha_apertura) = ?
          ORDER BY fecha_apertura DESC
        ''', [_mesSeleccionado]);
      }
      
      setState(() {});
    } catch (e) {
      debugPrint('Error al cargar turnos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (fecha != null) {
      setState(() => _fechaSeleccionada = fecha);
      _cargarTurnos();
    }
  }

  Future<void> _seleccionarMes() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    
    if (fecha != null) {
      setState(() => _mesSeleccionado = DateFormat('yyyy-MM').format(fecha));
      _cargarTurnos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.financeBlue,
        title: const Text(
          'Historial',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarTurnos,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: (_) => _cargarTurnos(),
          tabs: const [
            Tab(text: 'POR DÍA'),
            Tab(text: 'POR MES'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Selector de fecha/mes
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingMedium),
            color: Colors.white,
            child: _tabController.index == 0
                ? ElevatedButton.icon(
                    onPressed: _seleccionarFecha,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_dateFormat.format(_fechaSeleccionada!)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _seleccionarMes,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(DateFormat('MMMM yyyy').format(DateTime.parse('$_mesSeleccionado-01'))), // sin 'es'
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
          ),

          // Lista de turnos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _turnos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _tabController.index == 0
                                  ? 'No hay turnos en esta fecha'
                                  : 'No hay turnos en este mes',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSizes.paddingMedium),
                        itemCount: _turnos.length,
                        itemBuilder: (context, index) {
                          final turno = _turnos[index];
                          return _TurnoCard(
                            turno: turno,
                            currencyFormat: _currencyFormat,
                            dateFormat: _dateFormat,
                            timeFormat: _timeFormat,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _TurnoCard extends StatefulWidget {
  final Map<String, dynamic> turno;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final DateFormat timeFormat;

  const _TurnoCard({
    required this.turno,
    required this.currencyFormat,
    required this.dateFormat,
    required this.timeFormat,
  });

  @override
  State<_TurnoCard> createState() => _TurnoCardState();
}

class _TurnoCardState extends State<_TurnoCard> {
  bool _expandido = false;
  Map<String, dynamic>? _datos;
  bool _cargando = false;

  Future<void> _cargarDatos() async {
    if (_datos != null) return;
    
    setState(() => _cargando = true);
    
    try {
      final db = await DatabaseHelper().database;
      final turnoId = widget.turno['id'] as int;

      // Ventas
      final ventas = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_ventas,
          COALESCE(SUM(total), 0) as ingresos,
          COALESCE(SUM(CASE WHEN metodo_pago = 'efectivo' THEN total ELSE 0 END), 0) as efectivo,
          COALESCE(SUM(CASE WHEN metodo_pago = 'tarjeta' THEN total ELSE 0 END), 0) as tarjeta
        FROM ventas WHERE turno_id = ?
      ''', [turnoId]);

      // Gastos
      final gastos = await db.rawQuery('''
        SELECT COALESCE(SUM(monto), 0) as total
        FROM gastos_operativos
        WHERE turno_id = ? AND monto > 0
      ''', [turnoId]);

      // Surtidos
      final surtidos = await db.rawQuery('''
        SELECT COALESCE(SUM(costo_total), 0) as total
        FROM surtidos WHERE turno_id = ?
      ''', [turnoId]);

      // Mermas
      final mermas = await db.rawQuery('''
        SELECT COALESCE(SUM(valor_perdido), 0) as total
        FROM mermas WHERE turno_id = ?
      ''', [turnoId]);

      // Inversión inicial
      final inversion = await db.rawQuery('''
        SELECT COALESCE(SUM(p.costo * p.stock), 0) as total
        FROM productos p
        WHERE p.fecha_creacion >= (SELECT fecha_apertura FROM turnos WHERE id = ?)
        AND p.fecha_creacion < COALESCE((SELECT fecha_cierre FROM turnos WHERE id = ?), datetime('now'))
        AND NOT EXISTS (SELECT 1 FROM surtidos s WHERE s.producto_id = p.id)
      ''', [turnoId, turnoId]);

      setState(() {
        _datos = {
          'ventas': ventas.first,
          'gastos': (gastos.first['total'] as num).toDouble(),
          'surtidos': (surtidos.first['total'] as num).toDouble(),
          'mermas': (mermas.first['total'] as num).toDouble(),
          'inversion': (inversion.first['total'] as num).toDouble(),
        };
      });
    } catch (e) {
      debugPrint('Error al cargar datos del turno: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activo = (widget.turno['activo'] as int) == 1;
    final fechaApertura = DateTime.parse(widget.turno['fecha_apertura'] as String);
    final fechaCierre = widget.turno['fecha_cierre'] != null
        ? DateTime.parse(widget.turno['fecha_cierre'] as String)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingMedium),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: activo ? AppColors.success.withOpacity(0.2) : AppColors.financeBlue.withOpacity(0.2),
              child: Icon(
                activo ? Icons.lock_open : Icons.lock,
                color: activo ? AppColors.success : AppColors.financeBlue,
              ),
            ),
            title: Text(
              'Turno #${widget.turno['id']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Apertura: ${widget.dateFormat.format(fechaApertura)} ${widget.timeFormat.format(fechaApertura)}\n'
              '${activo ? "ACTIVO" : "Cierre: ${widget.dateFormat.format(fechaCierre!)} ${widget.timeFormat.format(fechaCierre)}"}',
            ),
            trailing: IconButton(
              icon: Icon(_expandido ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() => _expandido = !_expandido);
                if (_expandido) _cargarDatos();
              },
            ),
          ),

          if (_expandido) ...[
            const Divider(height: 1),
            
            if (_cargando)
              const Padding(
                padding: EdgeInsets.all(AppSizes.paddingLarge),
                child: CircularProgressIndicator(),
              )
            else if (_datos != null) ...[
              Padding(
                padding: const EdgeInsets.all(AppSizes.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ventas
                    const Text(
                      'VENTAS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildRow('Total ventas:', '${_datos!['ventas']['total_ventas']}'),
                    _buildRow('Ingresos:', widget.currencyFormat.format(_datos!['ventas']['ingresos'])),
                    _buildRow('Efectivo:', widget.currencyFormat.format(_datos!['ventas']['efectivo'])),
                    _buildRow('Tarjeta:', widget.currencyFormat.format(_datos!['ventas']['tarjeta'])),
                    
                    const Divider(height: 24),
                    
                    // Gastos
                    const Text(
                      'GASTOS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildRow('Inversión inicial:', widget.currencyFormat.format(_datos!['inversion'])),
                    _buildRow('Reabastecimiento:', widget.currencyFormat.format(_datos!['surtidos'])),
                    _buildRow('Operativos:', widget.currencyFormat.format(_datos!['gastos'])),
                    _buildRow('Mermas:', widget.currencyFormat.format(_datos!['mermas'])),
                    
                    const Divider(height: 24),
                    
                    // Balance
                    const Text(
                      'BALANCE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.financeBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final cajaInicial = (widget.turno['monto_inicial'] as num).toDouble();
                        final ingresos = (_datos!['ventas']['ingresos'] as num).toDouble();
                        final totalGastos = _datos!['inversion'] + _datos!['surtidos'] + _datos!['gastos'] + _datos!['mermas'];
                        final balance = cajaInicial + ingresos - totalGastos;
                        
                        return Column(
                          children: [
                            _buildRow('Caja inicial:', widget.currencyFormat.format(cajaInicial)),
                            _buildRow('+ Ingresos:', widget.currencyFormat.format(ingresos), color: AppColors.success),
                            _buildRow('- Gastos totales:', widget.currencyFormat.format(totalGastos), color: AppColors.error),
                            const Divider(height: 16),
                            _buildRow(
                              'TOTAL:',
                              widget.currencyFormat.format(balance),
                              bold: true,
                              color: balance >= 0 ? AppColors.success : AppColors.error,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}