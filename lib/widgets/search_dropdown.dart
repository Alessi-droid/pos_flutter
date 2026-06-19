// lib/widgets/search_dropdown.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.selectedIndex = 0,
  });

  @override
  State<SearchDropdown> createState() => _SearchDropdownState<T>();
}

class _SearchDropdownState<T> extends State<SearchDropdown<T>> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'SearchDropdownFocusNode');
  static const double _itemHeight = 72.0;

  @override
  void initState() {
    super.initState();
    // Se elimina el requestFocus() para evitar que le robe el foco al TextField
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SearchDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelected();
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  void _scrollToSelected() {
    if (widget.selectedIndex < 0 || widget.selectedIndex >= widget.items.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final targetOffset = widget.selectedIndex * _itemHeight;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentOffset = _scrollController.offset;
      final viewportHeight = _scrollController.position.viewportDimension;

      if (targetOffset < currentOffset) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      } else if (targetOffset > currentOffset + viewportHeight - _itemHeight) {
        final newOffset = (targetOffset - viewportHeight + _itemHeight).clamp(0.0, maxScroll);
        _scrollController.animateTo(
          newOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (widget.selectedIndex < widget.items.length - 1) {
        widget.onItemSelected(widget.items[widget.selectedIndex + 1]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (widget.selectedIndex > 0) {
        widget.onItemSelected(widget.items[widget.selectedIndex - 1]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (widget.selectedIndex >= 0 && widget.selectedIndex < widget.items.length) {
        widget.onItemSelected(widget.items[widget.selectedIndex]);
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      child: Container(
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
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final isSelected = index == widget.selectedIndex;
            return InkWell(
              onTap: () => widget.onItemSelected(widget.items[index]),
              child: Container(
                height: _itemHeight,
                color: isSelected ? AppColors.accentBlue.withOpacity(0.15) : null,
                child: widget.itemBuilder(context, widget.items[index], isSelected),
              ),
            );
          },
        ),
      ),
    );
  }
}