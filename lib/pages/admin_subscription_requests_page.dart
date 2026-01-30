import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../model/subscription_request.dart';

class AdminSubscriptionRequestsPage extends StatefulWidget {
  const AdminSubscriptionRequestsPage({Key? key}) : super(key: key);

  @override
  State<AdminSubscriptionRequestsPage> createState() => _AdminSubscriptionRequestsPageState();
}

class _AdminSubscriptionRequestsPageState extends State<AdminSubscriptionRequestsPage> {
  bool? isAdmin;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    checkAdmin();
  }

  Future<void> checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { isAdmin = false; loading = false; });
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    setState(() {
      isAdmin = doc.data()?['isAdmin'] == true;
      loading = false;
    });
  }

  Future<void> handleAction(DocumentSnapshot reqDoc, bool approve) async {
    setState(() { loading = true; });
    final data = reqDoc.data() as Map<String, dynamic>;
    final userId = data['userId'];
    final subscriptionType = data['subscriptionType'];
    final now = DateTime.now();
    DateTime? end;
    if (approve) {
      switch (subscriptionType) {
        case '1mois': end = DateTime(now.year, now.month + 1, now.day); break;
        case '3mois': end = DateTime(now.year, now.month + 3, now.day); break;
        case '6mois': end = DateTime(now.year, now.month + 6, now.day); break;
        case '1an': end = DateTime(now.year + 1, now.month, now.day); break;
      }
    }
    final batch = FirebaseFirestore.instance.batch();
    // Mettre à jour la demande
    batch.update(reqDoc.reference, {
      'status': approve ? 'approved' : 'rejected',
      'adminComment': approve ? 'Validé' : 'Refusé',
    });
    // Si validé, mettre à jour l'abonnement utilisateur
    if (approve && end != null) {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      batch.update(userRef, {
        'subscriptionStatus': 'active',
        'subscriptionStart': now,
        'subscriptionEnd': end,
        'subscriptionType': subscriptionType,
      });
    }
    try {
      await batch.commit();
      setState(() { loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Abonnement validé' : 'Demande refusée')),
      );
    } catch (e) {
      setState(() { loading = false; error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (isAdmin == false) {
      return const Scaffold(
        body: Center(child: Text('Accès réservé aux administrateurs.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Demandes d’abonnement')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('subscription_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('submittedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: \\${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aucune demande en attente.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(data['email'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['phoneNumber'] != null)
                        Text('Téléphone: \\${data['phoneNumber']}'),
                      Text('Montant: \\${data['amount']} FCFA'),
                      Text('Type: \\${data['subscriptionType']}'),
                      Text('ID transaction: \\${data['transactionId']}'),
                      Text('Date: \\${(data['submittedAt'] as Timestamp).toDate()}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: loading ? null : () => handleAction(docs[i], true),
                        tooltip: 'Valider',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: loading ? null : () => handleAction(docs[i], false),
                        tooltip: 'Refuser',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 