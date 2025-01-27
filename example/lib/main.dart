import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:background_remover/background_remover.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Background Remover Demo',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemPurple,
      ),
      home: const MyHomePage(title: 'Background Remover'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Uint8List? image;
  bool isLoading = false;

  Future<Uint8List?> prepareImageForML(Uint8List originalBytes) async {
    try {
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) return null;

      final resized = decoded.width > 1024 || decoded.height > 1024
          ? img.copyResize(
              decoded,
              width: decoded.width > decoded.height ? 1024 : null,
              height: decoded.height >= decoded.width ? 1024 : null,
            )
          : decoded;

      return Uint8List.fromList(img.encodePng(resized));
    } catch (e) {
      debugPrint('Error preparing image: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        image = null;
        isLoading = true;
      });

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        final originalBytes = await pickedFile.readAsBytes();
        final preparedImage = await prepareImageForML(originalBytes);

        if (preparedImage == null) {
          debugPrint('Failed to prepare image');
          return;
        }

        try {
          // Solo procesamos el fondo de la imagen, sin ML Kit
          final processedImage =
              await removeBackground(imageBytes: preparedImage);

          if (mounted) {
            setState(() {
              image = processedImage;
            });
          }
        } catch (e) {
          debugPrint('Processing error: $e');
          if (mounted) {
            setState(() => image = originalBytes);
          }
        }
      }
    } catch (e) {
      debugPrint('Image picking error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (isLoading)
              const Expanded(child: CupertinoActivityIndicator())
            else if (image != null)
              Expanded(
                child: ImageEditorWidget(
                  imageBytes: image!,
                  onImageChanged: (newImage) {
                    setState(() => image = newImage);
                  },
                  showSaveButton: false,
                  initialBrushSize: 20,
                  minBrushSize: 5,
                  maxBrushSize: 50,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoButton.filled(
                onPressed: _pickImage,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.photo),
                    SizedBox(width: 8),
                    Text('Seleccionar Imagen'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
