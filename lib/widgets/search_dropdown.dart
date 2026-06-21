// lib/widgets/search_dropdown.dart - VERSIÓN CORREGIDA

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

typedef SearchItemBuilder<T> = Widget Function(BuildContext context, T item, bool isSelected);
typedef OnItemSelected<T> = void Function(T item);

class SearchDropdown<T> extends StatefulWidget {
  final List<T> items;
  final SearchItemBuilder<T> itemBuilder;
  final OnItemSelected<T> onItemSelected;
  final VoidCallback? onDismiss;
  final double maxHeight;
  final int selectedIndex;

  const SearchDropdown({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onItemSelected,
    this.onDismiss,
    this.maxHeight = 300,
    this.selectedIndex = -1,
  });

  @override
  State<SearchDropdown> createState() => _SearchDropdownState<T>();
}

class _SearchDropdownState<T> extends State<SearchDropdown<T>> {
  final ScrollController _scrollController = ScrollController();
  static const double _itemHeight = 72.0;

  @override
  void didUpdateWidget(SearchDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el índice seleccionado cambió, hacer scroll automático
    if (oldWidget.selectedIndex != widget.selectedIndex && widget.selectedIndex >= 0) {
      _scrollToSelected();
    }
  }

  /// Scroll automático al item seleccionado
  void _scrollToSelected() {
    if (widget.selectedIndex < 0 || widget.selectedIndex >= widget.items.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      
      final targetOffset = widget.selectedIndex * _itemHeight;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentOffset = _scrollController.offset;
      final viewportHeight = _scrollController.position.viewportDimension;

      if (targetOffset < currentOffset) {
        // Item está arriba, scroll hacia arriba
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      } else if (targetOffset > currentOffset + viewportHeight - _itemHeight) {
        // Item está abajo, scroll hacia abajo
        final newOffset = (targetOffset - viewportHeight + _itemHeight).clamp(0.0, maxScroll);
        _scrollController.animateTo(
          newOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final isSelected = index == widget.selectedIndex;
          
          return Container(
            height: _itemHeight,
            color: isSelected ? AppColors.accentBlue.withOpacity(0.15) : null,
            child: InkWell(
              onTap: () => widget.onItemSelected(widget.items[index]),
              child: widget.itemBuilder(context, widget.items[index], isSelected),
            ),
          );
        },
      ),
    );
  }
}
