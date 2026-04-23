import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/providers/location_provider.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/screens/shared/advanced_map_screen.dart';

/// نوع النموذج - للمتاجر أو للعناوين السكنية
enum AddressFormType {
  /// نموذج عنوان المتجر (بدون رقم المبنى/الطابق/الشقة)
  store,

  /// نموذج العنوان السكني (مع كل التفاصيل)
  residential,
}

class AddressFormSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  /// When true (default), this section wraps its fields in a [Form].
  ///
  /// Set to false when embedding inside an existing parent [Form]
  /// (to avoid nested forms).
  final bool wrapInForm;

  /// نوع النموذج - يحدد الحقول المعروضة
  final AddressFormType formType;

  final TextEditingController governorateController;
  final TextEditingController cityController;
  final TextEditingController
  areaController; // المنطقة/الحي (كان villageController)
  final TextEditingController streetController;
  final TextEditingController landmarkController;

  // حقول إضافية للعناوين السكنية فقط
  final TextEditingController?
  labelController; // اسم العنوان (المنزل، العمل، إلخ)
  final TextEditingController? buildingNumberController; // رقم المبنى
  final TextEditingController? floorNumberController; // رقم الطابق
  final TextEditingController? apartmentNumberController; // رقم الشقة
  final TextEditingController? notesController; // ملاحظات إضافية

  final FocusNode governorateFocus;
  final FocusNode cityFocus;
  final FocusNode streetFocus;

  final VoidCallback onPickFromMap;

  /// Coordinates (optional). When [requirePosition] is true, the section will
  /// show an error hint if [position] is null.
  final LatLng? position;
  final bool requirePosition;
  final bool showMapPicker;

  final ValueChanged<String>? onGovernorateChanged;
  final ValueChanged<String>? onCityChanged;
  final ValueChanged<String>? onAreaChanged;

  /// Optional fixed lists for zone-safe selection.
  /// When provided, dropdowns are used instead of free text for these fields.
  final List<String>? governorateOptions;
  final List<String>? cityOptions;
  final List<String>? areaOptions;

  final String? summaryCity;
  final String? summaryGovernorate;

  const AddressFormSection({
    super.key,
    required this.formKey,
    this.wrapInForm = true,
    this.formType = AddressFormType.store,
    required this.governorateController,
    required this.cityController,
    required this.areaController,
    required this.streetController,
    required this.landmarkController,
    this.labelController,
    this.buildingNumberController,
    this.floorNumberController,
    this.apartmentNumberController,
    this.notesController,
    required this.governorateFocus,
    required this.cityFocus,
    required this.streetFocus,
    required this.onPickFromMap,
    this.position,
    this.requirePosition = false,
    this.showMapPicker = true,
    this.onGovernorateChanged,
    this.onCityChanged,
    this.onAreaChanged,
    this.governorateOptions,
    this.cityOptions,
    this.areaOptions,
    this.summaryCity,
    this.summaryGovernorate,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isResidential = formType == AddressFormType.residential;

    List<String> withCurrent(List<String>? options, String currentValue) {
      final current = currentValue.trim();
      final values = <String>[...(options ?? const <String>[])];
      if (current.isNotEmpty && !values.contains(current)) {
        values.insert(0, current);
      }
      return values;
    }

    final governorates = withCurrent(
      governorateOptions,
      governorateController.text,
    );
    final cities = withCurrent(cityOptions, cityController.text);
    final areas = withCurrent(areaOptions, areaController.text);

    // إذا تم تمرير options فهذا يعني أن الحقل يجب أن يكون اختياراً فقط
    // (حتى لو كانت القائمة فارغة مؤقتاً أثناء اختيار الحقل السابق)
    final useGovernorateDropdown = governorateOptions != null;
    final useCityDropdown = cityOptions != null;
    final useAreaDropdown = areaOptions != null;

    final fields = Column(
      children: [
        // اسم العنوان (للعناوين السكنية فقط)
        if (isResidential && labelController != null) ...[
          TextFormField(
            controller: labelController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'اسم العنوان',
              hintText: 'مثال: المنزل، العمل، منزل العائلة',
              prefixIcon: Icon(Icons.label_outline),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'الرجاء إدخال اسم للعنوان';
              }
              return null;
            },
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(governorateFocus),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: useGovernorateDropdown
                  ? DropdownButtonFormField<String>(
                      isExpanded: true,
                      isDense: true,
                      initialValue: governorateController.text.trim().isEmpty
                          ? null
                          : governorateController.text.trim(),
                      decoration: const InputDecoration(
                        labelText: 'المحافظة',
                        prefixIcon: Icon(Icons.map_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: governorates
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        final selected = (value ?? '').trim();
                        governorateController.text = selected;
                        onGovernorateChanged?.call(selected);
                        if (selected.isNotEmpty) {
                          FocusScope.of(context).requestFocus(cityFocus);
                        }
                      },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'الرجاء اختيار المحافظة';
                        }
                        return null;
                      },
                    )
                  : TextFormField(
                      controller: governorateController,
                      focusNode: governorateFocus,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'المحافظة',
                        prefixIcon: Icon(Icons.map_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'الرجاء إدخال المحافظة';
                        }
                        return null;
                      },
                      onChanged: onGovernorateChanged,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(cityFocus),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: useCityDropdown
                  ? DropdownButtonFormField<String>(
                      isExpanded: true,
                      isDense: true,
                      initialValue: cityController.text.trim().isEmpty
                          ? null
                          : cityController.text.trim(),
                      decoration: const InputDecoration(
                        labelText: 'المدينة/المركز',
                        prefixIcon: Icon(Icons.location_city),
                        border: OutlineInputBorder(),
                      ),
                      items: cities
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        final selected = (value ?? '').trim();
                        cityController.text = selected;
                        onCityChanged?.call(selected);
                        if (selected.isNotEmpty) {
                          FocusScope.of(context).requestFocus(streetFocus);
                        }
                      },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'الرجاء اختيار المدينة';
                        }
                        return null;
                      },
                    )
                  : TextFormField(
                      controller: cityController,
                      focusNode: cityFocus,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'المدينة/المركز',
                        prefixIcon: Icon(Icons.location_city),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'الرجاء إدخال المدينة';
                        }
                        return null;
                      },
                      onChanged: onCityChanged,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(streetFocus),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        useAreaDropdown
            ? DropdownButtonFormField<String>(
                isExpanded: true,
                isDense: true,
                initialValue: areaController.text.trim().isEmpty
                    ? null
                    : areaController.text.trim(),
                decoration: const InputDecoration(
                  labelText: 'المنطقة/الحي',
                  prefixIcon: Icon(Icons.cottage_outlined),
                  border: OutlineInputBorder(),
                ),
                items: areas
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  final selected = (value ?? '').trim();
                  areaController.text = selected;
                  onAreaChanged?.call(selected);
                  if (selected.isNotEmpty) {
                    FocusScope.of(context).requestFocus(streetFocus);
                  }
                },
                validator: (v) {
                  if (isResidential && (v == null || v.trim().isEmpty)) {
                    return 'الرجاء اختيار المنطقة/الحي';
                  }
                  return null;
                },
              )
            : TextFormField(
                controller: areaController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'المنطقة/الحي',
                  prefixIcon: Icon(Icons.cottage_outlined),
                  border: OutlineInputBorder(),
                ),
                onChanged: onAreaChanged,
                validator: (v) {
                  if (isResidential && (v == null || v.trim().isEmpty)) {
                    return 'الرجاء إدخال المنطقة/الحي';
                  }
                  return null;
                },
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(streetFocus),
              ),
        const SizedBox(height: 12),
        TextFormField(
          controller: streetController,
          focusNode: streetFocus,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'الشارع',
            prefixIcon: Icon(Icons.route),
            border: OutlineInputBorder(),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'الرجاء إدخال اسم الشارع';
            }
            return null;
          },
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        // حقول إضافية للعناوين السكنية
        if (isResidential) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              // رقم المبنى
              if (buildingNumberController != null)
                Expanded(
                  child: TextFormField(
                    controller: buildingNumberController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'رقم المبنى',
                      prefixIcon: Icon(Icons.apartment),
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                ),
              if (buildingNumberController != null &&
                  floorNumberController != null)
                const SizedBox(width: 12),
              // رقم الطابق
              if (floorNumberController != null)
                Expanded(
                  child: TextFormField(
                    controller: floorNumberController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الطابق',
                      prefixIcon: Icon(Icons.stairs),
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                ),
              if (floorNumberController != null &&
                  apartmentNumberController != null)
                const SizedBox(width: 12),
              // رقم الشقة
              if (apartmentNumberController != null)
                Expanded(
                  child: TextFormField(
                    controller: apartmentNumberController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'رقم الشقة',
                      prefixIcon: Icon(Icons.door_front_door),
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: landmarkController,
          textInputAction: isResidential
              ? TextInputAction.next
              : TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'علامة مميزة (اختياري)',
            hintText: 'مثال: بجوار المسجد، أمام الصيدلية',
            prefixIcon: Icon(Icons.place_outlined),
            border: OutlineInputBorder(),
          ),
          onFieldSubmitted: (_) {
            if (isResidential) {
              FocusScope.of(context).nextFocus();
            } else {
              FocusScope.of(context).unfocus();
            }
          },
        ),
        // ملاحظات إضافية (للعناوين السكنية فقط)
        if (isResidential && notesController != null) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: notesController,
            textInputAction: TextInputAction.done,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'ملاحظات إضافية (اختياري)',
              hintText: 'تعليمات للتوصيل أو ملاحظات أخرى',
              prefixIcon: Icon(Icons.notes),
              border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMapPicker)
          Row(
            children: [
              Expanded(
                child: Text(
                  isResidential
                      ? 'اختر موقعك من الخريطة'
                      : 'اختر موقع المتجر من الخريطة',
                  style: text.bodySmall?.copyWith(
                    color: color.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: onPickFromMap,
                icon: const Icon(Icons.map),
                tooltip: 'اختر من الخريطة',
                iconSize: 24,
              ),
            ],
          ),
        // Hide coordinates from UI; only show a hint when location is required
        // but not picked yet.
        if (showMapPicker && requirePosition && position == null) ...[
          const SizedBox(height: 8),
          Text(
            'الرجاء اختيار الموقع من الخريطة',
            style: text.bodySmall?.copyWith(color: color.error),
          ),
        ],
        const SizedBox(height: 12),
        if (wrapInForm)
          Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: fields,
          )
        else
          fields,
        if ((summaryCity ?? '').trim().isNotEmpty &&
            (summaryGovernorate ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: color.primary),
                const SizedBox(width: 8),
                Text(
                  '${summaryCity!}، ${summaryGovernorate!}',
                  style: text.bodySmall?.copyWith(
                    color: color.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Address + Location (Map) form section.
///
/// - Opens [AdvancedMapScreen] internally.
/// - Updates the provided controllers (and [onPositionChanged]).
/// - Optionally updates [LocationProvider] and refreshes nearby stores
///   (PostGIS path) via [StoreProvider.fetchNearbyStores].
class AddressLocationFormSection extends StatelessWidget {
  final MapUserType userType;
  final GlobalKey<FormState> formKey;

  /// When true (default), the internal [AddressFormSection] wraps its fields
  /// in a nested [Form]. Set to false when embedding inside an existing parent
  /// [Form] (to avoid nested forms).
  final bool wrapInForm;

  /// نوع النموذج - يحدد الحقول المعروضة
  final AddressFormType formType;

  final TextEditingController governorateController;
  final TextEditingController cityController;
  final TextEditingController areaController; // المنطقة/الحي
  final TextEditingController streetController;
  final TextEditingController landmarkController;

  // حقول إضافية للعناوين السكنية فقط
  final TextEditingController? labelController;
  final TextEditingController? buildingNumberController;
  final TextEditingController? floorNumberController;
  final TextEditingController? apartmentNumberController;
  final TextEditingController? notesController;

  final FocusNode governorateFocus;
  final FocusNode cityFocus;
  final FocusNode streetFocus;

  final LatLng? position;
  final ValueChanged<LatLng?> onPositionChanged;

  final ValueChanged<String>? onGovernorateChanged;
  final ValueChanged<String>? onCityChanged;
  final ValueChanged<String>? onAreaChanged;

  final List<String>? governorateOptions;
  final List<String>? cityOptions;
  final List<String>? areaOptions;

  final String? summaryCity;
  final String? summaryGovernorate;

  /// Controls what gets autofilled from map selection.
  ///
  /// Defaults to the simplest/safer behavior: fill governorate + city only.
  final bool autofillAllFieldsFromMap;

  /// If true, show an error hint when [position] is null.
  final bool requirePosition;
  final bool showMapPicker;

  /// If true, update [LocationProvider] with the picked location.
  final bool updateLocationProvider;

  /// If true and [updateLocationProvider] is true, also refresh nearby stores.
  /// (This is the client side of the PostGIS "nearby stores" flow.)
  final bool refreshNearbyStores;

  /// Max distance used when refreshing stores.
  final double maxDistanceKm;

  const AddressLocationFormSection({
    super.key,
    required this.userType,
    required this.formKey,
    this.wrapInForm = true,
    this.formType = AddressFormType.store,
    required this.governorateController,
    required this.cityController,
    required this.areaController,
    required this.streetController,
    required this.landmarkController,
    this.labelController,
    this.buildingNumberController,
    this.floorNumberController,
    this.apartmentNumberController,
    this.notesController,
    required this.governorateFocus,
    required this.cityFocus,
    required this.streetFocus,
    required this.position,
    required this.onPositionChanged,
    this.onGovernorateChanged,
    this.onCityChanged,
    this.onAreaChanged,
    this.governorateOptions,
    this.cityOptions,
    this.areaOptions,
    this.summaryCity,
    this.summaryGovernorate,
    this.autofillAllFieldsFromMap = false,
    this.requirePosition = false,
    this.showMapPicker = true,
    this.updateLocationProvider = false,
    this.refreshNearbyStores = false,
    this.maxDistanceKm = 15,
  });

  Future<void> _pickFromMap(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvancedMapScreen(
          userType: userType,
          actionType: MapActionType.pickLocation,
          initialPosition: position,
          onLocationSelectedDetails: (details) async {
            // 1) Update coordinates
            onPositionChanged(details.position);

            // 2) Autofill address fields (default: governorate + city only)
            final gov = (details.governorate ?? '').trim();
            final city = (details.city ?? '').trim();
            governorateController.text = gov;
            cityController.text = city;
            onGovernorateChanged?.call(gov);
            onCityChanged?.call(city);

            if (autofillAllFieldsFromMap) {
              final district = (details.district ?? '').trim();
              final street = (details.street ?? '').trim();
              if (district.isNotEmpty) areaController.text = district;
              if (street.isNotEmpty) streetController.text = street;
            }

            // 3) Update providers (PostGIS flow)
            if (updateLocationProvider) {
              try {
                final locationProvider = context.read<LocationProvider>();
                locationProvider.setLocation(
                  latitude: details.position.latitude,
                  longitude: details.position.longitude,
                  address: details.address,
                );

                if (refreshNearbyStores) {
                  final storeProvider = context.read<StoreProvider>();
                  await storeProvider.fetchNearbyStores(
                    latitude: details.position.latitude,
                    longitude: details.position.longitude,
                    maxDistanceKm: maxDistanceKm,
                  );
                }
              } catch (e) {
                AppLogger.error('❌ خطأ أثناء تحديث الموقع/المتاجر القريبة', e);
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AddressFormSection(
      formKey: formKey,
      wrapInForm: wrapInForm,
      formType: formType,
      governorateController: governorateController,
      cityController: cityController,
      areaController: areaController,
      streetController: streetController,
      landmarkController: landmarkController,
      labelController: labelController,
      buildingNumberController: buildingNumberController,
      floorNumberController: floorNumberController,
      apartmentNumberController: apartmentNumberController,
      notesController: notesController,
      governorateFocus: governorateFocus,
      cityFocus: cityFocus,
      streetFocus: streetFocus,
      onPickFromMap: () => _pickFromMap(context),
      position: position,
      requirePosition: requirePosition,
      showMapPicker: showMapPicker,
      onGovernorateChanged: onGovernorateChanged,
      onCityChanged: onCityChanged,
      onAreaChanged: onAreaChanged,
      governorateOptions: governorateOptions,
      cityOptions: cityOptions,
      areaOptions: areaOptions,
      summaryCity: summaryCity,
      summaryGovernorate: summaryGovernorate,
    );
  }
}
