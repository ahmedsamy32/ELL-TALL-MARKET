import 'package:flutter/material.dart';
import 'package:ell_tall_market/services/location_service.dart';

/// ويدجت لعرض المتاجر القريبة من موقع العميل
class NearbyStoresWidget extends StatefulWidget {
  final double customerLatitude;
  final double customerLongitude;
  final double maxDistanceKm;
  final String? categoryFilter;
  final Function(Map<String, dynamic> store)? onStoreTap;

  const NearbyStoresWidget({
    super.key,
    required this.customerLatitude,
    required this.customerLongitude,
    this.maxDistanceKm = 20,
    this.categoryFilter,
    this.onStoreTap,
  });

  @override
  State<NearbyStoresWidget> createState() => _NearbyStoresWidgetState();
}

class _NearbyStoresWidgetState extends State<NearbyStoresWidget> {
  List<Map<String, dynamic>> _stores = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNearbyStores();
  }

  Future<void> _loadNearbyStores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stores = await LocationService.getNearbyStores(
        latitude: widget.customerLatitude,
        longitude: widget.customerLongitude,
        maxDistanceKm: widget.maxDistanceKm,
        categoryFilter: widget.categoryFilter,
      );

      if (mounted) {
        setState(() {
          _stores = stores;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ في تحميل المتاجر';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadNearbyStores,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_stores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store_outlined, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'لا توجد متاجر قريبة منك',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'جرب زيادة نطاق البحث أو اختر موقعاً آخر',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNearbyStores,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stores.length,
        itemBuilder: (context, index) {
          final store = _stores[index];
          return _buildStoreCard(store, colorScheme);
        },
      ),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store, ColorScheme colorScheme) {
    final distanceKm = (store['distance_km'] as num?)?.toDouble() ?? 0;
    final rating = (store['rating'] as num?)?.toDouble() ?? 0;
    final deliveryTime = store['estimated_delivery_time'] as int? ?? 30;
    final deliveryFee = (store['delivery_fee'] as num?)?.toDouble() ?? 0;
    final isOpen = store['is_open'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => widget.onStoreTap?.call(store),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Store Image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      image: store['image_url'] != null
                          ? DecorationImage(
                              image: NetworkImage(store['image_url']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: store['image_url'] == null
                        ? Icon(Icons.store, color: colorScheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Store Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${store['total_reviews'] ?? 0})',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOpen ? 'مفتوح' : 'مغلق',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Distance, Time, Fee
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.location_on,
                    label: '${distanceKm.toStringAsFixed(1)} كم',
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.access_time,
                    label: '$deliveryTime دقيقة',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.delivery_dining,
                    label: '${deliveryFee.toStringAsFixed(0)} ج.م',
                    color: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
