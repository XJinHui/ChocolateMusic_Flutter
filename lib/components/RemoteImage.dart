import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

const Map<String, String> _browserImageHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
  'Referer': 'http://music.163.com/',
  'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
};

/// 项目封面图常用的外阴影样式，调用处直接传 `boxShadow: kImageBoxShadow`。
const List<BoxShadow> kImageBoxShadow = [
  BoxShadow(color: Color(0x3D000000), blurRadius: 12, offset: Offset(0, 4)),
];

/// Displays remote artwork and works around the User-Agent restriction used by
/// the NetEase image CDN. Other providers continue to use Flutter's native
/// image pipeline.
class RemoteImage extends StatefulWidget {
  const RemoteImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.headers,
    this.errorBuilder,
    this.fallbackAsset = 'assets/images/app_photo.png',
    this.fallbackBuilder,
    this.cacheWidth,
    this.cacheHeight,
    this.borderRadius,
    this.boxShadow,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Map<String, String>? headers;
  final ImageErrorWidgetBuilder? errorBuilder;
  final String fallbackAsset;
  final Widget Function(BuildContext context, Object error, StackTrace? stack)?
  fallbackBuilder;

  /// 解码尺寸上限（逻辑像素 × 设备像素比最合适）。
  ///
  /// 列表里的封面只有 60×60，但源图往往 500×500 以上，
  /// 按原尺寸解码会白白占用几十倍内存。传入该值后 Flutter 会在解码阶段
  /// 就把图片缩放到目标大小。不传则保持原来的按原图解码行为。
  final int? cacheWidth;
  final int? cacheHeight;

  /// 圆角半径（逻辑像素）。组件内部采用"外层画阴影、内层裁剪"的结构，
  /// 保证阴影不会被裁剪层切掉。传 null 则不裁剪圆角。
  final double? borderRadius;

  /// 图片外阴影，跟随 [borderRadius] 的圆角形状绘制。
  /// 未设置 [borderRadius] 时按直角矩形绘制。传 null 则无阴影。
  final List<BoxShadow>? boxShadow;

  @override
  State<RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<RemoteImage> {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  static final Map<String, Future<Uint8List>> _neteaseImageCache = {};
  late Future<Uint8List>? _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _neteaseImageFuture(widget.url);
  }

  @override
  void didUpdateWidget(covariant RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _imageFuture = _neteaseImageFuture(widget.url);
    }
  }

  bool get _isNetEaseImage {
    final Uri? uri = Uri.tryParse(widget.url);
    final String host = uri?.host.toLowerCase() ?? '';
    return host == 'music.126.net' || host.endsWith('.music.126.net');
  }

  Future<Uint8List>? _neteaseImageFuture(String url) {
    if (!_isNetEaseHost(url)) {
      return null;
    }
    return _neteaseImageCache.putIfAbsent(url, () async {
      final Response<List<int>> response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: _browserImageHeaders,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      final List<int>? bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('网易云封面返回空数据');
      }
      return Uint8List.fromList(bytes);
    });
  }

  static bool _isNetEaseHost(String url) {
    final Uri? uri = Uri.tryParse(url);
    final String host = uri?.host.toLowerCase() ?? '';
    return host == 'music.126.net' || host.endsWith('.music.126.net');
  }

  Widget _fallback(Object error, [StackTrace? stack]) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error, stack ?? StackTrace.current);
    }
    final Widget Function(BuildContext, Object, StackTrace?)? builder =
        widget.fallbackBuilder;
    if (builder != null) {
      return builder(context, error, stack);
    }
    return Image.asset(
      widget.fallbackAsset,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }

  Widget _nativeImage() {
    return Image.network(
      widget.url,
      headers: widget.headers ?? _browserImageHeaders,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      errorBuilder: (context, error, stack) => _fallback(error, stack),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _decorate(_imageBody());
  }

  /// 外层 Container 负责画阴影，内层 ClipRRect 负责裁剪圆角。
  /// 阴影画在裁剪层外面才不会被一起裁掉。
  Widget _decorate(Widget child) {
    final double? radius = widget.borderRadius;
    if (radius == null && widget.boxShadow == null) {
      return child;
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius == null ? null : BorderRadius.circular(radius),
        boxShadow: widget.boxShadow,
      ),
      child: radius == null
          ? child
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: child,
            ),
    );
  }

  Widget _imageBody() {
    if (!_isNetEaseImage) {
      return _nativeImage();
    }

    final Future<Uint8List>? imageFuture = _imageFuture;
    if (imageFuture == null) {
      return _fallback(StateError('网易云封面地址无效'));
    }

    return FutureBuilder<Uint8List>(
      future: imageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            cacheWidth: widget.cacheWidth,
            cacheHeight: widget.cacheHeight,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => _fallback(error, stack),
          );
        }
        if (snapshot.hasError) {
          return _fallback(snapshot.error!, snapshot.stackTrace);
        }
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}
