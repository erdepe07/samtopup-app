import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeData? _data;
  String? _error;
  bool _loading = true;
  int _cat = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await app.repo.home();
      if (!mounted) return;
      setState(() {
        _data = d;
        _cat = 0;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<GameSummary> get _visible {
    final d = _data;
    if (d == null || d.categories.isEmpty) return const [];
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      return d.categories
          .expand((c) => c.games)
          .where((g) => g.name.toLowerCase().contains(q))
          .toList();
    }
    return d.categories[_cat.clamp(0, d.categories.length - 1)].games;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('assets/images/icon.png', width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'sam '),
              TextSpan(text: 'topup', style: TextStyle(color: p.primary)),
            ]), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _content(p)),
    );
  }

  Widget _content(Palette p) {
    final d = _data!;
    final width = MediaQuery.of(context).size.width;
    final cols = width >= 900 ? 6 : (width >= 600 ? 4 : 3);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (d.banners.isNotEmpty)
          SliverToBoxAdapter(child: _BannerSlider(images: d.banners)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Mau topup apa?',
                prefixIcon: Icon(Icons.search_rounded, color: p.muted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _query = ''),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(99),
                  borderSide: BorderSide(color: p.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(99),
                  borderSide: BorderSide(color: p.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(99),
                  borderSide: BorderSide(color: p.primary, width: 1.6),
                ),
              ),
            ),
          ),
        ),
        if (_query.isEmpty && d.categories.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: LayoutBuilder(builder: (context, box) {
                // Semua kategori selalu terlihat: 3 per baris di HP, lebih banyak di layar lebar.
                const gap = 8.0;
                final perRow = box.maxWidth >= 720 ? 6 : 3;
                final w = (box.maxWidth - gap * (perRow - 1)) / perRow;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < d.categories.length; i++)
                      SizedBox(
                        width: w,
                        child: _CategoryButton(
                          name: d.categories[i].name,
                          selected: i == _cat.clamp(0, d.categories.length - 1),
                          onTap: () => setState(() => _cat = i),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          sliver: SliverToBoxAdapter(
            child: SectionTitle(_query.isNotEmpty ? 'Hasil pencarian' : d.categories.isEmpty ? 'Produk' : d.categories[_cat.clamp(0, d.categories.length - 1)].name),
          ),
        ),
        if (_visible.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Text(_query.isNotEmpty ? 'Tidak ada produk.' : 'Belum ada produk di kategori ini.', style: TextStyle(color: p.muted))),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .74,
              ),
              itemCount: _visible.length,
              itemBuilder: (_, i) => _GameTile(game: _visible[i]),
            ),
          ),
      ],
    );
  }
}

IconData _categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('game')) return Icons.sports_esports_rounded;
  if (n.contains('pulsa')) return Icons.phone_android_rounded;
  if (n.contains('data') || n.contains('paket')) return Icons.wifi_rounded;
  if (n.contains('voucher')) return Icons.card_giftcard_rounded;
  if (n.contains('pln') || n.contains('listrik') || n.contains('token')) return Icons.bolt_rounded;
  if (n.contains('money') || n.contains('wallet') || n.contains('saldo')) return Icons.account_balance_wallet_rounded;
  return Icons.category_rounded;
}

class _CategoryButton extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryButton({required this.name, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Material(
      color: selected ? p.primary : p.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? p.primary : p.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_categoryIcon(name), size: 17, color: selected ? Colors.white : p.primary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : p.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final GameSummary game;
  const _GameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GameScreen(slug: game.slug, title: game.name)),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: RemoteImage(url: game.image, label: game.name, radius: 12),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Text(
                game.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerSlider extends StatefulWidget {
  final List<String> images;
  const _BannerSlider({required this.images});

  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;
  // Rasio asli banner (lebar/tinggi). Dipakai agar gambar tampil utuh, tidak terpotong.
  double _ratio = 1920 / 600;

  void _measureFirst() {
    final provider = CachedNetworkImageProvider(widget.images.first);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble(), h = info.image.height.toDouble();
      if (mounted && h > 0) setState(() => _ratio = w / h);
      stream.removeListener(l);
    }, onError: (_, __) => stream.removeListener(l));
    stream.addListener(l);
  }

  @override
  void initState() {
    super.initState();
    _measureFirst();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!_controller.hasClients) return;
        final next = (_page + 1) % widget.images.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      children: [
        AspectRatio(
          aspectRatio: _ratio, // ikut rasio asli gambar -> tidak terpotong kanan/kiri
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => RemoteImage(
              url: widget.images[i],
              label: 'S',
              radius: 0,
              fit: BoxFit.contain, // tampil utuh; beda rasio antar banner tidak dipotong
            ),
          ),
        ),
        if (widget.images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.images.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? p.primary : p.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}