import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BorrowerListScreen extends StatelessWidget {
  const BorrowerListScreen({super.key});

  String _maskNationalId(String value) {
    if (value.length <= 4) return '****';
    return '${'*' * (value.length - 4)}${value.substring(value.length - 4)}';
  }

  String _maskPhone(String value) {
    if (value.length <= 4) return '****';
    return '${value.substring(0, 4)}****${value.substring(value.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    // List of mock borrowers to display for development/testing
    final mockBorrowers = [
      {'name': 'John Doe', 'id': '12345678', 'phone': '+254712345678'},
      {'name': 'Jane Smith', 'id': '87654321', 'phone': '+254787654321'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Borrowers')),
      body: ListView.builder(
        itemCount: mockBorrowers.length,
        itemBuilder: (context, index) {
          final borrower = mockBorrowers[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(borrower['name']!),
              subtitle: Text(
                'National ID: ${_maskNationalId(borrower['id']!)} | '
                'Phone: ${_maskPhone(borrower['phone']!)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // We'll hook up the borrower details route later
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the registration form subroute
          context.go('/borrowers/register');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
