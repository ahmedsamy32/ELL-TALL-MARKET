import 'package:flutter/material.dart';
import 'package:ell_tall_market/models/product_model.dart';

class ProductOptionsBottomSheet extends StatefulWidget {
  final ProductModel product;
  final Function(
    int quantity,
    Map<String, dynamic> selectedOptions,
    ProductVariant? variant,
  )
  onAddToCart;

  const ProductOptionsBottomSheet({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<ProductOptionsBottomSheet> createState() =>
      _ProductOptionsBottomSheetState();
}

class _ProductOptionsBottomSheetState extends State<ProductOptionsBottomSheet> {
  // Map<GroupId, SelectedOption>
  final Map<String, ProductVariantOption> _selectedOptions = {};
  int _quantity = 1;
  ProductVariant? _matchedVariant;
  String? _errorMessage;
  bool _showValidationError = false;

  @override
  void initState() {
    super.initState();
    _initializeDefaultOptions();
  }

  void _initializeDefaultOptions() {
    // Pre-select first option for required groups if strict
    // For now, we leave them empty to force user selection unless there's only one option
    if (widget.product.variantGroups != null) {
      for (var group in widget.product.variantGroups!) {
        if (group.options.length == 1) {
          _selectedOptions[group.id] = group.options.first;
        }
      }
    }
    _updateMatchedVariant();
  }

  void _updateMatchedVariant() {
    if (widget.product.variants == null || widget.product.variants!.isEmpty) {
      _matchedVariant = null;
      return;
    }

    try {
      // Find a variant that matches ALL selected options
      // Note: This logic assumes variants define a specific combination of options.
      // If the product has multiple groups (Color, Size), a variant should have both.

      _matchedVariant = widget.product.variants!.firstWhere((variant) {
        // Check if this variant contains all selected options
        // We look for match by comparing option IDs or Values
        // Usually variants have a list of options.

        // Simplifying matching logic:
        // A variant matches if for every selected option group, the variant has that option.
        // AND the variant doesn't have options contradicting the selection.

        // Better: A variant matches if its `selectedOptions` matches our `_selectedOptions`.
        // However, `_selectedOptions` might be partial.

        // Exact match strategy:
        if (variant.selectedOptions.length != _selectedOptions.length) {
          return false;
        }

        for (var option in variant.selectedOptions) {
          // Find the group this option belongs to (we might need group ID in option, or search groups)
          // Since ProductVariantOption doesn't have group_id directly in the provided model loop,
          // we align by 'value' and 'name'.

          bool found = false;
          for (var selected in _selectedOptions.values) {
            // Assuming unique ID or Name+Value pair
            if (selected.id == option.id) {
              found = true;
              break;
            }
          }
          if (!found) return false;
        }
        return true;
      });

      setState(() => _errorMessage = null);
    } catch (e) {
      _matchedVariant = null;
      // It's possible no variant exists for the exact combination yet
    }
  }

  List<String> _missingRequiredGroupNames() {
    if (widget.product.variantGroups == null) return const [];
    final missing = <String>[];
    for (var group in widget.product.variantGroups!) {
      if (!_selectedOptions.containsKey(group.id)) {
        missing.add(group.name);
      }
    }
    return missing;
  }

  double get _currentPrice {
    if (_matchedVariant != null && _matchedVariant!.price != null) {
      return _matchedVariant!.price!;
    }
    return widget.product.price;
  }

  String? get _currentImage {
    if (_matchedVariant != null &&
        _matchedVariant!.imageUrl != null &&
        _matchedVariant!.imageUrl!.isNotEmpty) {
      return _matchedVariant!.imageUrl;
    }
    // Also check selected options for images (e.g. Color Red might have an image)
    for (var opt in _selectedOptions.values) {
      if (opt.imageUrl != null && opt.imageUrl!.isNotEmpty) {
        return opt.imageUrl;
      }
    }
    return widget.product.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header / Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Product Summary
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _currentImage != null
                        ? Image.network(
                            _currentImage!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey[200],
                              width: 80,
                              height: 80,
                              child: const Icon(Icons.broken_image),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            width: 80,
                            height: 80,
                            child: const Icon(Icons.image),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_currentPrice.toStringAsFixed(0)} ج.م',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_matchedVariant != null &&
                            _matchedVariant!.stockQuantity != null)
                          Text(
                            'المتاح: ${_matchedVariant!.stockQuantity}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Options Sections
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (widget.product.variantGroups != null)
                    ...widget.product.variantGroups!.map(
                      (group) => _buildOptionGroup(group),
                    ),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Quantity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الكمية', style: theme.textTheme.titleMedium),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Text(
                              '$_quantity',
                              style: theme.textTheme.titleMedium,
                            ),
                            IconButton(
                              onPressed: () => setState(
                                () => _quantity++,
                              ), // Could cap at stock
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Add Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FilledButton(
                onPressed: _handleAdd,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('أضف إلى السلة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionGroup(ProductVariantGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            group.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: _showValidationError
                  ? (_selectedOptions.containsKey(group.id) ? null : Colors.red)
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'مطلوب',
            style: TextStyle(
              color:
                  _showValidationError &&
                      !_selectedOptions.containsKey(group.id)
                  ? Colors.red
                  : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: group.options.map((option) {
            final isSelected = _selectedOptions[group.id]?.id == option.id;
            return ChoiceChip(
              label: Text(option.value),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedOptions[group.id] = option;
                  } else {
                    // Only allow deselect if not required? Or just deselect.
                    // UX: Usually radio button behavior for required.
                    if (!group.isRequired) {
                      _selectedOptions.remove(group.id);
                    }
                  }
                  if (_showValidationError) {
                    _showValidationError =
                        _missingRequiredGroupNames().isNotEmpty;
                  }
                  _updateMatchedVariant();
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _handleAdd() {
    final missingGroups = _missingRequiredGroupNames();
    if (missingGroups.isNotEmpty) {
      setState(() {
        _showValidationError = true;
        _errorMessage = 'يرجى اختيار: ${missingGroups.join('، ')}';
      });
      return;
    }

    if (_matchedVariant == null &&
        widget.product.variants != null &&
        widget.product.variants!.isNotEmpty) {
      setState(() {
        _showValidationError = true;
        _errorMessage = 'التركيبة المختارة غير متاحة';
      });
      return;
    }

    if (_matchedVariant != null &&
        (_matchedVariant!.stockQuantity ?? 0) < _quantity) {
      setState(() {
        _showValidationError = true;
        _errorMessage = 'الكمية المطلوبة غير متاحة';
      });
      return;
    }

    if (widget.product.stockQuantity < _quantity) {
      setState(() {
        _showValidationError = true;
        _errorMessage = 'الكمية المطلوبة غير متاحة';
      });
      return;
    }

    setState(() {
      _showValidationError = false;
      _errorMessage = null;
    });

    // Construct selected options map for backend
    // Backend likely expects {'Color': 'Red', 'Size': 'XL'} or IDs
    // Based on CartProvider.addToCart, it takes Map<String, dynamic> selectedOptions.
    // We should probably send the Option Model or ID.
    // Usually it's key-value pairs of group_name: option_value or group_id: option_id

    // Check CartService implementation to be sure.
    // Assuming Map<String, dynamic> where keys are Group Names and values are Option Values for display,
    // OR keys are IDs.
    // Safe bet: Pass structured map.

    final optionsMap = <String, dynamic>{};
    _selectedOptions.forEach((groupId, option) {
      // Find group name
      final group = widget.product.variantGroups?.firstWhere(
        (g) => g.id == groupId,
      );
      if (group != null) {
        optionsMap[group.name] = option.value;
      }
    });

    widget.onAddToCart(_quantity, optionsMap, _matchedVariant);
  }
}
