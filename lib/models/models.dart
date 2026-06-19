class Producto {
  final int? id;
  final String codigo;
  final String nombre;
  final double precioVenta;
  final double precioCompra;
  final double stock;
  final int? productoPadreId;
  final int factorConversion;
  final bool esGranel; // Si es "suelto" (cigarro individual)
  final bool esKilo;   // NUEVO: Si se vende por peso (jamón, azúcar)

  Producto({
    this.id,
    required this.codigo,
    required this.nombre,
    required this.precioVenta,
    required this.precioCompra,
    required this.stock,
    this.productoPadreId,
    this.factorConversion = 0,
    this.esGranel = false,
    this.esKilo = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'precio_venta': precioVenta,
      'precio_compra': precioCompra,
      'stock': stock,
      'producto_padre_id': productoPadreId,
      'factor_conversion': factorConversion,
      'es_granel': esGranel ? 1 : 0,
      'es_kilo': esKilo ? 1 : 0,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      codigo: map['codigo'],
      nombre: map['nombre'],
      precioVenta: double.tryParse(map['precio_venta'].toString()) ?? 0.0,
      precioCompra: double.tryParse(map['precio_compra'].toString()) ?? 0.0,
      stock: double.tryParse(map['stock'].toString()) ?? 0.0,
      productoPadreId: map['producto_padre_id'],
      factorConversion: map['factor_conversion'] ?? 0,
      esGranel: (map['es_granel'] == 1),
      esKilo: (map['es_kilo'] == 1),
    );
  }
}

class VentaItem {
  final Producto producto;
  double cantidad;
  double total;

  VentaItem({required this.producto, required this.cantidad})
      : total = producto.precioVenta * cantidad;
}