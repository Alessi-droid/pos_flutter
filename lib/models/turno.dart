class Turno {
  final int? id;
  final double montoInicial;
  final DateTime fechaApertura;
  final DateTime? fechaCierre;
  final bool activo;
  final double? montoCierre;

  Turno({
    this.id,
    required this.montoInicial,
    DateTime? fechaApertura,
    this.fechaCierre,
    this.activo = true,
    this.montoCierre,
  }) : fechaApertura = fechaApertura ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'monto_inicial': montoInicial,
      'fecha_apertura': fechaApertura.toIso8601String(),
      'fecha_cierre': fechaCierre?.toIso8601String(),
      'activo': activo ? 1 : 0,
      'monto_cierre': montoCierre,
    };
  }

  factory Turno.fromMap(Map<String, dynamic> map) {
    return Turno(
      id: map['id'] as int?,
      montoInicial: (map['monto_inicial'] as num).toDouble(),
      fechaApertura: DateTime.parse(map['fecha_apertura'] as String),
      fechaCierre: map['fecha_cierre'] != null 
          ? DateTime.parse(map['fecha_cierre'] as String) 
          : null,
      activo: (map['activo'] as int) == 1,
      montoCierre: map['monto_cierre'] != null 
          ? (map['monto_cierre'] as num).toDouble() 
          : null,
    );
  }

  Turno copyWith({
    int? id,
    double? montoInicial,
    DateTime? fechaApertura,
    DateTime? fechaCierre,
    bool? activo,
    double? montoCierre,
  }) {
    return Turno(
      id: id ?? this.id,
      montoInicial: montoInicial ?? this.montoInicial,
      fechaApertura: fechaApertura ?? this.fechaApertura,
      fechaCierre: fechaCierre ?? this.fechaCierre,
      activo: activo ?? this.activo,
      montoCierre: montoCierre ?? this.montoCierre,
    );
  }
}
