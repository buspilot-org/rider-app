import 'package:material_ui/material_ui.dart';

import '../data/api.dart';
import '../data/invite_link.dart';
import '../state/app_state.dart';
import 'scan_screen.dart';
import 'widgets.dart';

/// Join an operator with an invite code: typed, scanned or from a link.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, this.initialCode});

  /// From an invite link; redeemed right away.
  final String? initialCode;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late final _controller = TextEditingController(text: widget.initialCode ?? '');
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _redeem());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = inviteCodeFrom(_controller.text);
    final l = context.l10n;
    if (code == null) {
      setState(() => _error = l.joinInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = AppScope.read(context);
    try {
      final result = await state.redeem(code);
      if (!mounted) return;
      final opName = state.catalog
              .operator(result.operatorId ?? '')
              ?.name
              .resolve(context.lang) ??
          '';
      switch (result.status) {
        case RedeemStatus.joined:
        case RedeemStatus.alreadyMember:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.status == RedeemStatus.joined
                    ? l.joinJoined(opName)
                    : l.joinAlreadyMember(opName),
              ),
            ),
          );
          Navigator.of(context).popUntil((r) => r.isFirst);
          return;
        case RedeemStatus.invalid:
          _error = l.joinInvalid;
        case RedeemStatus.revoked:
          _error = l.joinRevoked;
        case RedeemStatus.rateLimited:
          _error = l.joinRateLimited;
      }
    } on OfflineException {
      _error = l.offlineError;
    } catch (_) {
      _error = l.genericError;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (code != null && mounted) {
      _controller.text = code;
      await _redeem();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.joinTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l.joinIntro, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(l.scanQrButton),
          ),
          const SizedBox(height: 24),
          TextField(
            key: const Key('invite-code'),
            controller: _controller,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l.inviteCodeLabel,
              hintText: 'XXXXX-XXXXX',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _redeem(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('join-button'),
            onPressed: _busy ? null : _redeem,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.joinButton),
          ),
        ],
      ),
    );
  }
}
