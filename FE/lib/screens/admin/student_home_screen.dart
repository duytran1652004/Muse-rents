import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../theme/rents_colors.dart';
import '../../widgets/notification_button.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  List<dynamic> _newsArticles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() => _isLoading = true);
    try {
      // Use rss2json to parse EDMTunes RSS feed
      final response = await http.get(Uri.parse('https://api.rss2json.com/v1/api.json?rss_url=https://www.edmtunes.com/feed/'));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _newsArticles = data['items'] ?? [];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _cleanHtml(String html) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return html.replaceAll(exp, '').replaceAll('&nbsp;', ' ').trim();
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildNewsCard(Map<String, dynamic> item) {
    final title = item['title'] ?? 'Tin tức';
    final link = item['link'] ?? '';
    final pubDate = item['pubDate'] ?? '';
    final thumbnail = item['thumbnail'];
    final description = _cleanHtml(item['description'] ?? '');

    return GestureDetector(
      onTap: () => _launchUrl(link),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: RentsColors.softCardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnail != null && thumbnail.toString().isNotEmpty)
              Image.network(
                thumbnail,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: double.infinity,
                  height: 160,
                  color: RentsColors.bgGray,
                  child: const Icon(Icons.music_note, color: RentsColors.grayDark, size: 40),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 160,
                color: RentsColors.bgGray,
                child: const Icon(Icons.music_note, color: RentsColors.grayDark, size: 40),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: RentsColors.black),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(color: RentsColors.grayDark, fontSize: 13, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        pubDate.toString().split(' ').first,
                        style: const TextStyle(color: RentsColors.primaryBlue, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Xem chi tiết',
                        style: TextStyle(color: RentsColors.grayDark, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: AppBar(
        title: const Text('TIN TỨC DJ', style: TextStyle(color: RentsColors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: RentsColors.bgLightBlue,
        elevation: 0,
        leading: const NotificationButton(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue), onPressed: _fetchNews),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue))
          : _newsArticles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.article_outlined, size: 80, color: RentsColors.grayMedium),
                      const SizedBox(height: 16),
                      Text('Không thể tải tin tức',
                          style: TextStyle(color: RentsColors.grayDark.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNews,
                  color: RentsColors.primaryBlue,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _newsArticles.length,
                    itemBuilder: (context, index) => _buildNewsCard(_newsArticles[index]),
                  ),
                ),
    );
  }
}
