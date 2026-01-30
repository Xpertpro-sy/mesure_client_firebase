import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/subscription_request.dart';
import 'login_page.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({Key? key}) : super(key: key);

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  String? selectedType;
  int? selectedAmount;
  final TextEditingController transactionIdController = TextEditingController();
  bool isSubmitting = false;
  bool submitted = false;

  final List<Map<String, dynamic>> options = [
    {'label': '1 mois', 'amount': 5000, 'type': '1mois'},
    {'label': '3 mois', 'amount': 15000, 'type': '3mois'},
    {'label': '6 mois', 'amount': 30000, 'type': '6mois'},
    {'label': '1 an', 'amount': 50000, 'type': '1an'},
  ];

  Future<void> submitRequest() async {
    print('=== DÉBUT SUBMIT REQUEST ===');
    
    if (selectedType == null || selectedAmount == null || transactionIdController.text.isEmpty) {
      print('❌ Données manquantes: type=$selectedType, amount=$selectedAmount, transactionId=${transactionIdController.text}');
      return;
    }
    
    setState(() { isSubmitting = true; });
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ Utilisateur non connecté');
      setState(() { isSubmitting = false; });
      return;
    }
    
    print('✅ Utilisateur connecté: ${user.email}');
    
    final request = SubscriptionRequest(
      userId: user.uid,
      email: user.email ?? '',
      phoneNumber: user.phoneNumber,
      amount: selectedAmount!,
      transactionId: transactionIdController.text.trim(),
      subscriptionType: selectedType!,
      submittedAt: DateTime.now(),
      status: 'pending',
      adminComment: null,
    );
    
    print('📝 Demande créée: ${request.toMap()}');
    
    try {
      final docRef = await FirebaseFirestore.instance.collection('subscription_requests').add(request.toMap());
      print('✅ Demande envoyée avec succès! ID: ${docRef.id}');
      
      setState(() {
        isSubmitting = false;
        submitted = true;
      });
    } catch (e) {
      print('❌ Erreur lors de l\'envoi: $e');
      setState(() { 
        isSubmitting = false; 
      });
      
      // Afficher l'erreur à l'utilisateur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (submitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Abonnement')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 80),
              SizedBox(height: 16),
              Text('Votre demande d’abonnement a été reçue.\nElle sera traitée dans les 24h.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonnement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Choisissez la durée de votre abonnement :', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: options.map((opt) => ChoiceChip(
                label: Text('${opt['label']} – ${opt['amount']} FCFA'),
                selected: selectedType == opt['type'],
                onSelected: (_) {
                  setState(() {
                    selectedType = opt['type'];
                    selectedAmount = opt['amount'];
                  });
                },
              )).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Votre demande va être traitée pendant 24h ou moins.\nUne fois que tu as validé, tu peux faire le dépôt dans +223 78 71 16 23.\nTu peux aussi contacter notre service client au +223 79 63 25 26.',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: transactionIdController,
              decoration: const InputDecoration(
                labelText: 'ID de transaction',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isSubmitting ? null : submitRequest,
              child: isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }
} 