// Schermata di accesso RomagnaGO: sfondo bianco, testi in grigio #393939 e
// accenti azzurro brand; autenticazione Firebase (email/password, Google,
// link ospite). I commenti spiegano ogni passaggio in italiano.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Palette: azzurro brand, bianco e grigio scuro (#393939).
const Color _kAzzurroRomagna = Color(0xFF38B6FF);
const Color _kGrigioScuro = Color(0xFF393939);

// Sfondo campi su card bianca (leggero contrasto).
const Color _kCampoRiempimento = Color(0xFFF5F7FA);

// google_sign_in 7.x: [initialize] va chiamato una sola volta prima di [authenticate].
bool _googleSignInInizializzato = false;

/// Prepara il plugin Google Sign-In (obbligatorio dalla v7 prima di autenticare).
Future<void> _assicuraGoogleSignInPronto() async {
  if (_googleSignInInizializzato) return;
  await GoogleSignIn.instance.initialize();
  _googleSignInInizializzato = true;
}

/// Pagina di login/registrazione mostrata all’avvio prima della home mappa.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.guestRedirectNotice});

  /// Se valorizzato (es. da «Il mio account» in modalità ospite), mostra un avviso dopo il primo frame.
  final String? guestRedirectNotice;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controller per leggere email e password senza ricostruire i TextField a ogni lettera.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // true = accesso con email già registrata; false = creazione nuovo account.
  bool _modalitaAccesso = true;

  // Nasconde la password nel campo (toggle con icona).
  bool _nascondiPassword = true;

  // Disabilita pulsanti durante le chiamate async a Firebase (evita doppi tap).
  bool _caricamento = false;

  @override
  void initState() {
    super.initState();
    final msg = widget.guestRedirectNotice;
    if (msg != null && msg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(
                  'Modalità ospite',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                content: Text(msg, style: GoogleFonts.inter(height: 1.35)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('OK', style: GoogleFonts.inter(color: _kAzzurroRomagna)),
                  ),
                ],
              ),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// SnackBar uniforme: sfondo azzurro (#38b6ff) e testo bianco (errori auth).
  void _mostraMessaggio(BuildContext context, String testo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          testo,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        backgroundColor: _kAzzurroRomagna,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  /// Traduce i codici Firebase in messaggi comprensibili in italiano.
  String _messaggioErroreFirebase(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Nessun account con questa email. Controlla o registrati.';
      case 'wrong-password':
        return 'Password non corretta.';
      case 'email-already-in-use':
        return 'Questa email è già registrata. Accedi invece di registrarti.';
      case 'invalid-email':
        return 'Indirizzo email non valido.';
      case 'weak-password':
        return 'Password troppo debole (usa almeno 6 caratteri).';
      case 'invalid-credential':
        return 'Credenziali non valide. Riprova.';
      case 'user-disabled':
        return 'Questo account è stato disabilitato.';
      case 'too-many-requests':
        return 'Troppi tentativi. Riprova tra qualche minuto.';
      default:
        return e.message ?? 'Si è verificato un errore (${e.code}).';
    }
  }

  /// Dopo login/registrazione riuscita si va alla home mappa (route definita in main).
  void _vaiAllaHome(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  /// Accesso o registrazione con email e password tramite FirebaseAuth.
  Future<void> _inviaEmailPassword(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _mostraMessaggio(context, 'Inserisci email e password.');
      return;
    }

    setState(() => _caricamento = true);
    try {
      final auth = FirebaseAuth.instance;
      if (_modalitaAccesso) {
        // Login utente già registrato.
        await auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        // Creazione nuovo utente Firebase Authentication.
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      if (!context.mounted) return;
      _vaiAllaHome(context);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      _mostraMessaggio(context, _messaggioErroreFirebase(e));
    } catch (e) {
      if (!context.mounted) return;
      _mostraMessaggio(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  /// Google Sign-In: flusso interattivo (authenticate) + token per Firebase.
  Future<void> _accediConGoogle(BuildContext context) async {
    setState(() => _caricamento = true);
    try {
      await _assicuraGoogleSignInPronto();

      // Avvia il flusso nativo / web di selezione account Google.
      final accountGoogle = await GoogleSignIn.instance.authenticate();

      // idToken per Firebase Auth (OpenID).
      final idToken = accountGoogle.authentication.idToken;

      // Access token OAuth (separato in google_sign_in 7): serve a [GoogleAuthProvider.credential].
      final clientAuth = await accountGoogle.authorizationClient
          .authorizeScopes(const <String>['email', 'profile']);

      final credenziale = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credenziale);

      if (!context.mounted) return;
      _vaiAllaHome(context);
    } on GoogleSignInException catch (e) {
      // Annullamento o interruzione: niente SnackBar invasivo.
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return;
      }
      if (!context.mounted) return;
      _mostraMessaggio(
        context,
        e.description ?? 'Accesso Google non riuscito.',
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      _mostraMessaggio(context, _messaggioErroreFirebase(e));
    } catch (e) {
      if (!context.mounted) return;
      _mostraMessaggio(
        context,
        'Accesso con Google non riuscito. Verifica la configurazione Firebase.',
      );
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  /// Facebook richiede SDK nativi e configurazione console: qui solo messaggio guida.
  void _facebookInConfigurazione(BuildContext context) {
    _mostraMessaggio(
      context,
      'Accedi con Facebook: aggiungi flutter_facebook_auth e l’app Facebook in Firebase.',
    );
  }

  /// Ospite: nessuna sessione Firebase; si entra subito nell’esperienza mappa.
  void _esploraComeOspite(BuildContext context) {
    _vaiAllaHome(context);
  }

  @override
  Widget build(BuildContext context) {
    // Tipografia Inter (stile pulito, coerente col resto dell’app).
    final testoTitolo = GoogleFonts.inter(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: _kGrigioScuro,
    );
    final testoSottotitolo = GoogleFonts.inter(
      fontSize: 14,
      height: 1.4,
      color: _kGrigioScuro.withValues(alpha: 0.65),
    );

    return Scaffold(
      // Pagina interamente su bianco per massima leggibilità.
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo principale (PNG senza sfondo, già in pubspec assets).
                  Image.asset(
                    'assets/logomain_nobg.png',
                    fit: BoxFit.contain,
                    height: 72,
                    semanticLabel: 'RomagnaGO',
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/logomain.png',
                      fit: BoxFit.contain,
                      height: 72,
                      semanticLabel: 'RomagnaGO',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Muoversi in Romagna',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _kGrigioScuro.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // --------------------------------------------------------
                  // Card form: bordo grigio chiaro e ombra leggera (no vetro su bianco).
                  // --------------------------------------------------------
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _kGrigioScuro.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kGrigioScuro.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _modalitaAccesso ? 'Accedi' : 'Crea account',
                          style: testoTitolo,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _modalitaAccesso
                              ? 'Inserisci le tue credenziali'
                              : 'Registrati per sbloccare tutte le funzionalità',
                          style: testoSottotitolo,
                        ),
                        const SizedBox(height: 22),

                        // Campo email con icona e stile sobrio.
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: GoogleFonts.inter(
                            color: _kGrigioScuro,
                            fontSize: 15,
                          ),
                          cursorColor: _kAzzurroRomagna,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.mail_outline_rounded,
                              color: _kGrigioScuro.withValues(alpha: 0.55),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: _kAzzurroRomagna,
                                width: 1.4,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: _kGrigioScuro.withValues(alpha: 0.2),
                              ),
                            ),
                            hintText: 'E-mail',
                            hintStyle: GoogleFonts.inter(
                              color: _kGrigioScuro.withValues(alpha: 0.45),
                            ),
                            filled: true,
                            fillColor: _kCampoRiempimento,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Campo password con toggle visibilità.
                        TextField(
                          controller: _passwordController,
                          obscureText: _nascondiPassword,
                          style: GoogleFonts.inter(
                            color: _kGrigioScuro,
                            fontSize: 15,
                          ),
                          cursorColor: _kAzzurroRomagna,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: _kGrigioScuro.withValues(alpha: 0.55),
                            ),
                            suffixIcon: IconButton(
                              tooltip:
                                  _nascondiPassword
                                      ? 'Mostra password'
                                      : 'Nascondi',
                              onPressed: () {
                                setState(
                                  () => _nascondiPassword = !_nascondiPassword,
                                );
                              },
                              icon: Icon(
                                _nascondiPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _kGrigioScuro.withValues(alpha: 0.5),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: _kAzzurroRomagna,
                                width: 1.4,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: _kGrigioScuro.withValues(alpha: 0.2),
                              ),
                            ),
                            hintText: 'Password',
                            hintStyle: GoogleFonts.inter(
                              color: _kGrigioScuro.withValues(alpha: 0.45),
                            ),
                            filled: true,
                            fillColor: _kCampoRiempimento,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Pulsante principale: invia email/password a Firebase.
                        FilledButton(
                          onPressed:
                              _caricamento
                                  ? null
                                  : () => _inviaEmailPassword(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kAzzurroRomagna,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child:
                              _caricamento
                                  ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text(
                                    _modalitaAccesso ? 'Accedi' : 'Registrati',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                        ),
                        const SizedBox(height: 12),

                        // Link per passare tra login e registrazione.
                        TextButton(
                          onPressed:
                              _caricamento
                                  ? null
                                  : () {
                                    setState(() {
                                      _modalitaAccesso = !_modalitaAccesso;
                                    });
                                  },
                          child: Text(
                            _modalitaAccesso
                                ? 'Non hai un account? Registrati'
                                : 'Hai già un account? Accedi',
                            style: GoogleFonts.inter(
                              color: _kAzzurroRomagna,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Separatore visivo prima dei social.
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: _kGrigioScuro.withValues(alpha: 0.15),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                'oppure',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _kGrigioScuro.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: _kGrigioScuro.withValues(alpha: 0.15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Pulsanti social circolari minimali (Google + Facebook).
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PulsanteSocialCircolare(
                              onTap:
                                  _caricamento
                                      ? null
                                      : () => _accediConGoogle(context),
                              child: Text(
                                'G',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: _kGrigioScuro,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            _PulsanteSocialCircolare(
                              onTap:
                                  _caricamento
                                      ? null
                                      : () =>
                                          _facebookInConfigurazione(context),
                              child: Icon(
                                Icons.facebook,
                                size: 22,
                                color: _kGrigioScuro.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Link ospite: bypass login (nessuna autenticazione).
                  TextButton(
                    onPressed:
                        _caricamento ? null : () => _esploraComeOspite(context),
                    child: Text(
                      'Continua come ospite',
                      style: GoogleFonts.inter(
                        color: _kAzzurroRomagna,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration: TextDecoration.underline,
                        decorationColor: _kAzzurroRomagna,
                      ),
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
}

/// Pulsante tondo con bordo leggero: contenuto personalizzato (lettera G o icona).
class _PulsanteSocialCircolare extends StatelessWidget {
  const _PulsanteSocialCircolare({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kCampoRiempimento,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 52, height: 52, child: Center(child: child)),
      ),
    );
  }
}
