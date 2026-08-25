import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/server_profile.dart';
import '../services/profile_repository.dart';
import '../services/ssh_bootstrap.dart';

/// A server the form has just created, with the two things that are not on it.
///
/// The profile is already saved by the time this object exists. The password and
/// the provider key are not saved anywhere — they travel from the form to
/// whoever runs the bootstrap, and nowhere else.
final class NewServer {
  NewServer({
    required this.profile,
    required this.password,
    required this.openRouterApiKey,
  });

  /// Saved with `bootstrapped: false`: an intention until the stack answers.
  final ServerProfile profile;

  /// In its box, so the bootstrap can empty it the moment the key works.
  final RootPassword password;

  /// The stack declares `OPENROUTER_API_KEY` with `:?` in its compose file and
  /// refuses to start without it, which is why it is typed here alongside the
  /// password rather than asked for later.
  final String openRouterApiKey;

  /// Names what it carries without revealing any of it, for the same reason
  /// [ServerProfile.toString] and [RootPassword.toString] do.
  @override
  String toString() => 'NewServer(${profile.id}, $password, provider key held)';
}

/// The form for a new server.
///
/// It saves the profile and returns it — it does not navigate onward and does
/// not start the bootstrap. The caller decides what happens next, which is what
/// lets this screen be tested without the screen that comes after it.
class AddServerScreen extends StatefulWidget {
  const AddServerScreen({required this.profiles, super.key});

  final ProfileRepository profiles;

  /// Keys rather than labels, so a test names a field without depending on the
  /// wording of its label.
  static const nameField = Key('add-server-name');
  static const hostField = Key('add-server-host');
  static const portField = Key('add-server-port');
  static const usernameField = Key('add-server-username');
  static const passwordField = Key('add-server-password');
  static const providerKeyField = Key('add-server-provider-key');
  static const submitButton = Key('add-server-submit');

  @override
  State<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends State<AddServerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _username = TextEditingController(text: 'root');
  final _password = TextEditingController();
  final _providerKey = TextEditingController();

  bool _saving = false;
  String? _failure;

  @override
  void dispose() {
    // Disposing the controllers is what drops the password: a Dart string cannot
    // be overwritten, so releasing every reference to it is the only thing
    // "forgetting" can mean.
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _providerKey.dispose();
    super.dispose();
  }

  /// A generated id, never one derived from the host or the name.
  ///
  /// Both can change over a server's life, and the id is the prefix every secret
  /// this profile owns is filed under — deriving it would mean a rename orphans
  /// the key material. The timestamp makes it unique across runs, the random
  /// suffix across two additions inside the same microsecond.
  static String _generateId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final noise = Random().nextInt(1 << 30).toRadixString(36);
    return 'srv_${stamp}_$noise';
  }

  String? _required(String? value, String field) =>
      (value ?? '').trim().isEmpty ? 'Enter the $field' : null;

  String? _validatePort(String? value) {
    final port = int.tryParse((value ?? '').trim());
    if (port == null || port < 1 || port > 65535) {
      return 'Port must be a number between 1 and 65535';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final host = _host.text.trim();
    final typedName = _name.text.trim();
    final profile = ServerProfile(
      id: _generateId(),
      // A name is a convenience, not information: with none given the host says
      // as much and is never blank, because the form has just checked it.
      name: typedName.isEmpty ? host : typedName,
      host: host,
      username: _username.text.trim(),
      port: int.parse(_port.text.trim()),
      // The profile is saved before anything is deployed, which is what makes an
      // interrupted bootstrap resumable: the id already exists, and the secrets
      // are keyed by it.
      bootstrapped: false,
    );

    setState(() {
      _saving = true;
      _failure = null;
    });

    try {
      await widget.profiles.save(profile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        // The repository writes profiles, never a secret, so nothing typed here
        // can appear in its error.
        _failure = 'Could not save the server: $error';
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      NewServer(
        profile: profile,
        password: RootPassword(_password.text),
        openRouterApiKey: _providerKey.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Add a server')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: AddServerScreen.nameField,
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                helperText: 'Optional — the host is used when left blank',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: AddServerScreen.hostField,
              controller: _host,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText: 'name.example.com or 192.0.2.10',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _required(value, 'host'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: AddServerScreen.portField,
              controller: _port,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'SSH port',
                border: OutlineInputBorder(),
              ),
              validator: _validatePort,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: AddServerScreen.usernameField,
              controller: _username,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _required(value, 'username'),
            ),
            const SizedBox(height: 24),
            Text('Used once, never stored', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              key: AddServerScreen.passwordField,
              controller: _password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Root password',
                helperText:
                    'The bootstrap installs a key with it and then drops it',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _required(value, 'root password'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: AddServerScreen.providerKeyField,
              controller: _providerKey,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'OpenRouter API key',
                helperText: 'The stack will not start without it',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _required(value, 'OpenRouter API key'),
            ),
            if (_failure != null) ...[
              const SizedBox(height: 16),
              Text(
                _failure!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: AddServerScreen.submitButton,
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving…' : 'Save the server'),
            ),
          ],
        ),
      ),
    );
  }
}
