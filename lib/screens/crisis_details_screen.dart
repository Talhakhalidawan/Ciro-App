import 'package:flutter/material.dart';

/// Premium modern minimalist emergency crisis details viewer.
/// Renders rich alert metadata, hazard types, safety advisories, rescue contacts, and stylized public feeds.
class CrisisDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> alertData;

  const CrisisDetailsScreen({
    super.key,
    required this.alertData,
  });

  @override
  Widget build(BuildContext context) {
    // Parsing alert properties with elegant safe fallbacks
    final String type = (alertData['type'] ?? 'Alert').toString().toUpperCase();
    final String severity = (alertData['severity'] ?? 'Moderate').toString().toUpperCase();
    final double confidenceVal = double.tryParse((alertData['confidence'] ?? '0.90').toString()) ?? 0.90;
    final String confidence = "${(confidenceVal * 100).toInt()}% CONFIDENCE";
    final String title = alertData['title'] ?? 'Active Climate Warning';
    final String details = alertData['details'] ?? 'Anomalous climate activity has been reported in the region.';
    
    final List<dynamic> safetyAdvises = alertData['safety_advises'] ?? [];
    final List<dynamic> helpResources = alertData['help_resources'] ?? [];
    final List<dynamic> topPosts = alertData['top_posts'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0F111E), // Rich, premium dark space background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.05),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        title: const Text(
          'SENTINEL SHIELD',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: Colors.white.withOpacity(0.8)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Crisis advisory link copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TOP CRITICAL STATUS BADGE ──
              _buildCriticalWarningBadge(),
              const SizedBox(height: 24),

              // ── TITLE & DYNAMIC INFO PILLS ──
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildPill(type, const Color(0xFFFF5252).withOpacity(0.12), const Color(0xFFFF5252)),
                  const SizedBox(width: 8),
                  _buildPill(severity, Colors.orangeAccent.withOpacity(0.12), Colors.orangeAccent),
                  const SizedBox(width: 8),
                  _buildPill(confidence, Colors.blueAccent.withOpacity(0.12), Colors.blueAccent),
                ],
              ),
              const SizedBox(height: 24),

              // ── DETAILS PANEL (GLASSMORPHISM) ──
              _buildGlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notes_rounded, color: Colors.white54, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'SITUATION SUMMARY',
                          style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      details,
                      style: const TextStyle(
                        color: Color(0xFFE2E4EB),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── SAFETY ADVISORIES (GRID/LIST) ──
              if (safetyAdvises.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4.0, bottom: 12),
                  child: Text(
                    'CRITICAL SAFETY ADVISORIES',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...safetyAdvises.map((advise) => _buildSafetyCard(advise.toString())),
                const SizedBox(height: 28),
              ],

              // ── EMERGENCY HELP RESOURCES ──
              if (helpResources.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4.0, bottom: 12),
                  child: Text(
                    'EMERGENCY DISPATCH SERVICES',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.8,
                  ),
                  itemCount: helpResources.length,
                  itemBuilder: (context, index) {
                    final resource = helpResources[index] as Map<String, dynamic>;
                    return _buildHelpCard(
                      name: resource['name'] ?? 'Rescue unit',
                      contact: resource['contact'] ?? '1122',
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],

              // ── SOCIAL DISPATCH FEEDS (TOP POSTS) ──
              if (topPosts.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4.0, bottom: 16),
                  child: Row(
                    children: [
                      Icon(Icons.rss_feed_rounded, color: Colors.blueAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'REAL-TIME PUBLIC BROADCASTS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topPosts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final post = topPosts[index] as Map<String, dynamic>;
                    return _buildSocialPostCard(
                      platform: post['platform'] ?? 'x',
                      title: post['title'] ?? 'Active citizen weather updates in Punjab.',
                      url: post['url'] ?? '',
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── High-Fidelity UI Component Builders ──

  Widget _buildCriticalWarningBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3333).withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: const Color(0xFFFF3333).withOpacity(0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3333), size: 16),
          const SizedBox(width: 8),
          const Text(
            'RED ZONE EMERGENCY WARNING',
            style: TextStyle(
              color: Color(0xFFFF4A4A),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label, Color bg, Color text) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSafetyCard(String advise) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: Colors.tealAccent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              advise,
              style: const TextStyle(
                color: Color(0xFFDCDFEA),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard({required String name, required String contact}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                contact,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFFF5252).withOpacity(0.1),
                child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFFF5252), size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialPostCard({
    required String platform,
    required String title,
    required String url,
  }) {
    final bool isX = platform.toLowerCase() == 'x';
    final activeColor = isX ? Colors.blueAccent : Colors.redAccent;
    final platformIcon = isX ? Icons.alternate_email_rounded : Icons.play_circle_fill_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: activeColor.withOpacity(0.12),
                    child: Icon(platformIcon, color: activeColor, size: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isX ? '@sentinel_reports' : 'Hazard Dispatch',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(Icons.open_in_new_rounded, color: Colors.white.withOpacity(0.3), size: 14),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFDCDFEA),
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
