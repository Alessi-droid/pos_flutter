// lib/models/venta.dart

class Venta {
  final int? id;
  final int turnoId;
  final int folio; // 👈 NUEVO CAMPO
  final double total;
  final String metodoPago; // 'efectivo' o 'tarjeta'
  final DateTime fecha;

  Venta({
    this.id,
    required this.turnoId,
    required this.folio,
    required this.total,
    required this.metodoPago,
    DateTime? fecha,
  }) : fecha = fecha ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'turno_id': turnoId,
      'folio': folio,
      'total': total,
      'metodo_pago': metodoPago,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      id: map['id'] as int?,
      turnoId: map['turno_id'] as int,
      folio: map['folio'] as int,
      total: (map['total'] as num).toDouble(),
      metodoPago: map['metodo_pago'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
    );
  }

  Venta copyWith({
    int? id,
    int? turnoId,
    int? folio,
    double? total,
    String? metodoPago,
    DateTime? fecha,
  }) {
    return Venta(
      id: id ?? this.id,
      turnoId: turnoId ?? this.turnoId,
      folio: folio ?? this.folio,
      total: total ?? this.total,
      metodoPago: metodoPago ?? this.metodoPago,
      fecha: fecha ?? this.fecha,
    );
  }
}

class VentaDetalle {
  final int? id;
  final int ventaId;
  final int productoId;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;

  VentaDetalle({
    this.id,
    required this.ventaId,
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venta_id': ventaId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
    };
  }

  factory VentaDetalle.fromMap(Map<String, dynamic> map) {
    return VentaDetalle(
      id: map['id'] as int?,
      ventaId: map['venta_id'] as int,
      productoId: map['producto_id'] as int,
      cantidad: (map['cantidad'] as num).toDouble(),
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }
}
