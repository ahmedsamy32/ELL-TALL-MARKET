// screens/admin/manage_banners_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/banner_model.dart';
import '../../providers/banner_provider.dart';

class ManageBannersScreen extends StatefulWidget {
  const ManageBannersScreen({super.key});

  @override
  State<ManageBannersScreen> createState() => _ManageBannersScreenState();
}

class _ManageBannersScreenState extends State<ManageBannersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
            (_) => Provider.of<BannerProvider>(context, listen: false).fetchBanners());
  }

  @override
  Widget build(BuildContext context) {
    final bannerProvider = Provider.of<BannerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة البانرات'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddBannerDialog(context, bannerProvider),
          )
        ],
      ),
      body: bannerProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : bannerProvider.banners.isEmpty
          ? const Center(child: Text('لا يوجد بانرات'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bannerProvider.banners.length,
        itemBuilder: (context, index) {
          final banner = bannerProvider.banners[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Image.network(
                banner.imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.image_not_supported),
              ),
              title: Text(banner.title),
              subtitle: Text(banner.isActive ? 'نشط' : 'غير نشط'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () =>
                          _showEditBannerDialog(context, bannerProvider, banner)),
                  IconButton(
                      icon: Icon(
                          banner.isActive
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: banner.isActive ? Colors.red : Colors.green),
                      onPressed: () =>
                          bannerProvider.toggleBannerStatus(banner)),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          bannerProvider.deleteBanner(banner.id)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddBannerDialog(BuildContext context, BannerProvider provider) {
    final titleController = TextEditingController();
    final imageUrlController = TextEditingController();

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('إضافة بانر جديد'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'عنوان البانر'),
                ),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(labelText: 'رابط الصورة'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty &&
                      imageUrlController.text.isNotEmpty) {
                    provider.addBanner(BannerModel(
                        id: '',
                        title: titleController.text,
                        imageUrl: imageUrlController.text));
                    Navigator.pop(context);
                  }
                },
                child: const Text('حفظ')),
          ],
        ));
  }

  void _showEditBannerDialog(
      BuildContext context, BannerProvider provider, BannerModel banner) {
    final titleController = TextEditingController(text: banner.title);
    final imageUrlController = TextEditingController(text: banner.imageUrl);

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تعديل البانر'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'عنوان البانر'),
                ),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(labelText: 'رابط الصورة'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () {
                  provider.updateBanner(BannerModel(
                      id: banner.id,
                      title: titleController.text,
                      imageUrl: imageUrlController.text,
                      isActive: banner.isActive));
                  Navigator.pop(context);
                },
                child: const Text('تحديث')),
          ],
        ));
  }
}
