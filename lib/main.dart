// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'constants/app_constants.dart';
import 'providers/turno_provider.dart';
import 'providers/inventario_provider.dart';
import 'providers/venta_provider.dart';
import 'providers/finanzas_provider.dart';
import 'providers/config_provider.dart';
import 'providers/prestamos_provider.dart';

import 'screens/home_screen.dart'; // ⭐ NUEVA PANTALLA
import 'screens/venta_screen.dart';
import 'screens/inventario_screen.dart';
import 'screens/resurtir_screen.dart';
import 'screens/finanzas_screen.dart';
import 'screens/prestamos_screen.dart';
import 'screens/metricas_screen.dart';
import 'screens/historial_screen.dart';

// ⭐ GLOBAL KEYS PARA FOCO AUTOMÁTICO
final GlobalKey<State<VentaScreen>> ventaScreenKey = GlobalKey();
final GlobalKey<State<ResurtirScreen>> resurtirScreenKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TurnoProvider()),
        ChangeNotifierProvider(create: (_) => InventarioProvider()),
        ChangeNotifierProvider(create: (_) => VentaProvider()),
        ChangeNotifierProvider(create: (_) => FinanzasProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => PrestamosProvider()),
      ],
      child: MaterialApp(
        title: 'POS Tablet',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Roboto',
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  final FocusNode _mainKeyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this); // ⭐ AHORA SON 8 PESTAÑAS
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _cambiarPestana(_tabController.index);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TurnoProvider>().cargarTurnoActivo();
      _mainKeyFocus.requestFocus();
    });
  }

  void _navegarAPestana(int index) {
    _tabController.animateTo(index);
    _cambiarPestana(index);
  }

  void _cambiarPestana(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) { // 1 es Ventas
      context.read<VentaProvider>().cargarProductos();
      // ⭐ PONER FOCO AUTOMÁTICO EN BÚSQUEDA DE VENTA
      Future.delayed(const Duration(milliseconds: 50), () {
        (ventaScreenKey.currentState as dynamic)?.ponerFocoEnBusqueda();
      });
    } else if (index == 2 || index == 3) { // 2 es Inventario, 3 es Resurtir
      context.read<InventarioProvider>().cargarProductos();
      // ⭐ PONER FOCO AUTOMÁTICO EN RESURTIR
      if (index == 3) {
        Future.delayed(const Duration(milliseconds: 50), () {
          (resurtirScreenKey.currentState as dynamic)?.ponerFocoEnBusqueda();
        });
      }
    } else if (index == 4) { // 4 es Finanzas
      final turnoId = context.read<TurnoProvider>().turnoActivo?.id;
      if (turnoId != null) context.read<FinanzasProvider>().cargarBalance(turnoId);
    } else if (index == 5) { // 5 es Préstamos
      context.read<PrestamosProvider>().cargarDatos();
    }
  }

  void _handleGlobalKeys(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;
    final key = event.logicalKey;
    // F1 ahora es Inicio, F2 es Ventas...
    if (key == LogicalKeyboardKey.f1) _navegarAPestana(0);
    else if (key == LogicalKeyboardKey.f2) _navegarAPestana(1);
    else if (key == LogicalKeyboardKey.f3) _navegarAPestana(2);
    else if (key == LogicalKeyboardKey.f4) _navegarAPestana(3);
    else if (key == LogicalKeyboardKey.f5) _navegarAPestana(4);
    else if (key == LogicalKeyboardKey.f6) _navegarAPestana(5);
    else if (key == LogicalKeyboardKey.f7) _navegarAPestana(6);
    else if (key == LogicalKeyboardKey.f8) _navegarAPestana(7);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mainKeyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final turnoActivo = context.watch<TurnoProvider>().hayTurnoActivo;

    return RawKeyboardListener(
      focusNode: _mainKeyFocus,
      onKey: _handleGlobalKeys,
      autofocus: true,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                // ⭐ EL CANDADO: Si no hay turno y quiere entrar a Ventas(1), Resurtir(3) o Préstamos(5)
                if (!turnoActivo && (index == 1 || index == 3 || index == 5)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔒 CAJA CERRADA: Abre un turno primero para realizar esta acción.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return; // Bloquea la navegación
                }
                _navegarAPestana(index);
              },
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: AppColors.primaryBlue, size: 30),
              unselectedIconTheme: IconThemeData(color: Colors.grey.shade500, size: 24),
              selectedLabelTextStyle: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              backgroundColor: Colors.white,
              elevation: 4,
              destinations: [
                const NavigationRailDestination(icon: Icon(Icons.home), label: Text('Inicio')),
                NavigationRailDestination(icon: Icon(Icons.point_of_sale, color: turnoActivo ? null : Colors.grey.shade300), label: Text('Ventas', style: TextStyle(color: turnoActivo ? null : Colors.grey.shade400))),
                const NavigationRailDestination(icon: Icon(Icons.inventory), label: Text('Inventario')),
                NavigationRailDestination(icon: Icon(Icons.local_shipping, color: turnoActivo ? Colors.orange : Colors.grey.shade300), label: Text('Resurtir', style: TextStyle(color: turnoActivo ? null : Colors.grey.shade400))),
                const NavigationRailDestination(icon: Icon(Icons.attach_money), label: Text('Finanzas')),
                NavigationRailDestination(icon: Icon(Icons.handshake, color: turnoActivo ? null : Colors.grey.shade300), label: Text('Préstamos', style: TextStyle(color: turnoActivo ? null : Colors.grey.shade400))),
                const NavigationRailDestination(icon: Icon(Icons.analytics), label: Text('Métricas')),
                const NavigationRailDestination(icon: Icon(Icons.history), label: Text('Historial')),
              ],
            ),

            const VerticalDivider(thickness: 1, width: 1, color: Colors.black12),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  HomeScreen(onNavigate: _navegarAPestana), // 0
                  VentaScreen(key: ventaScreenKey),         // 1
                  const InventarioScreen(),                 // 2
                  ResurtirScreen(key: resurtirScreenKey),   // 3
                  const FinanzasScreen(),                   // 4
                  const PrestamosScreen(),                  // 5
                  const MetricasScreen(),                   // 6
                  const HistorialScreen(),                  // 7
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}