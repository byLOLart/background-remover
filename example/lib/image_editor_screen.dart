import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:background_remover/background_remover.dart';

class ImageEditorScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const ImageEditorScreen({super.key, required this.imageBytes});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  late ImageEditor _imageEditor;
  double _brushSize = 30.0;
  bool _isDragging = false;
  bool _isErasing = true;
  bool _showBrushPreview = false;
  Offset? _currentOffset;
  final ValueNotifier<Uint8List?> _imageNotifier =
      ValueNotifier<Uint8List?>(null);

  @override
  void initState() {
    super.initState();
    _imageEditor = ImageEditor();
    _initializeEditor();
  }

  Future<void> _initializeEditor() async {
    await _imageEditor.initialize(widget.imageBytes);
    final currentImage = await _imageEditor.getCurrentImage();
    _imageNotifier.value = currentImage;
  }

  void _handlePanStart(DragStartDetails details, BoxConstraints constraints) {
    _isDragging = true;
    _showBrushPreview = true;
    _updateOffset(details.globalPosition, constraints);
  }

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!_isDragging) return;
    _updateOffset(details.globalPosition, constraints);
    _processRegion();
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDragging = false;
    _showBrushPreview = false;
    _currentOffset = null;
    setState(() {});
  }

  void _updateOffset(Offset globalPosition, BoxConstraints constraints) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(globalPosition);
    final Size imageSize = Size(constraints.maxWidth, constraints.maxHeight);

    setState(() {
      _currentOffset = Offset(
        (localPosition.dx / imageSize.width).clamp(0.0, 1.0),
        (localPosition.dy / imageSize.height).clamp(0.0, 1.0),
      );
    });
  }

  Future<void> _processRegion() async {
    if (_currentOffset == null) return;

    final result = _isErasing
        ? await _imageEditor.eraseRegion(_currentOffset!, _brushSize)
        : await _imageEditor.restoreRegion(_currentOffset!, _brushSize);

    if (result != null) {
      _imageNotifier.value = result;
    }
  }

  Future<void> _handleUndo() async {
    final undoImage = await _imageEditor.undo();
    if (undoImage != null) {
      _imageNotifier.value = undoImage;
    }
  }

  Future<void> _handleRedo() async {
    final redoImage = await _imageEditor.redo();
    if (redoImage != null) {
      _imageNotifier.value = redoImage;
    }
  }

  Future<void> _handleSave() async {
    if (_imageEditor.hasChanges) {
      final currentImage = await _imageEditor.getCurrentImage();
      if (currentImage != null) {
        Navigator.pop(context, currentImage);
      }
    } else {
      Navigator.pop(context);
    }
  }

  Widget _buildBrushPreview(BoxConstraints constraints) {
    if (!_showBrushPreview || _currentOffset == null)
      return const SizedBox.shrink();

    final double x = _currentOffset!.dx * constraints.maxWidth;
    final double y = _currentOffset!.dy * constraints.maxHeight;

    return Positioned(
      left: x - _brushSize / 2,
      top: y - _brushSize / 2,
      child: Container(
        width: _brushSize,
        height: _brushSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _isErasing
                ? CupertinoColors.systemRed
                : CupertinoColors.systemGreen,
            width: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_imageEditor.hasChanges) {
          final shouldSave = await showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('¿Guardar cambios?'),
              content: const Text('¿Deseas guardar los cambios realizados?'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Descartar'),
                  onPressed: () => Navigator.pop(context, false),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('Guardar'),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          );
          if (shouldSave == true) {
            await _handleSave();
          }
        }
        return true;
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Editor de Imagen'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _handleUndo,
                child: const Icon(CupertinoIcons.arrow_counterclockwise),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _handleRedo,
                child: const Icon(CupertinoIcons.arrow_clockwise),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _handleSave,
                child: const Icon(CupertinoIcons.check_mark_circled_solid),
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        GestureDetector(
                          onPanStart: (details) =>
                              _handlePanStart(details, constraints),
                          onPanUpdate: (details) =>
                              _handlePanUpdate(details, constraints),
                          onPanEnd: _handlePanEnd,
                          child: Container(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            color: CupertinoColors.systemBackground,
                            child: ValueListenableBuilder<Uint8List?>(
                              valueListenable: _imageNotifier,
                              builder: (context, imageData, child) {
                                if (imageData == null) {
                                  return const CupertinoActivityIndicator();
                                }
                                return Image.memory(
                                  imageData,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                );
                              },
                            ),
                          ),
                        ),
                        _buildBrushPreview(constraints),
                      ],
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  border: Border(
                    top: BorderSide(
                      color: CupertinoColors.systemGrey4,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _isErasing = !_isErasing;
                        });
                      },
                      child: Icon(
                        _isErasing
                            ? CupertinoIcons.scissors
                            : CupertinoIcons.paintbrush,
                        color: _isErasing
                            ? CupertinoColors.systemRed
                            : CupertinoColors.systemGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.circle, size: 12),
                          Expanded(
                            child: CupertinoSlider(
                              value: _brushSize,
                              min: 10.0,
                              max: 100.0,
                              onChanged: (value) {
                                setState(() {
                                  _brushSize = value;
                                });
                              },
                            ),
                          ),
                          const Icon(CupertinoIcons.circle, size: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _imageEditor.dispose();
    _imageNotifier.dispose();
    super.dispose();
  }
}
