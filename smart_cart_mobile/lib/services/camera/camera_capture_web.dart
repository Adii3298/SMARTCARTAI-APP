import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

class CameraCaptureService {
  static Future<Uint8List?> capturePhotoFromLiveCamera() async {
    final completer = Completer<Uint8List?>();

    html.MediaStream? stream;
    try {
      stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      });
    } catch (e) {
      throw Exception('Camera access denied or webcam not found: $e');
    }

    if (stream == null) {
      throw Exception('Could not access live camera.');
    }

    // Modal overlay container
    final overlay = html.DivElement()
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100vw'
      ..style.height = '100vh'
      ..style.backgroundColor = 'rgba(10, 15, 29, 0.96)'
      ..style.zIndex = '999999'
      ..style.display = 'flex'
      ..style.flexDirection = 'column'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'space-between'
      ..style.padding = '14px'
      ..style.boxSizing = 'border-box'
      ..style.fontFamily = 'system-ui, -apple-system, sans-serif';

    // Header bar
    final header = html.DivElement()
      ..style.width = '100%'
      ..style.maxWidth = '550px'
      ..style.display = 'flex'
      ..style.justifyContent = 'space-between'
      ..style.alignItems = 'center'
      ..style.color = '#ffffff';

    final title = html.DivElement()
      ..setInnerHtml(
        '<strong style="font-size:16px;color:#34d399;">📸 Live Scanner - Grocery Note</strong>'
        '<div style="font-size:11px;color:#94a3b8;margin-top:2px;">Hold note 10-15 cm close to fill the box</div>'
      );

    final closeBtn = html.ButtonElement()
      ..innerText = '✕ Close'
      ..style.backgroundColor = 'rgba(255,255,255,0.15)'
      ..style.color = '#ffffff'
      ..style.border = 'none'
      ..style.padding = '8px 16px'
      ..style.borderRadius = '20px'
      ..style.cursor = 'pointer'
      ..style.fontSize = '13px'
      ..style.fontWeight = 'bold';

    header.children.addAll([title, closeBtn]);

    // Video container with target viewfinder
    final videoWrapper = html.DivElement()
      ..style.position = 'relative'
      ..style.width = '100%'
      ..style.maxWidth = '520px'
      ..style.flex = '1'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.overflow = 'hidden'
      ..style.borderRadius = '20px'
      ..style.margin = '12px 0'
      ..style.backgroundColor = '#000000'
      ..style.boxShadow = '0 10px 30px rgba(0,0,0,0.5)';

    final video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..srcObject = stream
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.borderRadius = '20px';

    // Scanner viewfinder frame (focused card size)
    final viewfinder = html.DivElement()
      ..style.position = 'absolute'
      ..style.top = '15%'
      ..style.left = '10%'
      ..style.width = '80%'
      ..style.height = '68%'
      ..style.border = '3px solid #10b981'
      ..style.borderRadius = '18px'
      ..style.boxShadow = '0 0 0 9999px rgba(0, 0, 0, 0.55)'
      ..style.pointerEvents = 'none'
      ..style.display = 'flex'
      ..style.flexDirection = 'column'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'flex-end'
      ..style.paddingBottom = '14px'
      ..style.boxSizing = 'border-box';

    final viewfinderHint = html.DivElement()
      ..innerText = '📄 Hold paper close so writing fills this frame'
      ..style.backgroundColor = 'rgba(0,0,0,0.75)'
      ..style.color = '#34d399'
      ..style.padding = '8px 14px'
      ..style.borderRadius = '14px'
      ..style.fontSize = '12px'
      ..style.fontWeight = 'bold'
      ..style.textAlign = 'center'
      ..style.letterSpacing = '0.3px';

    viewfinder.children.add(viewfinderHint);

    // Review Preview Image (shown immediately after capture)
    final previewImg = html.ImageElement()
      ..style.position = 'absolute'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.display = 'none'
      ..style.backgroundColor = '#0b0f19'
      ..style.borderRadius = '20px'
      ..style.zIndex = '5';

    videoWrapper.children.addAll([video, viewfinder, previewImg]);

    // Bottom controls
    final controls = html.DivElement()
      ..style.display = 'flex'
      ..style.flexDirection = 'column'
      ..style.alignItems = 'center'
      ..style.width = '100%'
      ..style.maxWidth = '520px'
      ..style.paddingBottom = '10px';

    final captureBtn = html.ButtonElement()
      ..setInnerHtml(
        '<div style="display:flex;align-items:center;gap:10px;font-size:15px;font-weight:900;">'
        '<span style="font-size:18px;">📸</span> <span>CAPTURE PHOTO NOW</span>'
        '</div>'
      )
      ..style.backgroundColor = '#059669'
      ..style.color = '#ffffff'
      ..style.border = 'none'
      ..style.padding = '14px 32px'
      ..style.borderRadius = '30px'
      ..style.cursor = 'pointer'
      ..style.boxShadow = '0 6px 20px rgba(5, 150, 105, 0.5)'
      ..style.transition = 'transform 0.1s ease';

    // Review action buttons (shown after capture)
    final reviewControls = html.DivElement()
      ..style.display = 'none'
      ..style.flexDirection = 'row'
      ..style.gap = '12px'
      ..style.width = '100%'
      ..style.justifyContent = 'center';

    final retakeBtn = html.ButtonElement()
      ..setInnerHtml('<span>🔄 Retake</span>')
      ..style.backgroundColor = 'rgba(255,255,255,0.18)'
      ..style.color = '#ffffff'
      ..style.border = '1px solid rgba(255,255,255,0.3)'
      ..style.padding = '12px 24px'
      ..style.borderRadius = '30px'
      ..style.cursor = 'pointer'
      ..style.fontSize = '14px'
      ..style.fontWeight = 'bold';

    final confirmBtn = html.ButtonElement()
      ..setInnerHtml('<span>⚡ Fast Scan Photo</span>')
      ..style.backgroundColor = '#059669'
      ..style.color = '#ffffff'
      ..style.border = 'none'
      ..style.padding = '12px 28px'
      ..style.borderRadius = '30px'
      ..style.cursor = 'pointer'
      ..style.fontSize = '14px'
      ..style.fontWeight = 'bold'
      ..style.boxShadow = '0 6px 20px rgba(5, 150, 105, 0.5)';

    reviewControls.children.addAll([retakeBtn, confirmBtn]);
    controls.children.addAll([captureBtn, reviewControls]);

    overlay.children.addAll([header, videoWrapper, controls]);
    html.document.body?.children.add(overlay);

    Uint8List? capturedBytes;

    void cleanup() {
      try {
        stream?.getTracks().forEach((track) => track.stop());
      } catch (_) {}
      overlay.remove();
    }

    closeBtn.onClick.listen((_) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    });

    retakeBtn.onClick.listen((_) {
      previewImg.style.display = 'none';
      viewfinder.style.display = 'flex';
      video.play();
      reviewControls.style.display = 'none';
      captureBtn.style.display = 'block';
    });

    confirmBtn.onClick.listen((_) {
      cleanup();
      if (!completer.isCompleted) completer.complete(capturedBytes);
    });

    captureBtn.onClick.listen((_) {
      try {
        final streamW = video.videoWidth > 0 ? video.videoWidth : 1280;
        final streamH = video.videoHeight > 0 ? video.videoHeight : 720;

        final vWrapRect = videoWrapper.getBoundingClientRect();
        final vfRect = viewfinder.getBoundingClientRect();

        // Object-fit: cover exact crop coordinate translation
        final scale = math.max(
          streamW / math.max(vWrapRect.width, 1),
          streamH / math.max(vWrapRect.height, 1),
        );
        final visW = vWrapRect.width * scale;
        final visH = vWrapRect.height * scale;
        final offsetX = (streamW - visW) / 2.0;
        final offsetY = (streamH - visH) / 2.0;

        final vfLeft = vfRect.left - vWrapRect.left;
        final vfTop = vfRect.top - vWrapRect.top;

        int cropX = (offsetX + (vfLeft * scale)).round();
        int cropY = (offsetY + (vfTop * scale)).round();
        int cropW = (vfRect.width * scale).round();
        int cropH = (vfRect.height * scale).round();

        // Clamp to physical video sensor boundaries
        if (cropX < 0) { cropW += cropX; cropX = 0; }
        if (cropY < 0) { cropH += cropY; cropY = 0; }
        if (cropX + cropW > streamW) cropW = streamW - cropX;
        if (cropY + cropH > streamH) cropH = streamH - cropY;

        if (cropW < 50) { cropX = 0; cropW = streamW; }
        if (cropH < 50) { cropY = 0; cropH = streamH; }

        // Optimize canvas resolution: cap max width at 900 for fast upload and sub-second OCR
        int targetCanvasW = cropW;
        int targetCanvasH = cropH;
        if (targetCanvasW > 900) {
          double factor = 900.0 / targetCanvasW;
          targetCanvasW = 900;
          targetCanvasH = (targetCanvasH * factor).round();
        }

        final canvas = html.CanvasElement(width: targetCanvasW, height: targetCanvasH);
        final ctx = canvas.context2D;

        // Draw cropped and scaled viewfinder region
        ctx.drawImageScaledFromSource(
          video,
          cropX,
          cropY,
          cropW,
          cropH,
          0,
          0,
          targetCanvasW,
          targetCanvasH,
        );

        final dataUrl = canvas.toDataUrl('image/jpeg', 0.88);
        final base64String = dataUrl.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
        capturedBytes = base64Decode(base64String);

        // Display captured preview so user can review before scanning
        previewImg.src = dataUrl;
        previewImg.style.display = 'block';
        viewfinder.style.display = 'none';
        video.pause();

        captureBtn.style.display = 'none';
        reviewControls.style.display = 'flex';
      } catch (err) {
        cleanup();
        if (!completer.isCompleted) completer.completeError('Capture error: $err');
      }
    });

    return completer.future;
  }
}
