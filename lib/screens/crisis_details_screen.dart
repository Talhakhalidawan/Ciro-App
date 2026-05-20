import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CrisisDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> alertData;

  const CrisisDetailsScreen({
    super.key,
    required this.alertData,
  });

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Strip non-numeric characters just in case, but preserve '+' if international
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not launch $launchUri');
    }
  }

  Future<void> _launchURL(String urlString) async {
    // Basic formatting to ensure it launches correctly
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    final Uri launchUri = Uri.parse(urlString);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Parsing alert properties
    final String type = (alertData['type'] ?? 'Heatwave').toString();
    final String severity = (alertData['severity'] ?? 'High').toString();
    final double confidenceVal = double.tryParse((alertData['confidence'] ?? '0.95').toString()) ?? 0.95;
    final String confidence = "${(confidenceVal * 100).toInt()}%";
    
    String capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

    final String title = alertData['title'] ?? 'Extreme Heatwave\nin Islamabad';
    final String details = alertData['details'] ?? 'Islamabad experienced a sharp temperature rise from 34.0°C to 46.0°C, indicating a severe heatwave.';
    
    final List<dynamic> safetyAdvises = alertData['safety_advises'] ?? [];
    final List<dynamic> helpResources = alertData['help_resources'] ?? [];
    final List<dynamic> topPosts = alertData['top_posts'] ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── SCROLLING NAV (BACK BUTTON) ──
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 16),
              
              // ── HEADER BADGE ──
              _buildSeverityBadge(severity),
              const SizedBox(height: 16),

              // ── TITLE ──
              Text(
                title.replaceAll(' in ', '\nin '),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),

              // ── HORIZONTALLY SCROLLING METADATA PILLS ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildPill(
                      labelPrefix: "Type: ",
                      labelValue: capitalize(type),
                      dotColor: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    _buildPill(
                      labelPrefix: "Severity: ",
                      labelValue: capitalize(severity),
                      dotColor: const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    _buildPill(
                      labelPrefix: "Confidence: ",
                      labelValue: confidence,
                      dotColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── DETAILS ──
              const Text(
                'Details',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // ── SAFETY TIPS ──
              if (safetyAdvises.isNotEmpty) ...[
                const Text(
                  'Safety Tips',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: safetyAdvises.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildInterestingSafetyCard(safetyAdvises[index].toString(), index);
                  },
                ),
                const SizedBox(height: 24),
              ],

              // ── EMERGENCY RESOURCES ──
              if (helpResources.isNotEmpty) ...[
                const Text(
                  'Emergency Resources',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCardGrid(
                  context,
                  itemCount: helpResources.length,
                  itemBuilder: (ctx, index) {
                    final res = helpResources[index];
                    String name = 'Emergency';
                    String contact = '1122';
                    
                    if (res is Map) {
                      name = res['name']?.toString() ?? name;
                      contact = res['contact']?.toString() ?? contact;
                    } else {
                      final parts = res.toString().split(' - ');
                      name = parts[0];
                      contact = parts.length > 1 ? parts[1] : contact;
                    }
                    
                    return GestureDetector(
                      onTap: () => _makePhoneCall(contact),
                      child: _buildHelpCard(name, contact),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ── INCIDENT VIDEOS ──
              if (topPosts.isNotEmpty) ...[
                const Text(
                  'Incident Videos',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topPosts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final post = topPosts[index] as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () {
                        if (post['url'] != null) _launchURL(post['url']);
                      },
                      child: _buildVideoLinkCard(
                        title: post['title'] ?? 'Video Report',
                        platform: (post['platform'] ?? 'Video').toString(),
                        url: post['url'] ?? 'No URL available',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],

              // ── BOTTOM WARNING BANNER ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 24),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Stay safe. Stay informed. Check on others.',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── COMPONENTS ──

  Widget _buildSeverityBadge(String severity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            '${severity.toUpperCase()} SEVERITY',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required String labelPrefix,
    required String labelValue,
    required Color dotColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.grey.shade300, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              text: labelPrefix,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: labelValue,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Flexible 2-column grid using IntrinsicHeight
  Widget _buildCardGrid(
    BuildContext context, {
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    List<Widget> rows = [];
    for (int i = 0; i < itemCount; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: itemBuilder(context, i)),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < itemCount
                      ? itemBuilder(context, i + 1)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildInterestingSafetyCard(String text, int index) {
    IconData iconData = Icons.health_and_safety_rounded;
    Color themeColor = const Color(0xFF10B981); // emerald green
    Color bgColor = const Color(0xFFECFDF5);

    final lowercaseText = text.toLowerCase();
    if (lowercaseText.contains('fluid') ||
        lowercaseText.contains('water') ||
        lowercaseText.contains('hydrat') ||
        lowercaseText.contains('drink')) {
      iconData = Icons.water_drop_rounded;
      themeColor = const Color(0xFF3B82F6); // blue
      bgColor = const Color(0xFFEFF6FF);
    } else if (lowercaseText.contains('sun') ||
        lowercaseText.contains('outdoor') ||
        lowercaseText.contains('sunlight') ||
        lowercaseText.contains('shade')) {
      iconData = Icons.wb_sunny_rounded;
      themeColor = const Color(0xFFF59E0B); // amber
      bgColor = const Color(0xFFFFFBEB);
    } else if (lowercaseText.contains('wear') ||
        lowercaseText.contains('cloth') ||
        lowercaseText.contains('dress')) {
      iconData = Icons.checkroom_rounded;
      themeColor = const Color(0xFF8B5CF6); // purple
      bgColor = const Color(0xFFF5F3FF);
    } else if (lowercaseText.contains('strenuous') ||
        lowercaseText.contains('exertion') ||
        lowercaseText.contains('work') ||
        lowercaseText.contains('physical')) {
      iconData = Icons.fitness_center_rounded;
      themeColor = const Color(0xFFEF4444); // red
      bgColor = const Color(0xFFFEF2F2);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Elegant customized circle avatar icon container
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                iconData,
                color: themeColor,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Content block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "ADVISORY ${index + 1}".toUpperCase(),
                  style: TextStyle(
                    color: themeColor.withOpacity(0.8),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard(String name, String contact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cleanCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.phone_in_talk_outlined, color: Colors.black87, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  contact,
                  style: const TextStyle(
                    color: Color(0xFFEF4444), // Highlight numbers in red to indicate urgency
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoLinkCard({
    required String title,
    required String platform,
    required String url,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cleanCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.play_circle_fill_rounded, color: Colors.black87, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  url,
                  style: const TextStyle(
                    color: Color(0xFF2563EB), // Standard link blue
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.open_in_new_rounded, color: Colors.black45, size: 20),
        ],
      ),
    );
  }

  BoxDecoration _cleanCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300, width: 1.0),
      // No shadow for a cleaner, flatter aesthetic
    );
  }
}