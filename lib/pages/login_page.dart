import 'package:client_mesure_firebase/service/firebase/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isLoading = false;
  bool _forLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // En-tête
              Column(
                children: [
                  const Text(
                    'Mesurix',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _forLogin ? 'Se connecter' : 'S\'inscrire',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // Message d'information
              Container(
                // width: 200,
                child: Text(
                  'La connexion via e-mail, Google, ou numéro de téléphone +223 est uniquement prise en charge dans votre région.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Form(
                key: _formKey,
                child: Column(
                    children: [
                      // Formulaire
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email/+223 Numéro de téléphone',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.email_outlined),
                              hintText: 'Entrez votre email ou numéro ',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Votre email ne dot pas être vide';
                              } else {
                                return null;
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Mot de passe',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.lock_outline),
                              hintText: 'Entrez votre mot de passe',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Votre mot de passe ne dot pas être vide';
                              } else {
                                return null;
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Confirmation de mot de passe',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!_forLogin)  TextFormField(
                            controller: _passwordConfirmController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.lock_outline),
                              hintText: 'Confirm le mot de passe',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Confirm mot de passe ne dot pas être vide';
                              } else if (value != _passwordController.text) {
                                return 'Les mots de passe ne correspondent pas';
                              } else {
                                return null;
                              }
                            },
                          ),
                        ],
                      ),

                      // const SizedBox(height: 24),
                      //
                      // // Conditions d'utilisation
                      // Row(
                      //   children: [
                      //     Checkbox(value: true, onChanged: (_) {}),
                      //     Flexible(
                      //       child: RichText(
                      //         text: TextSpan(
                      //           style: TextStyle(
                      //             color: Colors.grey[700],
                      //             fontSize: 14,
                      //           ),
                      //           children: const [
                      //             TextSpan(text: 'Je confirme avoir lu, consenti et accepté'),
                      //             TextSpan(
                      //               text: " Conditions d'utilisation de Mesurix ",
                      //               style: TextStyle(
                      //                 color: Colors.blue,
                      //                 fontWeight: FontWeight.w600,
                      //               ),
                      //             ),
                      //             TextSpan(text: ' et '),
                      //             TextSpan(
                      //               text: 'politique de confidentialité',
                      //               style: TextStyle(
                      //                 color: Colors.blue,
                      //                 fontWeight: FontWeight.w600,
                      //               ),
                      //             ),
                      //           ],
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      // ),

                      const SizedBox(height: 24),

                      // Bouton de connexion
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () async {
                            setState(() { _isLoading = true; });
                            if (_formKey.currentState!.validate()) {
                              // Login
                              try {
                                if (_forLogin) {
                                  await Auth().loginWithEmailAndPassworsd(
                                      _emailController.text,
                                      _passwordController.text
                                  );
                                } else {
                                  await Auth().createUserWithEmailAndPassworsd(
                                      _emailController.text,
                                      _passwordController.text,
                                  );
                                }
                                setState(() { _isLoading = false; });
                              } on FirebaseAuthException catch (e) {
                                setState(() { _isLoading = false; });
                                // Message erreur
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("${e.message}"),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.red,
                                    showCloseIcon: true,
                                  )
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading ? const CircularProgressIndicator() :
                          Text(_forLogin ? 'Se connecter' : 'S\'inscrire',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  )
              ),

              // Mot de passe oublié
              TextButton(
                onPressed: () {},
                child: const Text('Mot de passe oublié?'),
              ),

              const SizedBox(height: 15),

              // Séparateur
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'ou continuez avec',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                const Expanded(child: Divider()),
              ]),

              const SizedBox(height: 15),

              // Boutons de connexion sociale

              SocialLoginButton(
                icon: Image.asset(
                  'assets/png-clipart-google-google.png',
                  height: 24,
                ),
                label: 'Google',
                onPressed: () {},
              ),

              // Row(
              //   mainAxisAlignment: MainAxisAlignment.center,
              //   children: [
              //     const SizedBox(width: 24),
              //     SocialLoginButton(
              //       icon: const Icon(Icons.apple, size: 28),
              //       label: 'Apple',
              //       onPressed: () {},
              //     ),
              //   ],
              // ),

              const SizedBox(height: 10),

              // Inscription
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _forLogin
                        ? "Je n'ai pas de compte?"
                        : "J'ai déjà une compte?",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  TextButton(
                    onPressed: () {
                      _emailController.text = "";
                      _passwordController.text = "";
                      _passwordConfirmController.text = "";
                      setState(() {
                        _forLogin = !_forLogin;
                      });
                    },
                    child: Text(
                      _forLogin
                      ? 'S\'inscrire'
                      : 'Se connecter'
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  const SocialLoginButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: icon,
      label: Text(label),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}