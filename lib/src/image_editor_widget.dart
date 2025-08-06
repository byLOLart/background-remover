import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'image_editor.dart';

class ImageEditorWidget extends StatefulWidget {
  /// La imagen a editar
  final Uint8List imageBytes;

  /// Callback cuando la imagen es modificada
  final ValueChanged<Uint8List>? onImageChanged;

  /// Tamaño inicial del pincel
  final double initialBrushSize;

  /// Tamaño mínimo del pincel
  final double minBrushSize;

  /// Tamaño máximo del pincel
  final double maxBrushSize;

  /// Color del pincel para el modo borrador
  final Color eraserColor;

  /// Color del pincel para el modo restauración
  final Color restoreColor;

  /// Si se debe mostrar el botón de guardado
  final bool showSaveButton;

  /// Si se debe mostrar los botones de deshacer/rehacer
  final bool showUndoRedo;

  /// Color de fondo del editor
  final Color backgroundColor;

  const ImageEditorWidget({
    super.key,
    required this.imageBytes,
    this.onImageChanged,
    this.initialBrushSize = 30.0,
    this.minBrushSize = 10.0,
    this.maxBrushSize = 100.0,
    this.eraserColor = CupertinoColors.systemRed,
    this.restoreColor = CupertinoColors.systemGreen,
    this.showSaveButton = true,
    this.showUndoRedo = true,
    this.backgroundColor = CupertinoColors.systemBackground,
  });

  @override
  State<ImageEditorWidget> createState() => _ImageEditorWidgetState();
}

class _ImageEditorWidgetState extends State<ImageEditorWidget> {
  late ImageEditor _imageEditor;
  late double _brushSize;
  bool _isDragging = false;
  bool _isErasing = true;
  bool _showBrushPreview = false;
  Offset? _currentOffset;
  final ValueNotifier<Uint8List?> _imageNotifier =
      ValueNotifier<Uint8List?>(null);

  @override
  void initState() {
    super.initState();
    _brushSize = widget.initialBrushSize;
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
      widget.onImageChanged?.call(result);
    }
  }

  Widget _buildBrushPreview(BoxConstraints constraints) {
    if (!_showBrushPreview || _currentOffset == null) {
      return const SizedBox.shrink();
    }

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
            color: _isErasing ? widget.eraserColor : widget.restoreColor,
            width: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showUndoRedo)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final undoImage = await _imageEditor.undo();
                  if (undoImage != null) {
                    _imageNotifier.value = undoImage;
                    widget.onImageChanged?.call(undoImage);
                  }
                },
                child: const Icon(CupertinoIcons.arrow_counterclockwise),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final redoImage = await _imageEditor.redo();
                  if (redoImage != null) {
                    _imageNotifier.value = redoImage;
                    widget.onImageChanged?.call(redoImage);
                  }
                },
                child: const Icon(CupertinoIcons.arrow_clockwise),
              ),
            ],
          ),
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
                      color: widget.backgroundColor,
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
            color: widget.backgroundColor,
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
                  color: _isErasing ? widget.eraserColor : widget.restoreColor,
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
                        min: widget.minBrushSize,
                        max: widget.maxBrushSize,
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
    );
  }

  @override
  void dispose() {
    _imageEditor.dispose();
    _imageNotifier.dispose();
    super.dispose();
  }
}
