import 'dart:async';
import 'package:camera/camera.dart';

enum CameraStateStatus {
  uninitialized,
  initializing,
  ready,
  error,
}

class CameraService {
  static CameraService? _instance;
  static CameraService get instance => _instance ??= CameraService._();

  CameraService._();

  List<CameraDescription> _availableCameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  CameraStateStatus _status = CameraStateStatus.uninitialized;
  String? _errorMessage;

  List<CameraDescription> get cameras => _availableCameras;
  CameraController? get controller => _controller;
  bool get isReady => _status == CameraStateStatus.ready && _controller != null && _controller!.value.isInitialized;
  CameraStateStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isFrontCamera =>
      _availableCameras.isNotEmpty &&
      _selectedCameraIndex < _availableCameras.length &&
      _availableCameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front;

  Future<bool> initialize({bool preferFront = true}) async {
    try {
      _status = CameraStateStatus.initializing;
      _errorMessage = null;

      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        _status = CameraStateStatus.error;
        _errorMessage = 'No camera hardware found on this device.';
        return false;
      }

      // Pick front or back camera
      _selectedCameraIndex = _availableCameras.indexWhere(
        (c) => preferFront
            ? c.lensDirection == CameraLensDirection.front
            : c.lensDirection == CameraLensDirection.back,
      );

      if (_selectedCameraIndex < 0) {
        _selectedCameraIndex = 0;
      }

      await _initController(_availableCameras[_selectedCameraIndex]);
      _status = CameraStateStatus.ready;
      return true;
    } catch (e) {
      _status = CameraStateStatus.error;
      _errorMessage = 'Camera initialization failed: $e';
      return false;
    }
  }

  Future<void> _initController(CameraDescription camera) async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
  }

  Future<bool> switchCamera() async {
    if (_availableCameras.length < 2) return false;

    try {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
      await _initController(_availableCameras[_selectedCameraIndex]);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to switch camera: $e';
      return false;
    }
  }

  Future<void> dispose() async {
    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }
      _status = CameraStateStatus.uninitialized;
    } catch (_) {}
  }
}
