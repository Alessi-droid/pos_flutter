import 'package:flutter/material.dart';

/// Constantes de diseño basadas en las capturas originales
class AppColors {
  // Colores principales del drawer y módulo POS
  static const Color primaryBlue = Color(0xFF2C3E8F); // Azul marino del drawer
  static const Color accentBlue = Color(0xFF4A5FC1); // Azul más claro para botones
  
  // Colores del módulo Inventario
  static const Color inventoryOrange = Color(0xFFFF6B35);
  static const Color inventoryOrangeLight = Color(0xFFFFE5DC);
  
  // Colores del módulo Finanzas
  static const Color financeGreen = Color(0xFF4CAF50);
  static const Color financeRed = Color(0xFFE53935);
  static const Color financeBlue = Color(0xFF2196F3);
  
  // Neutros
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardWhite = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFE0E0E0);
  
  // Estados
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFFA000);
}

/// Tamaños optimizados para tablet 10.1"
class AppSizes {
  // Espaciado
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  
  // Drawer
  static const double drawerWidth = 180.0;
  
  // Botones
  static const double buttonHeight = 56.0;
  static const double fabSize = 64.0;
  
  // Tipografía
  static const double titleLarge = 32.0;
  static const double titleMedium = 24.0;
  static const double titleSmall = 20.0;
  static const double bodyLarge = 18.0;
  static const double bodyMedium = 16.0;
  static const double bodySmall = 14.0;
  
  // Íconos
  static const double iconSmall = 20.0;
  static const double iconMedium = 28.0;
  static const double iconLarge = 40.0;
  
  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  
  // Cards
  static const double cardElevation = 2.0;
}

/// Estilos de texto predefinidos
class AppTextStyles {
  // Headers
  static const TextStyle headerLarge = TextStyle(
    fontSize: AppSizes.titleLarge,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle headerMedium = TextStyle(
    fontSize: AppSizes.titleMedium,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: AppSizes.bodyLarge,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: AppSizes.bodyMedium,
    color: AppColors.textPrimary,
  );
  
  // Drawer
  static const TextStyle drawerItem = TextStyle(
    fontSize: AppSizes.bodyMedium,
    color: Colors.white70,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle drawerItemActive = TextStyle(
    fontSize: AppSizes.bodyMedium,
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );
  
  // Moneda (números grandes)
  static const TextStyle currency = TextStyle(
    fontSize: 48.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle currencySmall = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  // Tabla headers
  static const TextStyle tableHeader = TextStyle(
    fontSize: AppSizes.bodySmall,
    fontWeight: FontWeight.bold,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
}

/// Duración de animaciones
class AppDurations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}
