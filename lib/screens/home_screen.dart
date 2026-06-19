// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Para el reloj en tiempo real
import '../constants/app_constants.dart';
import '../providers/turno_provider.dart';
// import '../widgets/menu_lateral.dart'; // No lo usamos porque main.dart tiene NavigationRail
import '../widgets/apertura_caja_dialog.dart'; // Tu diálogo original reciclado

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate; // Función para cambiar de pestaña en main.dart

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Variables para el reloj
  String _timeString = "";
  String _dateString = "";
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Iniciar el reloj inmediatamente y actualizar cada segundo
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());

    // Cargar el estado del turno al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TurnoProvider>().cargarTurnoActivo();
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Detener el reloj al salir
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    setState(() {
      _timeString = DateFormat('hh:mm:ss a').format(now); // 02:30:15 PM
      _dateString = DateFormat('EEEE, d \'de\' MMMM \'del\' yyyy', 'es').format(now); // lunes, 5 de mayo...
    });
  }

  // Lógica para abrir turno usando tu diálogo original
  void _abrirTurno() async {
    final montoInicial = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AperturaCajaDialog(),
    );

    if (montoInicial != null && mounted) {
      final exito = await context.read<TurnoProvider>().abrirCaja(montoInicial);
      if (exito) {
        widget.onNavigate(1); // Manda al usuario directo a la pestaña Ventas (F2)
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final turnoProvider = context.watch<TurnoProvider>();
    final isOpened = turnoProvider.hayTurnoActivo;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Usamos Stack para poner la imagen de fondo y la UI encima
      body: Stack(
        children: [
          // 1. Imagen de Fondo
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/paisaje.jpg'), // Tu imagen en assets
                fit: BoxFit.cover, // Cubrir toda la pantalla
              ),
            ),
          ),

          // 2. Capa oscura semitransparente (Overlay) para legibilidad (un poco más oscura para el texto blanco)
          Container(
            color: Colors.black.withValues(alpha: 0.6), // 60% de oscuridad
          ),

          // 3. Contenido de la Interfaz
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.paddingLarge * 2),
              child: Column(
                children: [
                  // Encabezado con Reloj y Estado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reloj y Fecha
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_timeString, style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          Text(_dateString.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w300, letterSpacing: 1)),
                        ],
                      ),

                      // Indicador de Estado
                      _buildStatusBadge(isOpened),
                    ],
                  ),

                  const Spacer(), // Empuja el panel central al medio

                  // Panel Central Dinámico
                  // ⭐ NUEVO DISEÑO FUSIONADO: Quitamos el fondo blanco y las sombras
                  Container(
                    width: 700,
                    padding: const EdgeInsets.all(AppSizes.paddingLarge * 2),
                    // decoration: BoxDecoration( ... borrado ... ),
                    child: isOpened
                        ? _buildTurnoAbiertoPanel(turnoProvider)
                        : _buildTurnoCerradoPanel(),
                  ),

                  const Spacer(), // Empuja el panel central al medio

                  // Pie de página sutil
                  const Text('POS Tablet v7 - Sistema ERP Profesional de Confianza', style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isOpened) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isOpened ? AppColors.success : AppColors.error,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Row(
        children: [
          Icon(isOpened ? Icons.lock_open : Icons.lock, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            isOpened ? 'TURNO ACTIVO' : 'CAJA CERRADA',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnoCerradoPanel() {
    return Column(
      children: [
        const Icon(Icons.storefront, size: 80, color: Colors.white70), // Icono más claro
        const SizedBox(height: 24),
        const Text(
          '¡Bienvenido al Sistema!',
          // ⭐ Texto Principal ahora es blanco
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'Para empezar a vender, cobrar o surtir inventario,\nnecesitas abrir un nuevo turno de trabajo.',
          textAlign: TextAlign.center,
          // ⭐ Texto Secundario ahora es blanco70
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: _abrirTurno, // Llama a la función que abre tu diálogo viejo
            icon: const Icon(Icons.key, size: 28),
            label: const Text('ABRIR NUEVO TURNO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTurnoAbiertoPanel(TurnoProvider provider) {
    final DateTime apertura = provider.turnoActivo!.fechaApertura;
    final String horaApertura = DateFormat('hh:mm a').format(apertura);
    final NumberFormat currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Column(
      children: [
        const Icon(Icons.check_circle_outline, size: 80, color: AppColors.success),
        const SizedBox(height: 24),
        Text(
          'Turno Abierto a las $horaApertura',
          // ⭐ Texto Principal en verde success destaca bien
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.success),
        ),
        const SizedBox(height: 8),
        Text(
          'Fondo Inicial declarado: ${currency.format(provider.turnoActivo!.montoInicial)}',
          // ⭐ Texto Secundario ahora es blanco70
          style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () => widget.onNavigate(1), // Manda a la pestaña Ventas (F2)
                  icon: const Icon(Icons.point_of_sale, size: 28),
                  label: const Text('IR A LA CAJA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: SizedBox(
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: () => widget.onNavigate(4), // Manda a la pestaña Finanzas (F5)
                  icon: const Icon(Icons.cut, size: 28),
                  label: const Text('HACER CORTE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    // ⭐ Borde rojo destaca bien sobre oscuro
                    side: const BorderSide(color: AppColors.error, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}