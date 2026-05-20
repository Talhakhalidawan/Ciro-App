import 'package:flutter/material.dart';
import '../utils/ciro_theme.dart';

/// Standalone Community screen.
///
/// Currently shows static mock posts. In the future this will be backed
/// by a real community endpoint.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Community Feed',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: CiroTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Real-time safety reports and community discussions',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildCommunityPost(
                username: 'ali_guajrat',
                timeAgo: '12m ago',
                content:
                    'Very high temperatures near the city center today. Staying indoors. Power outages are being reported in Sector B.',
                upvotes: 24,
                comments: 5,
                tag: 'Weather Advisory',
                tagColor: Colors.orange,
              ),
              _buildCommunityPost(
                username: 'zainab_ciro',
                timeAgo: '45m ago',
                content:
                    'Is anyone else seeing heavy smoke near the industrial park? The air quality is feeling extremely thick and dusty.',
                upvotes: 42,
                comments: 18,
                tag: 'Air Quality',
                tagColor: Colors.redAccent,
              ),
              _buildCommunityPost(
                username: 'doctor_hamza',
                timeAgo: '2h ago',
                content:
                    'Health tip: Please drink at least 4-5 liters of water today to avoid heat exhaustion. Avoid sugary drinks which cause dehydration.',
                upvotes: 112,
                comments: 29,
                tag: 'Safety Tip',
                tagColor: Colors.teal,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Individual post card ─────────────────────────────────────────

  Widget _buildCommunityPost({
    required String username,
    required String timeAgo,
    required String content,
    required int upvotes,
    required int comments,
    required String tag,
    required Color tagColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: tagColor.withValues(alpha: 0.1),
                radius: 18,
                child: Text(
                  username[0].toUpperCase(),
                  style: TextStyle(
                      color: tagColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$username',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: CiroTheme.textPrimary),
                    ),
                    Text(
                      timeAgo,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                      color: tagColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
                fontSize: 14,
                color: CiroTheme.textPrimary,
                height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.arrow_upward_rounded,
                  size: 18, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                '$upvotes',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600),
              ),
              const SizedBox(width: 24),
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 17, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                '$comments',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
