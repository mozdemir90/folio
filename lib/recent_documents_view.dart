import 'package:flutter/material.dart';
import 'recent_documents.dart';

class RecentDocumentsView extends StatelessWidget {
  final List<RecentDocument> recentDocuments;
  final ValueChanged<String> onOpenFile;
  final ValueChanged<String> onRemoveFile;
  final VoidCallback onClearAll;
  final bool isDark;

  const RecentDocumentsView({
    super.key,
    required this.recentDocuments,
    required this.onOpenFile,
    required this.onRemoveFile,
    required this.onClearAll,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (recentDocuments.isEmpty) {
      return const SizedBox.shrink();
    }

    final cardBg =
        isDark ? const Color(0xFF181A1F) : const Color(0xFFFFFFFF);
    final borderColor =
        isDark ? const Color(0xFF2C3038) : const Color(0xFFE2E8F0);
    final itemHoverBg =
        isDark ? const Color(0xFF22262E) : const Color(0xFFF8FAFC);

    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 480;

      return Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.only(top: 24, bottom: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Son Açılan Belgeler',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${recentDocuments.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onClearAll,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label:
                        const Text('Temizle', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade500,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: borderColor),
            // List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentDocuments.length.clamp(0, 10),
              separatorBuilder: (context, index) =>
                  Divider(height: 1, thickness: 1, color: borderColor),
              itemBuilder: (context, index) {
                final doc = recentDocuments[index];
                final fileExists = doc.exists;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    hoverColor: itemHoverBg,
                    onTap: () => onOpenFile(doc.filePath),
                    borderRadius: index == recentDocuments.length - 1
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(16))
                        : BorderRadius.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      child: Row(
                        children: [
                          // PDF icon
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: fileExists
                                  ? const Color(0xFFEF4444)
                                      .withValues(alpha: 0.12)
                                  : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 22,
                              color: fileExists
                                  ? const Color(0xFFEF4444)
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title & Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: fileExists
                                        ? null
                                        : (isDark
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade400),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (doc.relativeTime.isNotEmpty) ...[
                                      Text(
                                        doc.relativeTime,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    if (doc.formattedSize.isNotEmpty) ...[
                                      Text('•',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500)),
                                      const SizedBox(width: 6),
                                      Text(
                                        doc.formattedSize,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    if (!isCompact) ...[
                                      Text('•',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          doc.filePath,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.grey.shade500
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Remove button
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            tooltip: 'Listeden Kaldır',
                            splashRadius: 16,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onRemoveFile(doc.filePath),
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }
}
