// lib/widgets/producto_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/producto.dart';
import '../providers/inventario_provider.dart';

class ProductoFormDialog extends StatefulWidget {
  final Producto? producto;
  final String? codigoInicial;

  const ProductoFormDialog({
    super.key,
    this.producto,
    this.codigoInicial,
  });

  @override
  State<ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends State<ProductoFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codigoController;
  late final TextEditingController _nombreController;
  late final TextEditingController _costoController;
  late final TextEditingController _precioController;
  late final TextEditingController _stockController;
  late final TextEditingController _stockMinimoController;
  late final TextEditingController _unidadMedidaController;

  // Nodos para saltar de campo en campo con el teclado
  final FocusNode _codigoFocus = FocusNode();
  final FocusNode _nombreFocus = FocusNode();
  final FocusNode _costoFocus = FocusNode();
  final FocusNode _precioFocus = FocusNode();
  final FocusNode _stockFocus = FocusNode();
  final FocusNode _stockMinimoFocus = FocusNode();
  final FocusNode _unidadMedidaFocus = FocusNode();
  final FocusNode _buscarPadreFocus = FocusNode();
  final FocusNode _unidadesPorCajaFocus = FocusNode();

  bool _esSuelto = false;
  bool _aGranel = false;

  Producto? _productoPadreSeleccionado;
  final TextEditingController _buscarPadreController = TextEditingController();
  List<Producto> _sugerenciasPadre = [];
  bool _mostrarSugerenciasPadre = false;
  final TextEditingController _unidadesPorCajaController = TextEditingController(text: '1');

  bool _isLoading = false;
  bool _esModoEdicion = false;

  @override
  void initState() {
    super.initState();
    _esModoEdicion = widget.producto != null;

    _codigoController = TextEditingController(
      text: widget.producto?.codigo ?? widget.codigoInicial ?? '',
    );
    _nombreController = TextEditingController(
        text: widget.producto?.nombre ?? '');
    _costoController = TextEditingController(
        text: widget.producto?.costo.toStringAsFixed(2) ?? '');
    _precioController = TextEditingController(
        text: widget.producto?.precioVenta.toStringAsFixed(2) ?? '');
    _stockController = TextEditingController(
        text: widget.producto?.stock.toStringAsFixed(2) ?? '0.0');
    _stockMinimoController = TextEditingController(
        text: widget.producto?.stockMinimo.toStringAsFixed(2) ?? '0.0');
    _unidadMedidaController = TextEditingController(
        text: widget.producto?.unidadMedida ?? 'kg');

    if (_esModoEdicion) {
      _esSuelto = widget.producto!.esSuelto;
      _aGranel = widget.producto!.aGranel;
      _unidadesPorCajaController.text = widget.producto!.unidadesPorCaja.toString();
      if (_esSuelto && widget.producto!.productoPadreId != null) {
        _cargarProductoPadre(widget.producto!.productoPadreId!);
      }
    }

    _buscarPadreController.addListener(_buscarProductoPadre);
    _unidadesPorCajaController.addListener(_calcularCostoUnitario);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _codigoFocus.requestFocus();
    });
  }

  Future<void> _cargarProductoPadre(int id) async {
    final provider = context.read<InventarioProvider>();
    final padre = await provider.obtenerProductoPorId(id);
    if (padre != null && mounted) {
      setState(() {
        _productoPadreSeleccionado = padre;
        _buscarPadreController.text = padre.nombre;
      });
      _calcularCostoUnitario();
    }
  }

  void _buscarProductoPadre() {
    final query = _buscarPadreController.text;
    final provider = context.read<InventarioProvider>();

    if (query.isEmpty) {
      setState(() {
        _sugerenciasPadre = [];
        _mostrarSugerenciasPadre = false;
      });
    } else {
      setState(() {
        _sugerenciasPadre = provider.buscarProductos(query)
            .where((p) => p.id != widget.producto?.id)
            .take(5)
            .toList();
        _mostrarSugerenciasPadre = _sugerenciasPadre.isNotEmpty;
      });
    }
  }

  void _seleccionarProductoPadre(Producto producto) {
    setState(() {
      _productoPadreSeleccionado = producto;
      _buscarPadreController.text = producto.nombre;
      _mostrarSugerenciasPadre = false;
    });
    _calcularCostoUnitario();
    FocusScope.of(context).requestFocus(_unidadesPorCajaFocus);
  }

  void _calcularCostoUnitario() {
    if (_productoPadreSeleccionado == null) return;

    final unidades = int.tryParse(_unidadesPorCajaController.text);
    if (unidades == null || unidades <= 0) return;

    final costoPadre = _productoPadreSeleccionado!.costo;
    final costoUnitario = costoPadre / unidades;

    _costoController.text = costoUnitario.toStringAsFixed(2);
    _calcularPrecioSugerido();
  }

  // ✅ FUNCIÓN DE PRECIO: +25% y redondeo a peso o .50 exacto
  void _calcularPrecioSugerido() {
    final costo = double.tryParse(_costoController.text);
    if (costo != null && costo > 0) {
      // Le suma el 25% de ganancia
      double sugerido = costo * 1.25;
      
      // Si el decimal es .50 o más, lo sube al peso siguiente.
      // Si el decimal es menor, lo baja al peso cerrado.
      double redondeado = sugerido.roundToDouble();
      
      _precioController.text = redondeado.toStringAsFixed(2);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_esSuelto && _productoPadreSeleccionado == null) {
      _mostrarError('Debes seleccionar un producto padre');
      return;
    }

    final unidadesPorCaja = int.tryParse(_unidadesPorCajaController.text);
    if (_esSuelto && (unidadesPorCaja == null || unidadesPorCaja <= 0)) {
      _mostrarError('Unidades por caja debe ser un número positivo');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final producto = Producto(
        id: widget.producto?.id,
        codigo: _codigoController.text.trim(),
        nombre: _nombreController.text.trim(),
        costo: double.parse(_costoController.text),
        precioVenta: double.parse(_precioController.text),
        stock: double.parse(_stockController.text),
        stockMinimo: double.parse(_stockMinimoController.text),
        esSuelto: _esSuelto,
        productoPadreId: _productoPadreSeleccionado?.id,
        unidadesPorCaja: _esSuelto ? int.parse(_unidadesPorCajaController.text) : 1,
        aGranel: _aGranel,
        unidadMedida: _aGranel ? _unidadMedidaController.text.trim() : null,
      );

      final provider = context.read<InventarioProvider>();
      bool exito;

      if (_esModoEdicion) {
        exito = await provider.actualizarProducto(producto);
      } else {
        exito = await provider.agregarProducto(producto);
      }

      if (mounted) {
        if (exito) {
          // ✅ PARCHE: Devuelve el producto a la pantalla anterior
          Navigator.pop(context, producto);
        } else {
          _mostrarError(_esModoEdicion
              ? 'Error al actualizar (código duplicado?)'
              : 'Error al guardar (código duplicado?)');
        }
      }
    } catch (e) {
      if (mounted) _mostrarError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nombreController.dispose();
    _costoController.dispose();
    _precioController.dispose();
    _stockController.dispose();
    _stockMinimoController.dispose();
    _unidadMedidaController.dispose();
    _buscarPadreController.dispose();
    _unidadesPorCajaController.dispose();

    _codigoFocus.dispose();
    _nombreFocus.dispose();
    _costoFocus.dispose();
    _precioFocus.dispose();
    _stockFocus.dispose();
    _stockMinimoFocus.dispose();
    _unidadMedidaFocus.dispose();
    _buscarPadreFocus.dispose();
    _unidadesPorCajaFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: Container(
        width: 700, // ✅ Tu estética original
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.paddingMedium),
                      decoration: BoxDecoration(
                        color: (_esModoEdicion
                                ? AppColors.accentBlue
                                : AppColors.inventoryOrange)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                      ),
                      child: Icon(
                        _esModoEdicion ? Icons.edit : Icons.add,
                        color: _esModoEdicion
                            ? AppColors.accentBlue
                            : AppColors.inventoryOrange,
                        size: AppSizes.iconLarge,
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _esModoEdicion ? 'Editar Producto' : 'Nuevo Producto',
                            style: const TextStyle(
                              fontSize: AppSizes.titleSmall,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _esModoEdicion
                                ? 'Modifica los datos del producto'
                                : 'Registra un nuevo producto en el inventario',
                            style: const TextStyle(
                              fontSize: AppSizes.bodyMedium,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingLarge),

                // Código
                TextFormField(
                  controller: _codigoController,
                  focusNode: _codigoFocus,
                  textInputAction: TextInputAction.next, // Salto con Enter
                  decoration: const InputDecoration(
                    labelText: 'Código *',
                    hintText: 'Código de barras o SKU',
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                  enabled: !_esModoEdicion,
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_nombreFocus),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El código es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.paddingMedium),

                // Nombre
                TextFormField(
                  controller: _nombreController,
                  focusNode: _nombreFocus,
                  textInputAction: TextInputAction.next, // Salto con Enter
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Nombre del producto',
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_costoFocus),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.paddingMedium),

                // Costo y Precio
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costoController,
                        focusNode: _costoFocus,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Costo *',
                          prefixText: '\$ ',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        onChanged: (_) => _calcularPrecioSugerido(),
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_precioFocus),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Requerido';
                          final num = double.tryParse(value);
                          if (num == null || num <= 0) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingMedium),
                    Expanded(
                      child: TextFormField(
                        controller: _precioController,
                        focusNode: _precioFocus,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Precio Venta *',
                          prefixText: '\$ ',
                          helperText: '+25% y redondeo automático',
                          prefixIcon: Icon(Icons.sell),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        onFieldSubmitted: (_) {
                          if (_esSuelto) {
                            FocusScope.of(context).requestFocus(_stockMinimoFocus);
                          } else {
                            FocusScope.of(context).requestFocus(_stockFocus);
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Requerido';
                          final num = double.tryParse(value);
                          if (num == null || num <= 0) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingMedium),

                // Stock y Stock mínimo
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        focusNode: _stockFocus,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Stock Inicial',
                          helperText: _esSuelto 
                              ? 'Los sueltos inician en 0' 
                              : _aGranel 
                                  ? 'Cantidad en ${_unidadMedidaController.text}' 
                                  : 'Cantidad en inventario',
                          prefixIcon: const Icon(Icons.inventory),
                          suffix: _aGranel ? Text(_unidadMedidaController.text) : null,
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: _aGranel || !_esSuelto),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        enabled: !_esSuelto,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_stockMinimoFocus),
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingMedium),
                    Expanded(
                      child: TextFormField(
                        controller: _stockMinimoController,
                        focusNode: _stockMinimoFocus,
                        textInputAction: _aGranel || _esSuelto ? TextInputAction.next : TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Stock Mínimo',
                          helperText: _aGranel ? 'Alerta en ${_unidadMedidaController.text}' : 'Alerta de bajo stock',
                          prefixIcon: const Icon(Icons.warning_amber),
                          suffix: _aGranel ? Text(_unidadMedidaController.text) : null,
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: _aGranel),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        onFieldSubmitted: (_) {
                          if (_aGranel) {
                            FocusScope.of(context).requestFocus(_unidadMedidaFocus);
                          } else if (_esSuelto) {
                            FocusScope.of(context).requestFocus(_buscarPadreFocus);
                          } else {
                            _guardar();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingLarge),

                // Switches
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingMedium),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Producto a Granel',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          'Se vende por peso o volumen (kg/lt)',
                          style: TextStyle(fontSize: AppSizes.bodySmall),
                        ),
                        value: _aGranel,
                        onChanged: (val) => setState(() => _aGranel = val),
                        activeColor: AppColors.inventoryOrange,
                        secondary: const Icon(Icons.scale, color: AppColors.inventoryOrange),
                      ),
                      if (_aGranel) ...[
                        const SizedBox(height: AppSizes.paddingSmall),
                        TextFormField(
                          controller: _unidadMedidaController,
                          focusNode: _unidadMedidaFocus,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Unidad de medida',
                            hintText: 'kg, lt, g, etc.',
                            prefixIcon: Icon(Icons.science),
                          ),
                          onFieldSubmitted: (_) => _guardar(),
                        ),
                      ],
                      const Divider(),
                      SwitchListTile(
                        title: const Text(
                          'Es Suelto',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          'Se extrae de una caja/paquete',
                          style: TextStyle(fontSize: AppSizes.bodySmall),
                        ),
                        value: _esSuelto,
                        onChanged: (val) {
                          setState(() {
                            _esSuelto = val;
                            if (val) {
                              _stockController.text = '0.0';
                              _aGranel = false;
                            }
                          });
                        },
                        activeColor: AppColors.accentBlue,
                        secondary: const Icon(Icons.inbox, color: AppColors.accentBlue),
                      ),
                    ],
                  ),
                ),

                // ✅ LA LÓGICA PERDIDA DE PRODUCTO SUELTO FUE RESTAURADA AQUÍ
                if (_esSuelto) ...[
                  const SizedBox(height: AppSizes.paddingLarge),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingMedium),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configuración de Producto Suelto',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentBlue,
                          ),
                        ),
                        const SizedBox(height: AppSizes.paddingMedium),

                        // Producto padre
                        TextFormField(
                          controller: _buscarPadreController,
                          focusNode: _buscarPadreFocus,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Producto Padre *',
                            hintText: 'Buscar producto que contiene la caja/paquete',
                            prefixIcon: const Icon(Icons.inventory),
                            suffixIcon: _productoPadreSeleccionado != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _productoPadreSeleccionado = null;
                                        _buscarPadreController.clear();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => _buscarProductoPadre(),
                          validator: _esSuelto
                              ? (value) {
                                  if (_productoPadreSeleccionado == null) {
                                    return 'Selecciona un producto padre';
                                  }
                                  return null;
                                }
                              : null,
                        ),

                        // Sugerencias de producto padre
                        if (_mostrarSugerenciasPadre)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 150),
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.divider),
                              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                              color: Colors.white,
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _sugerenciasPadre.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final producto = _sugerenciasPadre[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(producto.nombre),
                                  subtitle: Text('Código: ${producto.codigo} • Costo: ${_costoPorUnidad(producto)}'),
                                  onTap: () => _seleccionarProductoPadre(producto),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: AppSizes.paddingMedium),

                        // Unidades por caja
                        TextFormField(
                          controller: _unidadesPorCajaController,
                          focusNode: _unidadesPorCajaFocus,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Unidades por caja *',
                            hintText: 'Ej. 20',
                            prefixIcon: Icon(Icons.category),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => _calcularCostoUnitario(),
                          onFieldSubmitted: (_) => _guardar(),
                          validator: _esSuelto
                              ? (value) {
                                  final num = int.tryParse(value ?? '');
                                  if (num == null || num <= 0) {
                                    return 'Ingresa un número válido';
                                  }
                                  return null;
                                }
                              : null,
                        ),

                        if (_productoPadreSeleccionado != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSizes.paddingSmall),
                            child: Text(
                              'Costo por unidad: \$${_calcularCostoUnitarioTexto()}',
                              style: const TextStyle(
                                fontSize: AppSizes.bodySmall,
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSizes.paddingLarge * 1.5),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('CANCELAR'),
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingMedium),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _esModoEdicion
                              ? AppColors.accentBlue
                              : AppColors.inventoryOrange,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(_esModoEdicion ? 'ACTUALIZAR' : 'GUARDAR'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _costoPorUnidad(Producto padre) {
    final unidades = int.tryParse(_unidadesPorCajaController.text) ?? 1;
    final costoUnitario = padre.costo / unidades;
    return '\$${costoUnitario.toStringAsFixed(2)}/u';
  }

  String _calcularCostoUnitarioTexto() {
    if (_productoPadreSeleccionado == null) return '0.00';
    final unidades = int.tryParse(_unidadesPorCajaController.text) ?? 1;
    if (unidades <= 0) return '0.00';
    final costoUnitario = _productoPadreSeleccionado!.costo / unidades;
    return costoUnitario.toStringAsFixed(2);
  }
}