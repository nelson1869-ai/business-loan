import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/features/profile/providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileNotifierProvider);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('MMM dd, h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(profileNotifierProvider.notifier).loadProfile();
          await ref
              .read(profileNotifierProvider.notifier)
              .registerCurrentDevice();
        },
        child: _buildBody(context, ref, state, dateFormat, timeFormat),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ProfileState state,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    if (state.isLoading && state.profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.profile == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    state.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(profileNotifierProvider.notifier).loadProfile();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final profile = state.profile;
    if (profile == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Center(child: Text('Profile information unavailable.')),
        ],
      );
    }

    final initials = (profile.firstName.isNotEmpty ? profile.firstName[0] : '') +
        (profile.lastName.isNotEmpty ? profile.lastName[0] : '');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (profile.isFromCache)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded,
                    color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Offline Mode • Displaying cached profile',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Header Avatar Card
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF1E293B),
                  child: Text(
                    initials.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    profile.accountStatus.toUpperCase(),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Personal Information Card
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Phone Number', profile.phoneNumber),
                const Divider(height: 16),
                _buildInfoRow('Borrower ID', profile.borrowerId),
                const Divider(height: 16),
                _buildInfoRow('Member Since', dateFormat.format(profile.createdAt)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Device & Push Notification Registration Card
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Registered Device',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Icon(
                      Icons.phonelink_ring_rounded,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.deviceRegistration != null) ...[
                  _buildInfoRow('Platform', state.deviceRegistration!.platform.toUpperCase()),
                  const Divider(height: 16),
                  _buildInfoRow('Push Notifications', 'ACTIVE'),
                  const Divider(height: 16),
                  _buildInfoRow('Last Synced', timeFormat.format(state.deviceRegistration!.lastSeenAt.toLocal())),
                ] else
                  const Text(
                    'Android Device Push Token Registered',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Logout Action Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'Log Out of Borrower Portal',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
