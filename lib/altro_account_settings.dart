// Schermate account (Firebase Auth), hub impostazioni e segnaposto sezioni Altro.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'romagna_brand.dart';

bool _userHaProviderPassword(User u) =>
    u.providerData.any((p) => p.providerId == 'password');

/// Profilo utente: dati da Firebase; tap su sezioni per modifica.
class AccountProfilePage extends StatelessWidget {
  const AccountProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text('Il mio account', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snapshot) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return const Center(child: Text('Sessione non valida.'));
          }
          return _AccountProfileBody(user: user);
        },
      ),
    );
  }
}

class _AccountProfileBody extends StatelessWidget {
  const _AccountProfileBody({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final email = user.email ?? '—';
    final display = user.displayName?.trim();
    final photo = user.photoURL;

    Future<void> apriSceltaFoto() async {
      final sorgente = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder:
            (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text('Scegli dalla galleria', style: GoogleFonts.inter()),
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text('Scatta con la fotocamera', style: GoogleFonts.inter()),
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ],
              ),
            ),
      );
      if (sorgente == null || !context.mounted) return;

      final picker = ImagePicker();
      final x = await picker.pickImage(source: sorgente, maxWidth: 1600, imageQuality: 88);
      if (x == null || !context.mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Caricamento foto…', style: GoogleFonts.inter(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      try {
        final bytes = await x.readAsBytes();
        final ref = FirebaseStorage.instance.ref().child('profile_images').child('${user.uid}.jpg');
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        await user.updatePhotoURL(url);
        await user.reload();
        if (!context.mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Foto aggiornata.', style: GoogleFonts.inter(color: Colors.white)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Upload non riuscito (Firebase Storage / regole): $e',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    return ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: [
          Center(
            child: GestureDetector(
              onTap: apriSceltaFoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: kRomagnaPrimary.withValues(alpha: 0.2),
                    backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                    child:
                        photo == null || photo.isEmpty
                            ? Icon(Icons.person_rounded, size: 56, color: kRomagnaPrimary.withValues(alpha: 0.85))
                            : null,
                  ),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: apriSceltaFoto,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.edit_outlined, size: 18, color: kRomagnaDarkGray),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Tocca la foto per modificarla',
              style: GoogleFonts.inter(fontSize: 12, color: kRomagnaDarkGray.withValues(alpha: 0.55)),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: Text('E-mail', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(email, style: GoogleFonts.inter(fontSize: 15)),
          ),
          ListTile(
            title: Text('Password', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('••••••••', style: GoogleFonts.inter(fontSize: 15, letterSpacing: 1.2)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              if (!_userHaProviderPassword(user)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Hai effettuato l’accesso con Google. La password è gestita dal tuo account Google.',
                      style: GoogleFonts.inter(color: Colors.white, height: 1.35),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const ChangePasswordPage()),
              );
            },
          ),
          ListTile(
            title: Text('Nome e cognome', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(
              (display == null || display.isEmpty) ? 'Non impostato' : display,
              style: GoogleFonts.inter(fontSize: 15),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap:
                () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => EditDisplayNamePage(nomeIniziale: display ?? ''),
                  ),
                ),
          ),
        ],
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _attuale = TextEditingController();
  final _nuova = TextEditingController();
  final _ripeti = TextEditingController();
  bool _busy = false;
  bool _hide1 = true;
  bool _hide2 = true;
  bool _hide3 = true;

  @override
  void dispose() {
    _attuale.dispose();
    _nuova.dispose();
    _ripeti.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) return;

    final cur = _attuale.text;
    final n1 = _nuova.text;
    final n2 = _ripeti.text;
    if (cur.isEmpty || n1.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Compila tutti i campi.', style: GoogleFonts.inter(color: Colors.white))),
      );
      return;
    }
    if (n1 != n2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Le nuove password non coincidono.', style: GoogleFonts.inter(color: Colors.white))),
      );
      return;
    }
    if (n1.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La nuova password deve avere almeno 6 caratteri.', style: GoogleFonts.inter(color: Colors.white)),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final cred = EmailAuthProvider.credential(email: email, password: cur);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(n1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password aggiornata.', style: GoogleFonts.inter(color: Colors.white))),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.code, style: GoogleFonts.inter(color: Colors.white, fontSize: 13))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e', style: GoogleFonts.inter(color: Colors.white, fontSize: 13))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text('Cambia password', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _attuale,
            obscureText: _hide1,
            decoration: InputDecoration(
              labelText: 'Password attuale',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hide1 = !_hide1),
                icon: Icon(_hide1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nuova,
            obscureText: _hide2,
            decoration: InputDecoration(
              labelText: 'Nuova password',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hide2 = !_hide2),
                icon: Icon(_hide2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ripeti,
            obscureText: _hide3,
            decoration: InputDecoration(
              labelText: 'Ripeti nuova password',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hide3 = !_hide3),
                icon: Icon(_hide3 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _salva,
            style: FilledButton.styleFrom(backgroundColor: kRomagnaPrimary, foregroundColor: Colors.white),
            child:
                _busy
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Salva', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class EditDisplayNamePage extends StatefulWidget {
  const EditDisplayNamePage({super.key, required this.nomeIniziale});

  final String nomeIniziale;

  @override
  State<EditDisplayNamePage> createState() => _EditDisplayNamePageState();
}

class _EditDisplayNamePageState extends State<EditDisplayNamePage> {
  late final TextEditingController _c = TextEditingController(text: widget.nomeIniziale);
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final v = _c.text.trim();
    setState(() => _busy = true);
    try {
      await user.updateDisplayName(v.isEmpty ? null : v);
      await user.reload();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e', style: GoogleFonts.inter(color: Colors.white))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text('Nome e cognome', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _c,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome e cognome'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _salva,
              style: FilledButton.styleFrom(backgroundColor: kRomagnaPrimary, foregroundColor: Colors.white),
              child:
                  _busy
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Salva', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segnaposto generico (Avvisi, Contatti, …).
class AltroPlaceholderPage extends StatelessWidget {
  const AltroPlaceholderPage({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.4,
              color: kRomagnaDarkGray.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }
}
