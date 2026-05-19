import 'package:flutter/material.dart';

/// Premium light-theme emergency crisis details sheet matching the premium high-fidelity mockup.
class CrisisDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> alertData;

  const CrisisDetailsScreen({
    super.key,
    required this.alertData,
  });

  @override
  Widget build(BuildContext context) {
    // Parsing alert properties with elegant safe fallbacks
    final String type = (alertData['type'] ?? 'Heatwave').toString();
    final String severity = (alertData['severity'] ?? 'High').toString();
    final double confidenceVal = double.tryParse((alertData['confidence'] ?? '0.95').toString()) ?? 0.95;
    final String confidence = "${(confidenceVal * 100).toInt()}% Confidence";
    
    // Capitalize helper
    String capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

    final String title = alertData['title'] ?? 'Extreme Heatwave in Islamabad';
    final String details = alertData['details'] ?? 'Islamabad experienced a sharp temperature rise from 34.0°C to 46.0°C, indicating a severe heatwave.';
    
    final List<dynamic> safetyAdvises = alertData['safety_advises'] ?? [
      'Stay hydrated and avoid direct sunlight during peak hours.',
      'Wear light, breathable clothing and use sunscreen.'
    ];
    
    final List<dynamic> helpResources = alertData['help_resources'] ?? [
      {'name': 'Rescue 1122', 'contact': '1122'},
      {'name': 'Pakistan Meteorological Department', 'contact': '1170'}
    ];
    
    final List<dynamic> topPosts = alertData['top_posts'] ?? [
      {
        'platform': 'tiktok',
        'title': '46 Degrees Celsius | TikTok',
        'snippet': 'Discover videos related to 46 Degrees Celsius on TikTok. See more videos about 33 Degrees Celsius Weather.Uncover the...',
        'url': 'tiktok.com/discover/46-degrees-celsius'
      },
      {
        'platform': 'tiktok',
        'title': '154.1M posts. Discover videos related to 115 Degrees Hot...',
        'snippet': 'The temperature has reached 115 degrees Fahrenheit and is still rising, hot satisfying fyp weather usa USA Heatwave:...',
        'url': 'tiktok.com/discover/115-degrees-hot'
      },
      {
        'platform': 'tiktok',
        'title': '50 Degrees Temperature | TikTok',
        'snippet': 'Discover videos related to 50 Degrees Temperature on TikTok. See more videos about 50 Degrees Taif, Fits for 50 Degree...',
        'url': 'tiktok.com/discover/50-degrees-temperature'
      }
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1E2129), // Dark overlay mimicking map status area at the top
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top rounded visual gap simulating premium map background overlay
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB), // Very premium clean light grey paper background
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    // Premium thin grey horizontal drag handle
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Scrollable sheet content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── TOP CRITICAL BADGE & CLOSE BUTTON ROW ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildCriticalSeverityBadge(severity),
                                _buildCloseButton(context),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // ── ADVISORY ADJECTIVE TITLE ──
                            Text(
                              title,
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ── DYNAMIC METADATA PILLS ──
                            Row(
                              children: [
                                _buildMetadataPill(
                                  label: "Type: ${capitalize(type)}",
                                  dotColor: const Color(0xFFF97316),
                                  bgColor: const Color(0xFFFFF7ED),
                                  borderColor: const Color(0xFFFFEDD5),
                                  textColor: const Color(0xFFC2410C),
                                ),
                                const SizedBox(width: 8),
                                _buildMetadataPill(
                                  label: "Severity: ${capitalize(severity)}",
                                  dotColor: const Color(0xFFEF4444),
                                  bgColor: const Color(0xFFFEF2F2),
                                  borderColor: const Color(0xFFFEE2E2),
                                  textColor: const Color(0xFFB91C1C),
                                ),
                                const SizedBox(width: 8),
                                _buildMetadataPill(
                                  label: "Confidence: ${capitalize(confidence)}",
                                  dotColor: const Color(0xFF10B981),
                                  bgColor: const Color(0xFFF0FDF4),
                                  borderColor: const Color(0xFFDCFCE7),
                                  textColor: const Color(0xFF047857),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // ── DETAILS PANEL ──
                            const Text(
                              'Details',
                              style: TextStyle(
                                color: Color(0xFF111827),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              details,
                              style: const TextStyle(
                                color: Color(0xFF4B5563),
                                fontSize: 15,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── SAFETY ADVISES SECTION ──
                            if (safetyAdvises.isNotEmpty) ...[
                              const Text(
                                'Safety Advises',
                                style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.35,
                                ),
                                itemCount: safetyAdvises.length,
                                itemBuilder: (context, index) {
                                  final advise = safetyAdvises[index].toString();
                                  return _buildSafetyAdviseCard(advise, index);
                                },
                              ),
                              const SizedBox(height: 24),
                            ],

                            // ── HELP RESOURCES SECTION ──
                            if (helpResources.isNotEmpty) ...[
                              const Text(
                                'Help Resources',
                                style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.6,
                                ),
                                itemCount: helpResources.length,
                                itemBuilder: (context, index) {
                                  final resource = helpResources[index] as Map<String, dynamic>;
                                  return _buildHelpResourceCard(
                                    name: resource['name'] ?? 'Emergency',
                                    contact: resource['contact'] ?? '1122',
                                    index: index,
                                  );
                                },
                              ),
                              const SizedBox(height: 28),
                            ],

                            // ── TOP POSTS SECTION ──
                            if (topPosts.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Top Posts',
                                    style: TextStyle(
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Text(
                                        'Platform: ',
                                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                      ),
                                      const Text(
                                        'TikTok',
                                        style: TextStyle(
                                          color: Color(0xFF111827),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      _buildTikTokLogo(size: 14),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: topPosts.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final post = topPosts[index] as Map<String, dynamic>;
                                  return _buildSocialPostItem(
                                    title: post['title'] ?? '',
                                    snippet: post['snippet'] ?? post['details'] ?? '',
                                    url: post['url'] ?? '',
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── High-Fidelity UI Sub-Components ──

  Widget _buildCriticalSeverityBadge(String severity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444), // Bright red
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text(
            'HIGH SEVERITY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close_rounded, color: Color(0xFF374151), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Widget _buildMetadataPill({
    required String label,
    required Color dotColor,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyAdviseCard(String text, int index) {
    final bool isHydration = index == 0 || text.toLowerCase().contains('hydrat');
    final Color iconThemeColor = isHydration ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
    final IconData cardIcon = isHydration ? Icons.opacity_rounded : Icons.checkroom_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconThemeColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(cardIcon, color: iconThemeColor, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpResourceCard({
    required String name,
    required String contact,
    required int index,
  }) {
    final bool isRescue = index == 0;
    final Color themeColor = isRescue ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final IconData icon = isRescue ? Icons.phone_in_talk_rounded : Icons.wb_cloudy_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: themeColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  contact,
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 13,
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

  Widget _buildSocialPostItem({
    required String title,
    required String snippet,
    required String url,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: _buildTikTokLogo(size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  snippet,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  url,
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF9CA3AF),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTikTokLogo({required double size, Color color = Colors.black}) {
    // Elegant tiny stylized representation of the TikTok glyph
    return Icon(
      Icons.music_note_rounded,
      color: color,
      size: size,
    );
  }
}
