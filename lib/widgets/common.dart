import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Gambar dari server; bila kosong/gagal tampil kotak berinisial.
class RemoteImage extends StatelessWidget {
  final String url;
  final String label;
  final double? width, height;
  final double radius;
  final BoxFit fit;

  const RemoteImage({
    super.key,
    required this.url,
    this.label = '',
    this.width,
    this.height,
    this.radius = 14,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget placeholder() => Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: [p.primary.withOpacity(.85), const Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Text(
            label.isEmpty ? '' : String.fromCharCode(label.runes.first).toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28),
          ),
        );

    if (url.isEmpty) return placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => Container(width: width, height: height, color: p.primarySoft),
        errorWidget: (_, __, ___) => placeholder(),
      ),
    );
  }
}

/// Kartu putih berborder tipis, gaya web.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Material(
      color: selected ? p.primarySoft : p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? p.primary : p.border, width: selected ? 1.6 : 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Judul bagian dengan garis biru kecil di bawahnya.
class SectionTitle extends StatelessWidget {
  final String text;
  final String? step;
  const SectionTitle(this.text, {super.key, this.step});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (step != null) ...[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
              child: Text(step!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(99)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  static (String, Color) info(String s) {
    switch (s) {
      case 'success':
        return ('Berhasil', const Color(0xFF16A34A));
      case 'processing':
        return ('Diproses', const Color(0xFF2563EB));
      case 'failed':
        return ('Gagal', const Color(0xFFDC2626));
      case 'expired':
        return ('Kedaluwarsa', const Color(0xFF6B7280));
      default:
        return ('Menunggu Pembayaran', const Color(0xFFD97706));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = info(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: p.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
            const SizedBox(height: 16),
            SizedBox(
              width: 180,
              child: ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ),
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}
