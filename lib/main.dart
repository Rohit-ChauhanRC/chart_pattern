import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: ImageGalleryPage(),
    );
  }
}

class ImageController extends GetxController {
  var imageList = <Map<String, dynamic>>[].obs;
  late Database database;

  @override
  void onInit() {
    super.onInit();
    initDatabase();
  }

  Future<void> initDatabase() async {
    database = await openDatabase(
      join(await getDatabasesPath(), 'images.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE images(id INTEGER PRIMARY KEY, path TEXT)',
        );
      },
      version: 1,
    );
    fetchImages();
  }

  Future<void> fetchImages() async {
    final List<Map<String, dynamic>> maps = await database.query('images');
    imageList.assignAll(maps);
  }

  Future<void> addImage(String imagePath) async {
    await database.insert('images', {'path': imagePath});
    fetchImages();
  }

  Future<void> updateImage(int id, String newPath) async {
    await database.update('images', {'path': newPath},
        where: 'id = ?', whereArgs: [id]);
    fetchImages();
  }

  Future<void> deleteImage(int id) async {
    await database.delete('images', where: 'id = ?', whereArgs: [id]);
    fetchImages();
  }

  Future<String> saveImageToLocal(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.png';
    final savedImage = await imageFile.copy(path);
    return savedImage.path;
  }

  void showZoomedImage(String imagePath) {
    Get.to(() => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(imagePath)),
            ),
          ),
        ));
  }
}

class ImageGalleryPage extends StatelessWidget {
  final ImageController controller = Get.put(ImageController());
  final ImagePicker picker = ImagePicker();

  ImageGalleryPage({super.key});

  void pickImage(ImageSource source) async {
    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      String savedPath =
          await controller.saveImageToLocal(File(pickedFile.path));
      controller.addImage(savedPath);
      Get.back();
    }
  }

  void updateImage(int id) async {
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      String newPath = await controller.saveImageToLocal(File(pickedFile.path));
      controller.updateImage(id, newPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chart Pattern')),
      body: Obx(() => controller.imageList.isEmpty
          ? Center(child: Text('No images found'))
          : GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: controller.imageList.length,
              itemBuilder: (context, index) {
                final image = controller.imageList[index];
                return GestureDetector(
                  onTap: () => controller.showZoomedImage(image['path']),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child:
                            Image.file(File(image['path']), fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        child: Column(
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => updateImage(image['id']),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  controller.deleteImage(image['id']),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            )),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add_a_photo),
        onPressed: () => Get.defaultDialog(
          title: 'Choose Image Source',
          content: Column(
            children: [
              ElevatedButton(
                  onPressed: () => pickImage(ImageSource.camera),
                  child: Text('Camera')),
              ElevatedButton(
                  onPressed: () => pickImage(ImageSource.gallery),
                  child: Text('Gallery')),
            ],
          ),
        ),
      ),
    );
  }
}
