import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/chakra.dart';
import '../widgets/made_in_india.dart';
import 'civic_content.dart';
import 'legal_content.dart';

/// "India & Kabootar" — a civic + about + legal screen. Full-tricolour, with
/// the Ashoka Chakra, the Preamble, the Fundamental Duties, friendly facts, and
/// the app's privacy, terms, and non-affiliation disclaimer.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('India & Kabootar'),
        bottom: const TricolorLine(thickness: 4),
      ),
      body: ListView(
        children: const <Widget>[
          _Hero(),
          SizedBox(height: 8),
          _DisclaimerCard(),
          _FactCard(),
          _PreambleCard(),
          _DutiesCard(),
          _LegalCard(),
          _FooterCard(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x33FF9933), // saffron wash
            Color(0x22138808), // green wash
          ],
        ),
      ),
      child: Column(
        children: <Widget>[
          const Chakra(size: 84),
          const SizedBox(height: 16),
          Text(
            'Kabootar',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Proudly made in India — messaging that works even when the '
            'network does not.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                    alpha: 0.7,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          const TricolorBar(width: 120, height: 6),
        ],
      ),
    );
  }
}

/// Card scaffold used across the sections.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.icon, this.title});

  final Widget child;
  final IconData? icon;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
                alpha: 0.4,
              ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 18, color: Tiranga.chakra),
                  const SizedBox(width: 8),
                ],
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.verified_user_outlined,
      title: 'An independent, citizen-built app',
      child: Text(
        Civic.disclaimer,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _PreambleCard extends StatelessWidget {
  const _PreambleCard();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      icon: Icons.menu_book_outlined,
      title: 'Preamble to the Constitution of India',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            Civic.preamble,
            style: TextStyle(fontSize: 13.5, height: 1.55),
          ),
          SizedBox(height: 10),
          TricolorBar(width: 64, height: 4),
        ],
      ),
    );
  }
}

class _DutiesCard extends StatelessWidget {
  const _DutiesCard();

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.handshake_outlined,
      title: 'Our Fundamental Duties (Article 51A)',
      child: Column(
        children: <Widget>[
          for (int i = 0; i < Civic.fundamentalDuties.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Tiranga.chakra,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        // Tight leading so the digit centres in the circle.
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      Civic.fundamentalDuties[i],
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      icon: Icons.gavel_outlined,
      title: 'Privacy & terms',
      child: Column(
        children: <Widget>[
          _LegalTile(
            title: 'Privacy Policy',
            subtitle: 'No account, no servers, data stays on your device',
            body: Legal.privacy,
          ),
          SizedBox(height: 8),
          _LegalTile(
            title: 'Terms of Use',
            subtitle: 'As-is, best-effort delivery, use responsibly',
            body: Legal.terms,
          ),
        ],
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final String title;
  final String subtitle;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _LegalPage(title: title, body: body),
          ),
        ),
      ),
    );
  }
}

class _LegalPage extends StatelessWidget {
  const _LegalPage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: const TricolorLine(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
          const SizedBox(height: 24),
          const Center(child: MadeInIndia()),
        ],
      ),
    );
  }
}

class _FooterCard extends StatelessWidget {
  const _FooterCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: <Widget>[
          const MadeInIndia(caption: 'Jai Hind 🇮🇳'),
          const SizedBox(height: 8),
          Text(
            'Free & open source · MIT License',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                    alpha: 0.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Auto-rotating "Did you know?" fact.
class _FactCard extends StatefulWidget {
  const _FactCard();

  @override
  State<_FactCard> createState() => _FactCardState();
}

class _FactCardState extends State<_FactCard> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) {
        setState(() => _i = (_i + 1) % Civic.facts.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.lightbulb_outline,
      title: 'Did you know?',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Text(
          Civic.facts[_i],
          key: ValueKey<int>(_i),
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
      ),
    );
  }
}
