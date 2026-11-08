import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MusicApp());

const violet = Color(0xFF7C4DFF);
const cyan = Color(0xFF00E5FF);
const pink = Color(0xFFFF4081);
const accent = LinearGradient(colors: [violet, cyan]);

// ---------------- Vibes (mood presets for the background) ----------------
enum VibeKind { orbs, stars, rain, waves, embers }

class Vibe {
  final String name;
  final IconData icon;
  final VibeKind kind;
  final Color a, b;
  final List<Color> bg;
  const Vibe(this.name, this.icon, this.kind, this.a, this.b, this.bg);
}

const vibes = [
  Vibe('Neon Night', Icons.nightlife, VibeKind.orbs, Color(0xFF7C4DFF),
      Color(0xFF00E5FF), [Color(0xFF1A0B3D), Color(0xFF0B0A1E), Color(0xFF062C3A)]),
  Vibe('Midnight', Icons.nights_stay, VibeKind.stars, Color(0xFF5C6BC0),
      Color(0xFFB39DDB), [Color(0xFF050818), Color(0xFF0D1233), Color(0xFF1A1347)]),
  Vibe('Sunset', Icons.wb_twilight, VibeKind.embers, Color(0xFFFF7043),
      Color(0xFFFFC107), [Color(0xFF3D0C2B), Color(0xFF7A2A1F), Color(0xFF1A0B14)]),
  Vibe('Ocean', Icons.waves, VibeKind.waves, Color(0xFF00B0FF),
      Color(0xFF1DE9B6), [Color(0xFF04202F), Color(0xFF06314A), Color(0xFF021018)]),
  Vibe('Rainy Day', Icons.grain, VibeKind.rain, Color(0xFF90A4AE),
      Color(0xFF4FC3F7), [Color(0xFF151B24), Color(0xFF232E3B), Color(0xFF0C1016)]),
  Vibe('Party', Icons.celebration, VibeKind.orbs, Color(0xFFFF4081),
      Color(0xFFD500F9), [Color(0xFF2A0A33), Color(0xFF0B0A1E), Color(0xFF3A0A22)]),
];

int vibeFor(String title) =>
    title.codeUnits.fold<int>(0, (a, b) => a + b) % vibes.length;

// ---------------- Data ----------------
class Song {
  final String title, artist, album;
  int seconds;
  final Color c1, c2;
  int vibe;
  final Uint8List? bytes; // not null = real uploaded audio
  final String mime;
  Song(this.title, this.artist, this.album, this.seconds, this.c1, this.c2,
      {this.vibe = 0, this.bytes, this.mime = 'audio/mpeg'});

  bool get real => bytes != null;
}

final List<Song> songs = [
  Song('Neon Skyline', 'Aurora Drift', 'City Lights', 214,
      const Color(0xFF7C4DFF), const Color(0xFF00E5FF), vibe: 0),
  Song('Midnight Circuit', 'Static Bloom', 'Night Shift', 187,
      const Color(0xFFFF4081), const Color(0xFF7C4DFF), vibe: 1),
  Song('Amber Hours', 'Velvet Coast', 'Sunset Drive', 203,
      const Color(0xFFFF9800), const Color(0xFFFF4081), vibe: 2),
  Song('Paper Planes', 'The Quiet Fields', 'Open Windows', 176,
      const Color(0xFF26C6DA), const Color(0xFF66BB6A), vibe: 3),
  Song('Ocean Echoes', 'Luna Harbor', 'Deep Blue', 241,
      const Color(0xFF2979FF), const Color(0xFF00BFA5), vibe: 3),
  Song('Electric Dreams', 'Pixel Parade', 'Arcade Nights', 195,
      const Color(0xFFD500F9), const Color(0xFF2979FF), vibe: 5),
  Song('Slow Rain', 'Maple & Moon', 'Grey Mornings', 228,
      const Color(0xFF546E7A), const Color(0xFF26C6DA), vibe: 4),
  Song('Sunrise Run', 'Tempo Tribe', 'Morning Miles', 182,
      const Color(0xFFFFC107), const Color(0xFFFF5722), vibe: 2),
  Song('Lantern Lights', 'Orchid Season', 'Festival', 210,
      const Color(0xFFFF7043), const Color(0xFFAB47BC), vibe: 2),
  Song('Afterglow', 'Aurora Drift', 'City Lights', 199,
      const Color(0xFFEC407A), const Color(0xFFFFCA28), vibe: 1),
];

const _artPairs = [
  [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
  [Color(0xFFFF4081), Color(0xFFFFC107)],
  [Color(0xFF00BFA5), Color(0xFF2979FF)],
  [Color(0xFFFF7043), Color(0xFFAB47BC)],
  [Color(0xFF26C6DA), Color(0xFF66BB6A)],
];

String fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

String mimeFor(String ext) {
  switch (ext.toLowerCase()) {
    case 'wav':
      return 'audio/wav';
    case 'ogg':
      return 'audio/ogg';
    case 'm4a':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    case 'flac':
      return 'audio/flac';
    default:
      return 'audio/mpeg';
  }
}

// ---------------- App ----------------
class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Music Playlist',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: violet,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0x14FFFFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        home: const PlaylistPage(),
      );
}

// ---------------- Animated vibe background ----------------
class _P {
  final double x, y, s, ph;
  final int k;
  _P(this.x, this.y, this.s, this.ph, this.k);
}

List<_P> _makeParticles(VibeKind kind) {
  final r = Random(11);
  int count;
  switch (kind) {
    case VibeKind.orbs:
      count = 6;
      break;
    case VibeKind.stars:
      count = 80;
      break;
    case VibeKind.rain:
      count = 90;
      break;
    case VibeKind.embers:
      count = 45;
      break;
    case VibeKind.waves:
      count = 0;
      break;
  }
  return List.generate(
    count,
    (_) => _P(r.nextDouble(), r.nextDouble(), r.nextDouble(),
        r.nextDouble() * 2 * pi, r.nextInt(8)),
  );
}

class VibePainter extends CustomPainter {
  final Vibe vibe;
  final Animation<double> anim;
  final List<_P> ps;

  VibePainter(this.vibe, this.anim)
      : ps = _makeParticles(vibe.kind),
        super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final w = size.width;
    final h = size.height;
    const tau = 2 * pi;

    switch (vibe.kind) {
      case VibeKind.orbs:
        for (int i = 0; i < ps.length; i++) {
          final p = ps[i];
          final c = i.isEven ? vibe.a : vibe.b;
          final radius = 140 + p.s * 180;
          final center = Offset(
            p.x * w + sin(tau * t * (1 + p.k % 2) + p.ph) * w * 0.08,
            p.y * h + cos(tau * t + p.ph) * h * 0.08,
          );
          final paint = Paint()
            ..shader = RadialGradient(
              colors: [c.withAlpha(110), c.withAlpha(0)],
            ).createShader(Rect.fromCircle(center: center, radius: radius));
          canvas.drawCircle(center, radius, paint);
        }
        break;

      case VibeKind.stars:
        final paint = Paint();
        for (final p in ps) {
          final tw = 0.5 + 0.5 * sin(tau * t * (1 + p.k % 3) + p.ph);
          paint.color = Colors.white.withAlpha((60 + 195 * tw).round());
          canvas.drawCircle(Offset(p.x * w, p.y * h * 0.9), 0.6 + p.s * 1.6, paint);
        }
        final moon = Offset(w * 0.82, h * 0.18);
        canvas.drawCircle(
          moon,
          120,
          Paint()
            ..shader = RadialGradient(
              colors: [vibe.b.withAlpha(90), vibe.b.withAlpha(0)],
            ).createShader(Rect.fromCircle(center: moon, radius: 120)),
        );
        canvas.drawCircle(moon, 26, Paint()..color = vibe.b.withAlpha(230));
        break;

      case VibeKind.rain:
        final paint = Paint()
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        for (final p in ps) {
          final speed = 3 + p.k % 5;
          final f = (t * speed + p.ph / tau) % 1.0;
          final y = f * (h + 60) - 30;
          final x = p.x * w - f * 20;
          paint.color = Colors.white.withAlpha((50 + 70 * p.s).round());
          canvas.drawLine(Offset(x, y), Offset(x - 4, y + 14 + p.s * 18), paint);
        }
        break;

      case VibeKind.embers:
        final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        for (int i = 0; i < ps.length; i++) {
          final p = ps[i];
          final f = (t * (1 + p.k % 3) + p.ph / tau) % 1.0;
          final y = h + 10 - f * (h + 20);
          final x = p.x * w + sin(tau * t * (1 + p.k % 2) + p.ph) * 18;
          final c = i.isEven ? vibe.a : vibe.b;
          paint.color = c.withAlpha((210 * (1 - f)).round());
          canvas.drawCircle(Offset(x, y), 1.5 + p.s * 3.5, paint);
        }
        break;

      case VibeKind.waves:
        for (int i = 0; i < 3; i++) {
          final path = Path()..moveTo(0, h);
          for (double x = 0; x <= w; x += 8) {
            final y = h * (0.70 + i * 0.09) +
                sin((x / w) * tau * (1.2 + i * 0.4) + tau * t * (i + 1)) *
                    (18 + i * 8);
            path.lineTo(x, y);
          }
          path
            ..lineTo(w, h)
            ..close();
          final c = i.isEven ? vibe.a : vibe.b;
          canvas.drawPath(path, Paint()..color = c.withAlpha(45 + i * 15));
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant VibePainter old) => old.vibe != vibe;
}

class VibeBackground extends StatefulWidget {
  final Vibe vibe;
  const VibeBackground({super.key, required this.vibe});

  @override
  State<VibeBackground> createState() => _VibeBackgroundState();
}

class _VibeBackgroundState extends State<VibeBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.vibe.bg,
            ),
          ),
          child: SizedBox.expand(
            child: CustomPaint(painter: VibePainter(widget.vibe, _c)),
          ),
        ),
      );
}

// ---------------- Spinning vinyl logo ----------------
class LogoMark extends StatefulWidget {
  final bool playing;
  final Color glow;
  const LogoMark({super.key, required this.playing, required this.glow});

  @override
  State<LogoMark> createState() => _LogoMarkState();
}

class _LogoMarkState extends State<LogoMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant LogoMark old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disc = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(colors: [
          Color(0xFF12122A),
          Color(0xFF5A5A82),
          Color(0xFF12122A),
          Color(0xFF12122A),
          Color(0xFF5A5A82),
          Color(0xFF12122A),
        ]),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: [BoxShadow(color: widget.glow.withAlpha(120), blurRadius: 20)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: accent),
          ),
        ],
      ),
    );

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) =>
                Transform.rotate(angle: _c.value * 2 * pi, child: child),
            child: disc,
          ),
          const Icon(Icons.music_note, size: 16, color: Colors.white),
        ],
      ),
    );
  }
}

// ---------------- Small reusable widgets ----------------
class GradientText extends StatelessWidget {
  final String text;
  final double size;
  final double spacing;
  const GradientText(this.text, {super.key, this.size = 22, this.spacing = 0});

  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (r) => accent.createShader(r),
        child: Text(text,
            style: TextStyle(
                color: Colors.white,
                fontSize: size,
                fontWeight: FontWeight.w800,
                letterSpacing: spacing)),
      );
}

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x2EFFFFFF), Color(0x0FFFFFFF)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x2EFFFFFF)),
            ),
            child: child,
          ),
        ),
      );
}

class GradientButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const GradientButton(
      {super.key, required this.icon, required this.label, required this.onTap});

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hover ? 1.05 : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: accent,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: violet.withAlpha(_hover ? 170 : 110),
                    blurRadius: _hover ? 26 : 16,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(widget.label,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      );
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const DashedBorderPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter old) => old.color != color;
}

class Art extends StatelessWidget {
  final Song song;
  final double size;
  final bool glow;
  const Art({super.key, required this.song, required this.size, this.glow = false});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [song.c1, song.c2],
          ),
          borderRadius: BorderRadius.circular(size * 0.18),
          boxShadow: glow
              ? [BoxShadow(color: song.c1.withAlpha(120), blurRadius: 50, spreadRadius: 2)]
              : const [],
        ),
        child: Icon(Icons.music_note, size: size * 0.45, color: Colors.white.withAlpha(220)),
      );
}

class Equalizer extends StatefulWidget {
  final bool playing;
  final Color color;
  const Equalizer({super.key, required this.playing, required this.color});

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 30,
        height: 22,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (i) {
              final h = widget.playing
                  ? 6 + 16 * sin(_c.value * 2 * pi + i * 1.3).abs()
                  : 6.0;
              return Container(
                width: 4,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
      );
}

// ---------------- Main page ----------------
class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final _rand = Random();
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer; // only used for demo (simulated) songs

  String _name = 'Chill Vibes';
  int _current = 0;
  bool _playing = false;
  double _pos = 0; // seconds
  bool _shuffle = false;
  int _repeat = 0; // 0 off, 1 all, 2 one
  final Set<int> _fav = {1, 4};
  String _query = '';
  bool _onlyFav = false;
  bool _showPlayer = false;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      if (songs[_current].real && _playing) {
        setState(() => _pos = p.inMilliseconds / 1000);
      }
    });
    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      if (songs[_current].real && d.inSeconds > 0) {
        setState(() => songs[_current].seconds = d.inSeconds);
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (songs[_current].real) _advance(auto: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ----- rename playlist -----
  Future<void> _renamePlaylist() async {
    final c = TextEditingController(text: _name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename playlist'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final name = result?.trim() ?? '';
    if (name.isNotEmpty && mounted) {
      setState(() => _name = name);
      _snack('Playlist renamed');
    }
  }

  // ----- add songs from device -----
  Future<void> _addSongs() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        withData: true,
      );
      if (res == null) return;

      int added = 0;
      setState(() {
        for (final f in res.files) {
          final data = f.bytes;
          if (data == null) continue;
          final name = f.name;
          final dot = name.lastIndexOf('.');
          final title = dot > 0 ? name.substring(0, dot) : name;
          final ext = dot > 0 ? name.substring(dot + 1) : 'mp3';
          final pair = _artPairs[songs.length % _artPairs.length];
          songs.add(Song(title, 'Your device', 'Uploaded', 0, pair[0], pair[1],
              vibe: vibeFor(title), bytes: data, mime: mimeFor(ext)));
          added++;
        }
      });
      _snack(added == 0 ? 'No audio could be read' : 'Added $added song(s)');
    } catch (e) {
      _snack('Could not add songs: $e');
    }
  }

  // ----- playback logic -----
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      setState(() => _pos += 0.25);
      if (_pos >= songs[_current].seconds) _advance(auto: true);
    });
  }

  Future<void> _start(int i) async {
    _timer?.cancel();
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _current = i;
      _pos = 0;
      _playing = true;
    });
    final s = songs[i];
    if (s.real) {
      try {
        await _player.play(BytesSource(s.bytes!, mimeType: s.mime));
      } catch (e) {
        if (mounted) setState(() => _playing = false);
        _snack('Could not play this file: $e');
      }
    } else {
      _startTimer();
    }
  }

  Future<void> _toggle() async {
    final s = songs[_current];
    if (_playing) {
      _timer?.cancel();
      setState(() => _playing = false);
      if (s.real) await _player.pause();
    } else {
      if (s.real && _pos > 0) {
        setState(() => _playing = true);
        await _player.resume();
      } else if (!s.real && _pos > 0) {
        setState(() => _playing = true);
        _startTimer();
      } else {
        await _start(_current);
      }
    }
  }

  Future<void> _playIndex(int i) async {
    if (i == _current) {
      await _toggle();
    } else {
      await _start(i);
    }
  }

  Future<void> _advance({required bool auto}) async {
    final n = songs.length;
    if (auto && _repeat == 2) {
      await _start(_current);
      return;
    }
    int next;
    if (_shuffle && n > 1) {
      do {
        next = _rand.nextInt(n);
      } while (next == _current);
    } else {
      next = (_current + 1) % n;
      if (auto && _repeat == 0 && next == 0) {
        _timer?.cancel();
        await _player.stop();
        if (mounted) {
          setState(() {
            _playing = false;
            _pos = 0;
          });
        }
        return;
      }
    }
    await _start(next);
  }

  Future<void> _prev() async {
    final n = songs.length;
    if (_pos > 3) {
      await _start(_current);
    } else {
      await _start((_current - 1 + n) % n);
    }
  }

  Future<void> _seek(double v) async {
    if (songs[_current].real) {
      await _player.seek(Duration(milliseconds: (v * 1000).round()));
    }
  }

  void _toggleFav(int i) => setState(() {
        if (!_fav.remove(i)) _fav.add(i);
      });

  List<int> get _visible {
    final q = _query.trim().toLowerCase();
    return [
      for (int i = 0; i < songs.length; i++)
        if ((!_onlyFav || _fav.contains(i)) &&
            (q.isEmpty ||
                songs[i].title.toLowerCase().contains(q) ||
                songs[i].artist.toLowerCase().contains(q)))
          i
    ];
  }

  Widget _background(Song s) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 900),
        child: VibeBackground(key: ValueKey(s.vibe), vibe: vibes[s.vibe]),
      );

  // ---------------- UI pieces ----------------
  Widget _heart(int i) {
    final f = _fav.contains(i);
    return IconButton(
      tooltip: f ? 'Remove from favorites' : 'Add to favorites',
      visualDensity: VisualDensity.compact,
      icon: Icon(f ? Icons.favorite : Icons.favorite_border,
          color: f ? pink : Colors.white54),
      onPressed: () => _toggleFav(i),
    );
  }

  Widget _tile(int i, int number) {
    final s = songs[i];
    final cur = i == _current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _playIndex(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cur ? const Color(0x24FFFFFF) : const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: cur ? s.c1.withAlpha(200) : const Color(0x14FFFFFF)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Center(
                    child: cur
                        ? Equalizer(playing: _playing, color: cyan)
                        : Text('$number',
                            style: const TextStyle(color: Colors.white38)),
                  ),
                ),
                const SizedBox(width: 8),
                Art(song: s, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(
                          s.real
                              ? '${s.artist} • ${s.album}'
                              : '${s.artist} • Demo (no audio)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(vibes[s.vibe].icon, size: 15, color: vibes[s.vibe].a),
                const SizedBox(width: 8),
                Text(s.seconds > 0 ? fmt(s.seconds) : '--:--',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                _heart(i),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addTile() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _addSongs,
          child: CustomPaint(
            painter: DashedBorderPainter(cyan.withAlpha(150), 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, gradient: accent),
                    child: const Icon(Icons.library_add, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Add songs from your device',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('MP3 • WAV • M4A • OGG',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _library(double bottomPad) {
    final vis = _visible;
    final knownMins = songs.fold<int>(0, (a, s) => a + s.seconds) ~/ 60;
    final cur = songs[_current];
    final showAdd = !_onlyFav && _query.trim().isEmpty;

    return LayoutBuilder(builder: (context, cons) {
      final colW = min(cons.maxWidth, 760.0);
      final side = (cons.maxWidth - colW) / 2;
      final gap = max(0.0, 72 - side - 20); // keeps text clear of the logo
      final compact = colW < 520;

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20 + gap, 16, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const GradientText('MY PLAYLIST', size: 22, spacing: 4),
                          Text('${songs.length} songs • $knownMins min',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white60)),
                        ],
                      ),
                    ),
                    GradientButton(
                      icon: Icons.add,
                      label: compact ? 'Add' : 'Add songs',
                      onTap: _addSongs,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Glass(
                  child: Row(
                    children: [
                      Art(song: cur, size: 76, glow: true),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(_name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'Rename playlist',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit,
                                      size: 18, color: Colors.white70),
                                  onPressed: _renamePlaylist,
                                ),
                              ],
                            ),
                            const Text('Made for you',
                                style: TextStyle(color: Colors.white60)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () {
                                    setState(() => _shuffle = false);
                                    _start(0);
                                  },
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Play all'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() => _shuffle = true);
                                    _start(_rand.nextInt(songs.length));
                                  },
                                  icon: const Icon(Icons.shuffle),
                                  label: const Text('Shuffle'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search songs or artists',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: !_onlyFav,
                      onSelected: (_) => setState(() => _onlyFav = false),
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.favorite, size: 16, color: pink),
                      label: Text('Favorites (${_fav.length})'),
                      selected: _onlyFav,
                      onSelected: (_) => setState(() => _onlyFav = true),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: vis.isEmpty
                    ? const Center(
                        child: Text('No songs found',
                            style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
                        itemCount: vis.length + (showAdd ? 1 : 0),
                        itemBuilder: (context, k) {
                          if (k == vis.length) return _addTile();
                          return _tile(vis[k], k + 1);
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _miniPlayer() {
    final s = songs[_current];
    final dur = max(1, s.seconds);
    return GestureDetector(
      onTap: () => setState(() => _showPlayer = true),
      child: Glass(
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Art(song: s, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(s.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _toggle,
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 30),
                ),
                IconButton(
                  onPressed: () => _advance(auto: false),
                  icon: const Icon(Icons.skip_next, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (_pos / dur).clamp(0.0, 1.0).toDouble(),
                  minHeight: 3,
                  color: cyan,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerPanel(bool full) {
    final s = songs[_current];
    final dur = max(1, s.seconds).toDouble();
    final artSize = min(280.0, MediaQuery.of(context).size.width - 80);
    const nowPlaying = Text('NOW PLAYING',
        style: TextStyle(letterSpacing: 3, fontSize: 12, color: Colors.white60));

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (full)
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Close player',
                      icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                      onPressed: () => setState(() => _showPlayer = false),
                    ),
                    const Spacer(),
                    nowPlaying,
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                )
              else
                nowPlaying,
              const SizedBox(height: 20),
              AnimatedScale(
                scale: _playing ? 1 : 0.92,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: Art(song: s, size: artSize, glow: true),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800)),
                        Text(s.real ? s.artist : '${s.artist} • Demo',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 15)),
                      ],
                    ),
                  ),
                  _heart(_current),
                ],
              ),
              Slider(
                value: _pos.clamp(0.0, dur).toDouble(),
                max: dur,
                onChanged: (v) => setState(() => _pos = v),
                onChangeEnd: _seek,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fmt(_pos.round()),
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    Text(s.seconds > 0 ? fmt(s.seconds) : '--:--',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: 'Shuffle',
                    onPressed: () => setState(() => _shuffle = !_shuffle),
                    icon: Icon(Icons.shuffle,
                        color: _shuffle ? cyan : Colors.white54),
                  ),
                  IconButton(
                    tooltip: 'Previous',
                    onPressed: _prev,
                    icon: const Icon(Icons.skip_previous, size: 36),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _toggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [s.c1, s.c2]),
                          boxShadow: [
                            BoxShadow(color: s.c1.withAlpha(140), blurRadius: 24),
                          ],
                        ),
                        child: Icon(
                          _playing ? Icons.pause : Icons.play_arrow,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: () => _advance(auto: false),
                    icon: const Icon(Icons.skip_next, size: 36),
                  ),
                  IconButton(
                    tooltip: 'Repeat',
                    onPressed: () => setState(() => _repeat = (_repeat + 1) % 3),
                    icon: Icon(
                      _repeat == 2 ? Icons.repeat_one : Icons.repeat,
                      color: _repeat == 0 ? Colors.white54 : cyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text('VIBE',
                  style: TextStyle(
                      letterSpacing: 3, fontSize: 11, color: Colors.white54)),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < vibes.length; i++)
                    ChoiceChip(
                      avatar: Icon(vibes[i].icon, size: 16),
                      label: Text(vibes[i].name),
                      selected: s.vibe == i,
                      onSelected: (_) => setState(() => s.vibe = i),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = songs[_current];

    return Stack(
      children: [
        Positioned.fill(child: _background(s)),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(builder: (context, cons) {
              final wide = cons.maxWidth >= 900;
              final logo = Positioned(
                left: 16,
                top: 14,
                child: Tooltip(
                  message: 'Music Playlist',
                  child: LogoMark(playing: _playing, glow: vibes[s.vibe].a),
                ),
              );

              if (wide) {
                return Stack(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _library(20)),
                        Container(
                          width: 430,
                          decoration: const BoxDecoration(
                            color: Color(0x33000000),
                            border:
                                Border(left: BorderSide(color: Color(0x1FFFFFFF))),
                          ),
                          child: _playerPanel(false),
                        ),
                      ],
                    ),
                    logo,
                  ],
                );
              }

              return Stack(
                children: [
                  Positioned.fill(child: _library(120)),
                  logo,
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _miniPlayer(),
                  ),
                  if (_showPlayer)
                    Positioned.fill(
                      child: Stack(
                        children: [
                          Positioned.fill(child: _background(s)),
                          _playerPanel(true),
                        ],
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}