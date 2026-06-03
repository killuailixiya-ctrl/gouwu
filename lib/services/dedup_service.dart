import '../models/order_item.dart';
import '../models/product.dart';
import '../database/dao/product_dao.dart';

class DedupResult {
  final Product? matchedProduct;
  final double score;
  final String level;
  final Map<String, double> detail;

  DedupResult({
    this.matchedProduct,
    required this.score,
    required this.level,
    required this.detail,
  });

  bool get isDuplicate => level == 'high';
  bool get isPossibleDuplicate => level == 'high' || level == 'medium';
}

class DedupService {
  final ProductDao _productDao = ProductDao();

  String normalizeName(String name) {
    var normalized = name
        .replaceAll(RegExp(r'[\s]+'), ' ')
        .trim();

    normalized = normalized
        .replaceAll('正版', '')
        .replaceAll('官方', '')
        .replaceAll('包邮', '')
        .replaceAll('现货', '')
        .replaceAll('全新', '')
        .replaceAll(RegExp(r'[【\]\[]'), '')
        .trim()
        .toLowerCase();

    normalized = normalized
        .replaceAll('ver.', 'ver')
        .replaceAll('version', 'ver')
        .replaceAll('フィギュア', '手办')
        .replaceAll('figure', '手办')
        .replaceAll('スケール', '比例')
        .replaceAll('scale', '比例')
        .replaceAll('ねんどろいど', '黏土人')
        .replaceAll('nendoroid', '黏土人')
        .replaceAll('アクリル', '亚克力')
        .replaceAll('acrylic', '亚克力')
        .replaceAll('ポスター', '海报')
        .replaceAll('poster', '海报')
        .replaceAll('ぬいぐるみ', '毛绒')
        .replaceAll('plush', '毛绒')
        .replaceAll('缶バッジ', '徽章')
        .replaceAll('can badge', '徽章');

    return normalized;
  }

  List<String> tokenize(String text) {
    final normalized = normalizeName(text);
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      if (char == ' ' || char == '/' || char == '·' || char == '-') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens.where((t) => t.length > 1).toList();
  }

  double jaccardSimilarity(List<String> set1, List<String> set2) {
    if (set1.isEmpty && set2.isEmpty) return 1.0;
    if (set1.isEmpty || set2.isEmpty) return 0.0;
    final intersection = set1.where((e) => set2.contains(e)).length;
    final union = set1.toSet().union(set2.toSet()).length;
    return intersection / union;
  }

  int levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    final dp = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[len1][len2];
  }

  double editSimilarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    return 1.0 - (levenshteinDistance(s1, s2) / maxLen);
  }

  double calculateNameSimilarity(String newName, Product existingProduct) {
    final newNormalized = normalizeName(newName);
    final existingNormalized = existingProduct.normalizedName;

    if (newNormalized == existingNormalized) return 1.0;

    final newTokens = tokenize(newName);
    final existingTokens = tokenize(existingProduct.displayName);
    final jaccard = jaccardSimilarity(newTokens, existingTokens);

    final editSim = editSimilarity(newNormalized, existingNormalized);

    return jaccard * 0.6 + editSim * 0.4;
  }

  bool isSameCharacter(OrderItem newItem, Product existingProduct) {
    if (newItem.characterId != null && existingProduct.characterId != null) {
      return newItem.characterId == existingProduct.characterId;
    }
    return false;
  }

  bool isSameSeries(OrderItem newItem, Product existingProduct) {
    if (newItem.seriesId != null && existingProduct.seriesId != null) {
      return newItem.seriesId == existingProduct.seriesId;
    }
    return false;
  }

  Future<DedupResult> checkDuplicate(OrderItem newItem, {Set<String>? excludeNormalizedNames}) async {
    final allProducts = await _productDao.getAll();
    if (allProducts.isEmpty) {
      return DedupResult(score: 0, level: 'none', detail: {});
    }

    Product? bestMatch;
    double bestScore = 0;
    Map<String, double> bestDetail = {};

    for (final product in allProducts) {
      if (excludeNormalizedNames != null &&
          excludeNormalizedNames.contains(product.normalizedName)) {
        continue;
      }

      final scores = <String, double>{};

      scores['name'] = calculateNameSimilarity(newItem.name, product) * 0.45;

      if (newItem.imageHash != null && product.imageHash != null) {
        scores['image'] = 0.0;
      } else {
        scores['image'] = 0.0;
      }

      if (newItem.categoryId != null &&
          newItem.categoryId == product.categoryId) {
        scores['category'] = 0.10;
      } else {
        scores['category'] = 0.0;
      }

      if (isSameCharacter(newItem, product)) {
        scores['character'] = 0.15;
      } else if (isSameSeries(newItem, product)) {
        scores['character'] = 0.05;
      } else {
        scores['character'] = 0.0;
      }

      if (newItem.unitPrice > 0 && product.avgPrice > 0) {
        final priceDiff =
            (newItem.unitPrice - product.avgPrice).abs() / product.avgPrice;
        if (priceDiff < 0.15) {
          scores['price'] = 0.05;
        } else {
          scores['price'] = 0.0;
        }
      } else {
        scores['price'] = 0.0;
      }

      final total = scores.values.fold(0.0, (a, b) => a + b);

      if (total > bestScore) {
        bestScore = total;
        bestMatch = product;
        bestDetail = scores;
      }
    }

    String level;
    if (bestScore >= 0.80) {
      level = 'high';
    } else if (bestScore >= 0.50) {
      level = 'medium';
    } else {
      level = 'none';
    }

    return DedupResult(
      matchedProduct: bestMatch,
      score: bestScore,
      level: level,
      detail: bestDetail,
    );
  }

  Future<List<DedupResult>> checkBatch(List<OrderItem> items, {Set<String>? excludeNormalizedNames}) async {
    final results = <DedupResult>[];
    for (final item in items) {
      results.add(await checkDuplicate(item, excludeNormalizedNames: excludeNormalizedNames));
    }
    return results;
  }
}