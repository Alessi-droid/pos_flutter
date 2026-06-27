// lib/models/producto.dart - CON SOPORTE PARA MÚLTIPLES IDS/CÓDIGOS

class Producto {
  final int? id;
  final String codigo;
  final String nombre;
  final double costo;
  final double precioVenta;
  double stock;
  final double stockMinimo;
  final bool esSuelto;
  final int? productoPadreId;
  final int unidadesPorCaja;
  final bool aGranel;
  final String? unidadMedida;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final String? codigosAlternativos; // ⭐ NUEVO: Códigos de otros distribuidores (JSON)

  Producto({
    this.id,
    required this.codigo,
    required this.nombre,
    required this.costo,
    required this.precioVenta,
    this.stock = 0,
    this.stockMinimo = 0.0,
    this.esSuelto = false,
    this.productoPadreId,
    this.unidadesPorCaja = 1,
    this.aGranel = false,
    this.unidadMedida,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    this.codigosAlternativos, // ⭐ NUEVO
  })  : fechaCreacion = fechaCreacion ?? DateTime.now(),
        fechaActualizacion = fechaActualizacion ?? DateTime.now();

  String get nombreConUnidad {
    if (aGranel && unidadMedida != null) {
      return '$nombre ($unidadMedida)';
    }
    return nombre;
  }

  double get margenUtilidad => 
      costo > 0 ? ((precioVenta - costo) / costo * 100) : 0;

  double get valorInventario => costo * stock;

  // ⭐ NUEVO: Obtener lista de códigos alternativos
  List<String> get codigosAlternativosLista {
    if (codigosAlternativos == null || codigosAlternativos!.isEmpty) return [];
    return codigosAlternativos!.split(',').map((c) => c.trim()).toList();
  }

  /// Calcula precio sugerido con 25% de utilidad y redondea a entero
  /// Regla: 0.5 redondea hacia arriba, menor redondea hacia abajo
  static double calcularPrecioSugerido(double costo) {
    double sugerido = costo * 1.25;
    double parteDecimal = sugerido - sugerido.floorToDouble();
    if (parteDecimal >= 0.5) {
      return sugerido.ceilToDouble();
    } else {
      return sugerido.floorToDouble();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'costo': costo,
      'precio_venta': precioVenta,
      'stock': stock,
      'stock_minimo': stockMinimo,
      'es_suelto': esSuelto ? 1 : 0,
      'producto_padre_id': productoPadreId,
      'unidades_por_caja': unidadesPorCaja,
      'a_granel': aGranel ? 1 : 0,
      'unidad_medida': unidadMedida,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
      'codigos_alternativos': codigosAlternativos, // ⭐ NUEVO
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] as int?,
      codigo: map['codigo'] as String,
      nombre: map['nombre'] as String,
      costo: (map['costo'] as num).toDouble(),
      precioVenta: (map['precio_venta'] as num).toDouble(),
      stock: (map['stock'] as num).toDouble(),
      stockMinimo: (map['stock_minimo'] as num?)?.toDouble() ?? 0.0,
      esSuelto: (map['es_suelto'] as int) == 1,
      productoPadreId: map['producto_padre_id'] as int?,
      unidadesPorCaja: map['unidades_por_caja'] as int? ?? 1,
      aGranel: (map['a_granel'] as int? ?? 0) == 1,
      unidadMedida: map['unidad_medida'] as String?,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      fechaActualizacion: DateTime.parse(map['fecha_actualizacion'] as String),
      codigosAlternativos: map['codigos_alternativos'] as String?, // ⭐ NUEVO
    );
  }

  Producto copyWith({
    int? id,
    String? codigo,
    String? nombre,
    double? costo,
    double? precioVenta,
    double? stock,
    double? stockMinimo,
    bool? esSuelto,
    int? productoPadreId,
    int? unidadesPorCaja,
    bool? aGranel,
    String? unidadMedida,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    String? codigosAlternativos, // ⭐ NUEVO
  }) {
    return Producto(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      costo: costo ?? this.costo,
      precioVenta: precioVenta ?? this.precioVenta,
      stock: stock ?? this.stock,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      esSuelto: esSuelto ?? this.esSuelto,
      productoPadreId: productoPadreId ?? this.productoPadreId,
      unidadesPorCaja: unidadesPorCaja ?? this.unidadesPorCaja,
      aGranel: aGranel ?? this.aGranel,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      codigosAlternativos: codigosAlternativos ?? this.codigosAlternativos, // ⭐ NUEVO
    );
  }
}
