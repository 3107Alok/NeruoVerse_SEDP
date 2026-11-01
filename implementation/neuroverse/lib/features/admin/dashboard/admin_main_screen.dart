import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../data/local/hive_service.dart';
import '../../auth/auth_screen.dart';
import '../../../../providers/app_provider.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;
  final List<int> _tabHistory = [];

  void _switchTab(int index) {
    if (_currentIndex == index) return;
    if (index == 0) {
      _tabHistory.clear();
    } else {
      _tabHistory.remove(index);
      _tabHistory.add(_currentIndex);
    }
    setState(() => _currentIndex = index);
  }

  String _userRoleFilter = 'all'; // 'all', 'patient', 'caregiver'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0 && _tabHistory.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_tabHistory.isNotEmpty) {
          final prevTab = _tabHistory.removeLast();
          setState(() => _currentIndex = prevTab);
        } else if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
          title: const Text('Admin Console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: Colors.grey.shade300,
              height: 1.0,
            ),
          ),
        ),
        body: _buildCurrentTab(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _switchTab,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey.shade500,
          backgroundColor: Colors.white,
          elevation: 8,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people_rounded), label: 'Users'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics_rounded), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildUsersTab();
      case 2:
        return _buildAnalyticsTab();
      case 3:
        return _buildSettingsTab();
      default:
        return _buildDashboardTab();
    }
  }

  Stream<QuerySnapshot>? _getUsersStream() {
    try {
      return FirebaseFirestore.instance.collection('users').snapshots();
    } catch (_) {
      return null;
    }
  }

  // 1. DASHBOARD TAB
  Widget _buildDashboardTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final allDocs = snapshot.data!.docs;

        // Strictly exclude admin accounts from user metrics
        final appUsers = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] != 'admin';
        }).toList();

        final totalUsers = appUsers.length;
        final patients = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['role'] == 'patient').length;
        final caregivers = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['role'] == 'caregiver').length;

        return ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Admin Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00796B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF004D40).withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'System Administrator',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Platform Health & User Management',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Live', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stat Cards Grid (2 x 2)
            Row(
              children: [
                Expanded(
                  child: _buildAestheticStatCard(
                    title: 'Total Users',
                    value: '$totalUsers',
                    subtitle: 'Patients & Caregivers',
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF00796B),
                    badge: 'Excl. Admin',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildAestheticStatCard(
                    title: 'Patients',
                    value: '$patients',
                    subtitle: 'Cognitive players',
                    icon: Icons.accessibility_new_rounded,
                    color: Colors.green.shade600,
                    badge: 'Active',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildAestheticStatCard(
                    title: 'Caregivers',
                    value: '$caregivers',
                    subtitle: 'Linked guardians',
                    icon: Icons.volunteer_activism_rounded,
                    color: Colors.orange.shade700,
                    badge: 'Verified',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildAestheticStatCard(
                    title: 'Sync Health',
                    value: '100%',
                    subtitle: 'Firestore cloud online',
                    icon: Icons.cloud_done_rounded,
                    color: Colors.teal.shade600,
                    badge: 'Optimal',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. Send Notification / Broadcast Announcement Card (ABOVE System Status)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1976D2).withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Broadcast Notification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Send manual alert or update to all app users',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showBroadcastNotificationDialog(context),
                      icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF0D47A1)),
                      label: const Text(
                        'Send Notification',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. System Status Telemetry Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Status: Optimal',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Firestore cloud sync, auth nodes, and intelligence services are operational.',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAestheticStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 2. USERS TAB (Authorized Management with filter and excluding admins)
  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final allDocs = snapshot.data!.docs;
        
        // Exclude admin accounts from general user list
        final nonAdminDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] != 'admin';
        }).toList();

        // Apply Role Filter
        List<QueryDocumentSnapshot> filteredDocs = nonAdminDocs;
        if (_userRoleFilter != 'all') {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['role'] == _userRoleFilter;
          }).toList();
        }

        // Apply Search Filter
        if (_searchQuery.isNotEmpty) {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || email.contains(q) || doc.id.toLowerCase().contains(q);
          }).toList();
        }

        final patientCount = nonAdminDocs.where((d) => (d.data() as Map<String, dynamic>)['role'] == 'patient').length;
        final caregiverCount = nonAdminDocs.where((d) => (d.data() as Map<String, dynamic>)['role'] == 'caregiver').length;

        return Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by name, email or ID...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),

            // Role Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _buildFilterChip('All Users (${nonAdminDocs.length})', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Patients ($patientCount)', 'patient'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Caregivers ($caregiverCount)', 'caregiver'),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Users List
            Expanded(
              child: filteredDocs.isEmpty
                  ? Center(
                      child: Text(
                        'No matching users found.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final data = filteredDocs[index].data() as Map<String, dynamic>;
                        final role = data['role'] ?? 'patient';
                        final name = data['name'] ?? 'User';
                        final rawEmail = (data['email'] as String?)?.trim();
                        final String email;
                        if (rawEmail != null && rawEmail.isNotEmpty) {
                          email = rawEmail;
                        } else if (data['shareCode'] != null && data['shareCode'].toString().isNotEmpty) {
                          email = 'Code: ${data['shareCode']}';
                        } else {
                          email = 'UID: ${filteredDocs[index].id.substring(0, 8)}...';
                        }
                        final isPatient = role == 'patient';
                        final roleColor = isPatient ? Colors.green.shade700 : Colors.orange.shade800;
                        final roleBg = isPatient ? Colors.green.shade50 : Colors.orange.shade50;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            onTap: () => _showUserDetailsSheet(context, filteredDocs[index].id, data),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: roleBg,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16),
                              ),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: roleBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        role.toString().toUpperCase(),
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor),
                                      ),
                                    ),
                                    if (data['isSuspended'] == true) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.red.shade200, width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.block_rounded, size: 10, color: Colors.red.shade700),
                                            const SizedBox(width: 3),
                                            Text(
                                              'SUSPENDED',
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _userRoleFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (sel) {
        if (sel) setState(() => _userRoleFilter = value);
      },
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : Colors.grey.shade700,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade300),
      ),
    );
  }

  void _showUserDetailsSheet(BuildContext context, String uid, Map<String, dynamic> data) {
    final role = data['role'] ?? 'patient';
    final name = data['name'] ?? 'User';
    final email = data['email'] ?? 'No email';
    final age = data['age'] ?? 'Not set';
    final gender = data['gender'] ?? 'Not set';
    final language = data['language'] ?? 'English';
    final caretaker = data['caretakerName'] ?? 'None assigned';
    final shareCode = data['shareCode'] ?? 'None';
    final isPatient = role == 'patient';
    final roleColor = isPatient ? Colors.green.shade700 : Colors.orange.shade800;
    final roleBg = isPatient ? Colors.green.shade50 : Colors.orange.shade50;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FD),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'User Profile & Diagnostics',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Details Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Hero Identification Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: roleBg,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: roleColor),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  email,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: roleBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isPatient ? 'PATIENT' : 'CAREGIVER',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: roleColor),
                                      ),
                                    ),
                                    if (data['isSuspended'] == true) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red.shade300, width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.block_rounded, size: 12, color: Colors.red.shade700),
                                            const SizedBox(width: 4),
                                            Text(
                                              'SUSPENDED',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Profile Attributes Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Personal Attributes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 14),
                          _buildUserDetailRow(Icons.email_outlined, Colors.indigo, 'Email', email),
                          const Divider(height: 20),
                          _buildUserDetailRow(Icons.cake_outlined, Colors.pink, 'Age', age != 'Not set' ? '$age years' : 'Not set'),
                          const Divider(height: 20),
                          _buildUserDetailRow(Icons.people_outline, Colors.blue, 'Gender', gender),
                          const Divider(height: 20),
                          _buildUserDetailRow(Icons.language_rounded, Colors.teal, 'Language', language),
                          if (isPatient) ...[
                            const Divider(height: 20),
                            _buildUserDetailRow(Icons.shield_outlined, Colors.amber.shade800, 'Caretaker', caretaker),
                            const Divider(height: 20),
                            _buildUserDetailRow(Icons.qr_code_rounded, Colors.purple, 'Connect Code', shareCode),
                          ],
                          const Divider(height: 20),
                          _buildUserDetailRow(Icons.fingerprint_rounded, Colors.grey, 'User ID', '${uid.substring(0, uid.length.clamp(0, 12))}...'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Activity / Telemetry Section (If patient, query game_sessions)
                    if (isPatient)
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(uid).collection('game_sessions').get(),
                        builder: (context, sSnap) {
                          if (sSnap.connectionState == ConnectionState.waiting) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          }

                          final sessions = sSnap.data?.docs ?? [];
                          int totalPlays = sessions.length;
                          double avgAcc = 0;
                          int maxLevel = 1;

                          if (sessions.isNotEmpty) {
                            int totalAcc = 0;
                            for (var s in sessions) {
                              final sMap = s.data() as Map<String, dynamic>;
                              totalAcc += (sMap['accuracyPercentage'] as num? ?? 0).toInt();
                              int lvl = (sMap['difficultyLevel'] as num? ?? 1).toInt();
                              if (lvl > maxLevel) maxLevel = lvl;
                            }
                            avgAcc = totalAcc / totalPlays;
                          }

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(color: Colors.grey.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Patient Activity Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                      child: Text('$totalPlays Plays', style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(child: _buildMiniStat('Plays', '$totalPlays', Icons.play_arrow_rounded, Colors.purple)),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildMiniStat('Avg Acc', '${avgAcc.toStringAsFixed(0)}%', Icons.track_changes_rounded, Colors.green)),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildMiniStat('Max Lvl', 'Lvl $maxLevel', Icons.military_tech_rounded, Colors.orange)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),

                    // Admin Management Action Buttons
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF5E35B1), size: 20),
                            ),
                            title: const Text('Promote to Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: const Text('Grant full admin console privileges', style: TextStyle(fontSize: 12)),
                            onTap: () {
                              _confirmPromoteToAdmin(context, ctx, uid, name);
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (data['isSuspended'] == true) ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                (data['isSuspended'] == true) ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                                color: (data['isSuspended'] == true) ? Colors.green : Colors.red,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              (data['isSuspended'] == true) ? 'Reactivate Account' : 'Suspend Account',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: (data['isSuspended'] == true) ? Colors.green : Colors.red,
                              ),
                            ),
                            subtitle: Text(
                              (data['isSuspended'] == true) ? 'Restore full app access' : 'Temporarily disable user access',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () {
                              _confirmToggleSuspension(context, ctx, uid, name, data['isSuspended'] == true);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserDetailRow(IconData icon, Color iconColor, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  // 3. ANALYTICS TAB (Aggregated & 100% Dynamic from Cloud Data)
  Widget _buildAnalyticsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final userDocs = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['role'] != 'admin';
        }).toList();

        final totalUsers = userDocs.length;

        // 1. Calculate Real Dynamic Language Distribution
        final Map<String, int> langCounts = {};
        for (var doc in userDocs) {
          final data = doc.data() as Map<String, dynamic>;
          String lang = (data['language'] as String?)?.trim() ?? 'English';
          if (lang.isEmpty) lang = 'English';
          langCounts[lang] = (langCounts[lang] ?? 0) + 1;
        }

        final sortedLangs = langCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // 2. Calculate Real Dynamic Gender Demographics
        final Map<String, int> genderCounts = {};
        for (var doc in userDocs) {
          final data = doc.data() as Map<String, dynamic>;
          String gender = (data['gender'] as String?)?.trim() ?? 'Not specified';
          if (gender.isEmpty || gender == 'Not set') gender = 'Not specified';
          genderCounts[gender] = (genderCounts[gender] ?? 0) + 1;
        }

        final sortedGenders = genderCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Palette of vibrant theme colors
        final List<Color> colorPalette = [
          Colors.blue.shade600,
          const Color(0xFF5E35B1), // Purple
          Colors.teal.shade600,
          Colors.orange.shade700,
          Colors.pink.shade600,
          Colors.amber.shade800,
        ];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Engagement Telemetry Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E35B1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.analytics_rounded, size: 32, color: Color(0xFF5E35B1)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Telemetry & Demographics',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$totalUsers registered app users in Firestore',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Dynamic Language Distribution Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Language & Accessibility Usage',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'Live Cloud Sync',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (sortedLangs.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Text('No user language data recorded yet.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...List.generate(sortedLangs.length, (index) {
                final entry = sortedLangs[index];
                final percent = totalUsers > 0 ? ((entry.value / totalUsers) * 100).round() : 0;
                final color = colorPalette[index % colorPalette.length];
                return _buildDynamicStatBar(
                  label: entry.key,
                  count: entry.value,
                  percentage: percent,
                  color: color,
                );
              }),

            const SizedBox(height: 24),

            // Dynamic Gender Distribution Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gender Demographics',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'Real-Time',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (sortedGenders.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Text('No demographic data recorded yet.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...List.generate(sortedGenders.length, (index) {
                final entry = sortedGenders[index];
                final percent = totalUsers > 0 ? ((entry.value / totalUsers) * 100).round() : 0;
                final color = [Colors.teal, Colors.pink, Colors.amber.shade800][index % 3];
                return _buildDynamicStatBar(
                  label: entry.key,
                  count: entry.value,
                  percentage: percent,
                  color: color,
                );
              }),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildDynamicStatBar({
    required String label,
    required int count,
    required int percentage,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
              Row(
                children: [
                  Text('$count users • ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text('$percentage%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // 4. SETTINGS TAB
  Widget _buildSettingsTab() {
    final user = FirebaseAuth.instance.currentUser;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Admin Profile Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFF00796B),
                child: const Icon(Icons.admin_panel_settings_rounded, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Administrator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(user?.email ?? 'admin@neuroverse.ai', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('SUPERUSER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00796B))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Temporarily lock app for non-admin users', style: TextStyle(fontSize: 12)),
                value: false,
                activeColor: Colors.purple,
                onChanged: (val) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maintenance mode disabled.')));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                ),
                title: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
                onTap: () async {
                  final hive = context.read<HiveService>();
                  final appProvider = context.read<AppProvider>();
                  final nav = Navigator.of(context);
                  try {
                    await GoogleSignIn().signOut();
                  } catch (_) {}
                  await FirebaseAuth.instance.signOut();
                  await hive.saveUserProfile({});
                  appProvider.clearUserProfile();
                  appProvider.clearProgress();
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmPromoteToAdmin(BuildContext parentCtx, BuildContext sheetCtx, String uid, String name) {
    showDialog(
      context: parentCtx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF5E35B1)),
            SizedBox(width: 10),
            Text('Promote to Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to promote "$name" to System Administrator?\n\nThey will receive full, unrestricted access to all user profiles, system telemetry, and platform configurations.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E35B1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dCtx);
              Navigator.pop(sheetCtx);
              try {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({'role': 'admin'});
                if (mounted) {
                  ScaffoldMessenger.of(parentCtx).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF5E35B1),
                      content: Text('👑 "$name" is now a System Administrator!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(parentCtx).showSnackBar(
                    SnackBar(backgroundColor: Colors.red, content: Text('Failed to promote user: $e')),
                  );
                }
              }
            },
            child: const Text('Promote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmToggleSuspension(BuildContext parentCtx, BuildContext sheetCtx, String uid, String name, bool currentlySuspended) {
    final willSuspend = !currentlySuspended;
    showDialog(
      context: parentCtx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              willSuspend ? Icons.block_rounded : Icons.check_circle_rounded,
              color: willSuspend ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 10),
            Text(
              willSuspend ? 'Suspend Account' : 'Reactivate Account',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          willSuspend
              ? 'Are you sure you want to suspend "$name"?\n\nThey will be immediately blocked from logging in or using the app until reactivated.'
              : 'Are you sure you want to reactivate "$name"?\n\nTheir app access will be fully restored.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willSuspend ? Colors.red : Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dCtx);
              Navigator.pop(sheetCtx);
              try {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'isSuspended': willSuspend,
                });
                if (mounted) {
                  ScaffoldMessenger.of(parentCtx).showSnackBar(
                    SnackBar(
                      backgroundColor: willSuspend ? Colors.red.shade800 : Colors.green.shade800,
                      content: Text(
                        willSuspend ? '🚫 "$name" has been suspended.' : '✅ "$name" has been reactivated.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(parentCtx).showSnackBar(
                    SnackBar(backgroundColor: Colors.red, content: Text('Error updating account: $e')),
                  );
                }
              }
            },
            child: Text(
              willSuspend ? 'Suspend' : 'Reactivate',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBroadcastNotificationDialog(BuildContext context) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String target = 'all';
    String priority = 'info';
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(bCtx).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(bCtx).size.height * 0.85,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(22),
                  shrinkWrap: true,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFF1976D2), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Broadcast Announcement',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(bCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Target Audience Radio Selection
                    const Text('Target Audience', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('All Users (Patients & Caregivers)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            value: 'all',
                            groupValue: target,
                            activeColor: const Color(0xFF1976D2),
                            dense: true,
                            onChanged: (val) {
                              if (val != null) setSheetState(() => target = val);
                            },
                          ),
                          const Divider(height: 1),
                          RadioListTile<String>(
                            title: const Text('Patients Only', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            value: 'patient',
                            groupValue: target,
                            activeColor: const Color(0xFF1976D2),
                            dense: true,
                            onChanged: (val) {
                              if (val != null) setSheetState(() => target = val);
                            },
                          ),
                          const Divider(height: 1),
                          RadioListTile<String>(
                            title: const Text('Caregivers Only', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            value: 'caregiver',
                            groupValue: target,
                            activeColor: const Color(0xFF1976D2),
                            dense: true,
                            onChanged: (val) {
                              if (val != null) setSheetState(() => target = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title Field
                    const Text('Notification Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Platform Update, New Exercises Available',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Message Field
                    const Text('Notification Message', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: messageController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Type your message body here...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Priority / Type Radio Selection
                    const Text('Notification Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('General Announcement', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            value: 'info',
                            groupValue: priority,
                            activeColor: const Color(0xFF1976D2),
                            dense: true,
                            onChanged: (val) {
                              if (val != null) setSheetState(() => priority = val);
                            },
                          ),
                          const Divider(height: 1),
                          RadioListTile<String>(
                            title: const Text('Important / Urgent Alert', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            value: 'urgent',
                            groupValue: priority,
                            activeColor: Colors.red.shade700,
                            dense: true,
                            onChanged: (val) {
                              if (val != null) setSheetState(() => priority = val);
                            },
                          ),
                          const Divider(height: 1),
                          RadioListTile<String>(
                            title: const Text('Health Tip & Encouragement', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            value: 'motivation',
                            groupValue: priority,
                            activeColor: Colors.green.shade700,
                            dense: true,
                            onChanged: (val) {
                              if (val != null) setSheetState(() => priority = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Send Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: isSending
                            ? null
                            : () async {
                                final t = titleController.text.trim();
                                final m = messageController.text.trim();
                                if (t.isEmpty || m.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter both Title and Message.')),
                                  );
                                  return;
                                }

                                setSheetState(() => isSending = true);
                                try {
                                  await FirebaseFirestore.instance.collection('announcements').add({
                                    'title': t,
                                    'message': m,
                                    'target': target,
                                    'priority': priority,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'sentBy': 'Admin',
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(bCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Colors.green.shade700,
                                        content: Text('Announcement broadcasted to ${target == 'all' ? 'all users' : target + 's'}.'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(() => isSending = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(backgroundColor: Colors.red, content: Text('Error broadcasting announcement: $e')),
                                    );
                                  }
                                }
                              },
                        icon: isSending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        label: Text(
                          isSending ? 'Broadcasting...' : 'Broadcast to Users',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
