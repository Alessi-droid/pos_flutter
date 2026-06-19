// lib/screens/merma_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../providers/turno_provider.dart';
import '../providers/finanzas_provider.dart'; // ⭐ NUEVO IMPORT
import '../database/database_helper.dart';
import '../models/producto.dart';

class ItemMerma {
  final Producto producto;
  double cantidad;

  ItemMerma({
    required this.producto,
    this.cantidad = 1.0,
  });

  double get valorPerdido => producto.costo * cantidad;
}

class MermaScreen extends StatefulWidget {
  const MermaScreen({super.key});

  @override
  State<MermaScreen> createState() => _MermaScreenState();
}

class _MermaScreenState extends State<MermaScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  final List<ItemMerma> _items = [];
  List<Producto> _todosProductos = [];
  List<Producto> _sugerencias = [];
  bool _mostrarSugerencias = false;
  int _selectedSuggestionIndex = -1;
  bool _isLoading = false;

  double get totalPerdido => _items.fold(0.0, (sum, item) => sum + item.valorPerdido);
  bool get listaVacia => _items.isEmpty;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _searchController.addListener(_onSearchChanged);

    // ⭐ CARGAMOS EL CATÁLOGO AL ABRIR LA PANTALLA
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanzasProvider>().cargarCatalogoCategorias();
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      _searchFocus.requestFocus();
    });
  }

  Future<void> _cargarProductos() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        orderBy: 'nombre ASC',
      );
      _todosProductos = maps.map((map) => Producto.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error al cargar productos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;

    if (query.isEmpty) {
      setState(() {
        _sugerencias = [];
        _mostrarSugerencias = false;
        _selectedSuggestionIndex = -1;
      });
    } else {
      final queryLower = query.toLowerCase();
      final resultados = _todosProductos.where((p) {
        return p.codigo.toLowerCase().contains(queryLower) ||
            p.nombre.toLowerCase().contains(queryLower);
      }).take(10).toList();

      setState(() {
        _sugerencias = resultados;
        _mostrarSugerencias = resultados.isNotEmpty;
        _selectedSuggestionIndex = resultados.isNotEmpty ? 0 : -1;
      });
    }
  }

  void _agregarProducto(Producto producto) {
    setState(() {
      _mostrarSugerencias = false;
      _searchController.clear();
      _selectedSuggestionIndex = -1;
    });

    final cantidadInicial = producto.aGranel ? 0.1 : 1.0;

    final index = _items.indexWhere((item) => item.producto.id == producto.id);
    if (index >= 0) {
      setState(() {
        _items[index].cantidad += cantidadInicial;
      });
    } else {
      setState(() {
        _items.add(ItemMerma(
          producto: producto,
          cantidad: cantidadInicial,
        ));
      });
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      _searchFocus.requestFocus();
    });
  }

  void _eliminarItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _editarCantidad(int index) async {
    final item = _items[index];
    final controller = TextEditingController(
        text: item.producto.aGranel
            ? item.cantidad.toStringAsFixed(2)
            : item.cantidad.toInt().toString()
    );

    final nuevaCantidad = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.producto.nombre),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: item.producto.aGranel),
          inputFormatters: item.producto.aGranel
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))]
              : [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Cantidad',
            suffix: Text(item.producto.aGranel ? 'kg' : 'pz'),
          ),
          onSubmitted: (value) {
            final cant = double.tryParse(value);
            if (cant != null && cant > 0) {
              Navigator.of(context).pop(cant);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              final cant = double.tryParse(controller.text);
              if (cant != null && cant > 0) {
                Navigator.of(context).pop(cant);
              }
            },
            child: const Text('ACEPTAR'),
          ),
        ],
      ),
    );

    if (nuevaCantidad != null && nuevaCantidad > 0) {
      setState(() {
        _items[index].cantidad = nuevaCantidad;
      });
    }
    _searchFocus.requestFocus();
  }

  Future<void> _registrarMermas() async {
    if (_items.isEmpty) return;

    final turnoProvider = context.read<TurnoProvider>();
    if (!turnoProvider.hayTurnoActivo) {
      _mostrarError('No hay turno activo');
      return;
    }

    // Pedir motivo con el nuevo menú estricto
    final motivo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MotivoDialog(),
    );

    if (motivo == null || motivo.trim().isEmpty) {
      _searchFocus.requestFocus();
      return;
    }

    try {
      final db = await DatabaseHelper().database;

      await db.transaction((txn) async {
        for (var item in _items) {
          await txn.insert('mermas', {
            'turno_id': turnoProvider.turnoActivo!.id,
            'producto_id': item.producto.id,
            'cantidad': item.cantidad,
            'motivo': motivo,
            'valor_perdido': item.valorPerdido,
            'fecha': DateTime.now().toIso8601String(),
          });

          await txn.rawUpdate(
            'UPDATE productos SET stock = stock - ? WHERE id = ?',
            [item.cantidad, item.producto.id],
          );
        }
      });

      if (mounted) {
        _mostrarExito('Mermas registradas: ${_items.length} productos');
        setState(() {
          _items.clear();
        });
        await _cargarProductos();
        _searchFocus.requestFocus();
      }
    } catch (e) {
      _mostrarError('Error al registrar mermas: $e');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.error),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.success),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.orange,
        title: const Text(
          'Registro de Mermas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services, color: Colors.white),
            onPressed: () {
              setState(() => _items.clear());
              _searchFocus.requestFocus();
            },
            tooltip: 'Limpiar lista',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Cerrar',
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              setState(() {
                _mostrarSugerencias = false;
                _selectedSuggestionIndex = -1;
              });
              _searchController.clear();
              _searchFocus.requestFocus();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && _mostrarSugerencias) {
              setState(() {
                if (_selectedSuggestionIndex < _sugerencias.length - 1) {
                  _selectedSuggestionIndex++;
                }
              });
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && _mostrarSugerencias) {
              setState(() {
                if (_selectedSuggestionIndex > 0) {
                  _selectedSuggestionIndex--;
                }
              });
            } else if (event.logicalKey == LogicalKeyboardKey.enter && _mostrarSugerencias) {
              if (_selectedSuggestionIndex >= 0 && _selectedSuggestionIndex < _sugerencias.length) {
                _agregarProducto(_sugerencias[_selectedSuggestionIndex]);
              }
            }
          }
        },
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSizes.paddingMedium),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: 'Escanear o buscar producto...',
                  hintStyle: const TextStyle(
                    fontSize: AppSizes.titleSmall,
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon: const Icon(Icons.search, size: AppSizes.iconMedium),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _mostrarSugerencias = false);
                      _searchFocus.requestFocus();
                    },
                  )
                      : null,
                ),
                style: const TextStyle(fontSize: AppSizes.bodyLarge),
              ),
            ),
            if (_mostrarSugerencias) _buildSugerencias(),
            Expanded(child: _buildLista()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSugerencias() {
    return Container(
      color: Colors.white,
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _sugerencias.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final producto = _sugerencias[index];
          final isSelected = index == _selectedSuggestionIndex;

          return ListTile(
            tileColor: isSelected ? Colors.orange.withOpacity(0.1) : null,
            leading: Icon(
              Icons.inventory_2,
              color: isSelected ? Colors.orange : Colors.grey,
            ),
            title: Text(
              producto.nombreConUnidad,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text('Stock: ${producto.stock.toStringAsFixed(2)} ${producto.aGranel ? 'kg' : 'pz'}'),
            trailing: Text(
              _currencyFormat.format(producto.costo),
              style: const TextStyle(fontSize: AppSizes.bodyMedium),
            ),
            onTap: () => _agregarProducto(producto),
          );
        },
      ),
    );
  }

  Widget _buildLista() {
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'Escanea productos para registrar mermas',
          style: TextStyle(
            fontSize: AppSizes.titleMedium,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingMedium,
              vertical: AppSizes.paddingSmall,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              border: const Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 4, child: Text('PRODUCTO', style: AppTextStyles.tableHeader)),
                const Expanded(flex: 2, child: Text('CANT', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
                const Expanded(flex: 2, child: Text('COSTO', style: AppTextStyles.tableHeader, textAlign: TextAlign.right)),
                const Expanded(flex: 2, child: Text('PÉRDIDA', style: AppTextStyles.tableHeader, textAlign: TextAlign.right)),
                Container(width: 50),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                final isEven = index % 2 == 0;

                return Container(
                  color: isEven ? Colors.orange[50] : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingMedium,
                    vertical: AppSizes.paddingSmall,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          item.producto.nombreConUnidad,
                          style: const TextStyle(fontSize: AppSizes.bodyMedium),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => _editarCantidad(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.producto.aGranel
                                  ? item.cantidad.toStringAsFixed(2)
                                  : item.cantidad.toInt().toString(),
                              style: const TextStyle(
                                fontSize: AppSizes.bodyMedium,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currencyFormat.format(item.producto.costo),
                          style: const TextStyle(fontSize: AppSizes.bodyMedium),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currencyFormat.format(item.valorPerdido),
                          style: const TextStyle(
                            fontSize: AppSizes.bodyMedium,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.error),
                          onPressed: () => _eliminarItem(index),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PÉRDIDA TOTAL',
                  style: TextStyle(
                    fontSize: AppSizes.bodyLarge,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  _currencyFormat.format(totalPerdido),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width: 250,
            child: ElevatedButton.icon(
              onPressed: listaVacia ? null : _registrarMermas,
              icon: const Icon(Icons.save, size: AppSizes.iconMedium),
              label: const Text('REGISTRAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingLarge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EL NUEVO DIÁLOGO DE MOTIVO (ESTRICTO CON CATÁLOGO)
// ============================================================================
class _MotivoDialog extends StatefulWidget {
  @override
  State<_MotivoDialog> createState() => _MotivoDialogState();
}

class _MotivoDialogState extends State<_MotivoDialog> {
  String? _motivoSeleccionado;

  void _abrirGestorCategorias() {
    showDialog(
      context: context,
      builder: (context) => const _GestorCategoriasDialog(tipo: 'merma'),
    ).then((_) {
      final finanzas = context.read<FinanzasProvider>();
      setState(() {
        if (_motivoSeleccionado != null && !finanzas.categoriasMerma.any((c) => c['nombre'] == _motivoSeleccionado)) {
          _motivoSeleccionado = null;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<FinanzasProvider>();

    return AlertDialog(
      title: const Text('Motivo de la Merma'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Selecciona por qué estás dando de baja estos productos:', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Motivo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_motivoSeleccionado != null) {
              Navigator.of(context).pop(_motivoSeleccionado);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('CONFIRMAR'),
        ),
      ],
    );
  }
}

// ============================================================================
// EL SUB-DIÁLOGO: ADMINISTRADOR DE CATEGORÍAS (Para administrar sin salir)
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
        content: const Text('¿Borrar esta categoría del menú? (Los registros pasados no se borrarán)'),
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