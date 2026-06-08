import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String? orderNo;
  final double? totalAmount;
  final List<String> productNames;
  final String fullText;

  OcrResult({
    this.orderNo,
    this.totalAmount,
    this.productNames = const [],
    this.fullText = '',
  });
}

class _BlockInfo {
  final TextBlock block;
  final double yCenter;
  final double xMin;
  final double xMax;
  final String text;

  _BlockInfo(this.block)
      : yCenter = (block.boundingBox.top + block.boundingBox.bottom) / 2,
        xMin = block.boundingBox.left,
        xMax = block.boundingBox.right,
        text = block.text.trim();

  _BlockInfo.fromLine(TextLine line, TextBlock parentBlock)
      : yCenter = (line.boundingBox.top + line.boundingBox.bottom) / 2,
        xMin = line.boundingBox.left,
        xMax = line.boundingBox.right,
        text = line.text.trim(),
        block = TextBlock(
          text: line.text,
          boundingBox: line.boundingBox,
          lines: [line],
          cornerPoints: parentBlock.cornerPoints,
          recognizedLanguages: parentBlock.recognizedLanguages,
        );
}

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<OcrResult> recognizeFromFile(String filePath) async {
    final inputImage = InputImage.fromFilePath(filePath);
    final recognizedText = await _recognizer.processImage(inputImage);

    final fullText = recognizedText.text;
    if (fullText.trim().isEmpty) {
      return OcrResult(fullText: '');
    }

    final blocks = recognizedText.blocks
        .map((b) => _BlockInfo(b))
        .toList();

    final imageHeight = blocks.isNotEmpty
        ? blocks.map((b) => b.block.boundingBox.bottom).reduce((a, b) => a > b ? a : b)
        : 0.0;

    final orderNo = _extractOrderNo(fullText, blocks, imageHeight);
    final totalAmount = _extractTotalAmount(fullText, blocks, imageHeight);
    final productNames = _extractProductNames(blocks, imageHeight);

    return OcrResult(
      orderNo: orderNo,
      totalAmount: totalAmount,
      productNames: productNames,
      fullText: fullText,
    );
  }

  String? _extractOrderNo(String fullText, List<_BlockInfo> blocks, double imageHeight) {
    final patterns = [
      RegExp(r'订单编号[：:]\s*([\dA-Za-z\-]{6,40})'),
      RegExp(r'订单号[：:]\s*([\dA-Za-z\-]{6,40})'),
      RegExp(r'订单号码[：:]\s*([\dA-Za-z\-]{6,40})'),
      RegExp(r'order\s*(?:no|id|number)[：:.]?\s*([\dA-Za-z\-]{6,40})', caseSensitive: false),
      RegExp(r'编号[：:]\s*([\dA-Za-z\-]{10,40})'),
      RegExp(r'No\.?\s*([\dA-Za-z\-]{8,40})'),
      RegExp(r'[0-9]{15,20}'),
      RegExp(r'(\d{18,20})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(fullText);
      if (match != null) {
        final no = match.group(1)?.trim();
        if (no != null && no.length >= 6 && !no.contains(RegExp(r'^\d+\.\d+$')) && !no.contains('¥')) {
          return no;
        }
      }
    }

    for (final block in blocks) {
      if (block.text.contains(RegExp(r'[\d]{15,}'))) {
        final match = RegExp(r'(\d{15,})').firstMatch(block.text);
        if (match != null) return match.group(1)!;
      }
    }

    return null;
  }

  double? _extractTotalAmount(String fullText, List<_BlockInfo> blocks, double imageHeight) {

    final footerKeywords = [
      RegExp(r'(实付款|实付金额|应付总额|应付|合计|总计|总价|实付|总金额)[：:]\s*[¥￥]?\s*([\d,]+\.?\d*)'),
      RegExp(r'共\s*\d+\s*件.*?[¥￥]\s*([\d,]+\.?\d{2})'),
      RegExp(r'共\s*计.*?[¥￥]\s*([\d,]+\.?\d{2})'),
    ];

    for (final kw in footerKeywords) {
      final match = kw.firstMatch(fullText);
      if (match != null) {
        final amountStr = match.group(2)?.replaceAll(',', '');
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0) return amount;
        }
      }
    }

    final footerBlocks = blocks.where((b) => b.yCenter > imageHeight * 0.6).toList();
    final footerText = footerBlocks.map((b) => b.text).join('\n');

    final amounts = <double>[];
    final priceRegExp = RegExp(r'[¥￥]\s*([\d,]+\.?\d{0,2})');
    for (final match in priceRegExp.allMatches(footerText)) {
      final str = match.group(1)?.replaceAll(',', '');
      if (str != null) {
        final val = double.tryParse(str);
        if (val != null && val > 0) amounts.add(val);
      }
    }

    if (amounts.isNotEmpty) {
      amounts.sort();
      final largest = amounts.last;
      if (amounts.length > 1 && largest > amounts.first * 3) {
        return largest;
      }
      return largest;
    }

    final allAmounts = <double>[];
    final allPriceRegExp = RegExp(r'[¥￥]\s*([\d,]+\.?\d{0,2})');
    for (final match in allPriceRegExp.allMatches(fullText)) {
      final str = match.group(1)?.replaceAll(',', '');
      if (str != null) {
        final val = double.tryParse(str);
        if (val != null && val > 0) allAmounts.add(val);
      }
    }

    if (allAmounts.isNotEmpty) {
      allAmounts.sort();
      if (allAmounts.length >= 3) {
        final productAmounts = allAmounts.sublist(0, allAmounts.length - 1);
        final total = allAmounts.last;
        final sumOfRest = productAmounts.fold<double>(0, (a, b) => a + b);
        if (total > sumOfRest * 0.8 || allAmounts.length == 1) {
          return total;
        }
        return sumOfRest;
      }
      return allAmounts.reduce((a, b) => a > b ? a : b);
    }

    return null;
  }

  List<String> _extractProductNames(List<_BlockInfo> blocks, double imageHeight) {
    if (blocks.isEmpty) return [];

    final headerEnd = imageHeight * 0.22;
    final footerStart = imageHeight * 0.72;

    final lineGroups = <int, List<_BlockInfo>>{};

    for (final block in blocks) {
      if (block.yCenter < headerEnd) continue;
      if (block.yCenter > footerStart) continue;

      for (final line in block.block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        if (text.length < 2 || text.length > 120) continue;

        if (_isNonProductLine(text)) continue;

        final groupKey = (line.boundingBox.top / 10).round();
        lineGroups.putIfAbsent(groupKey, () => []);
        lineGroups[groupKey]!.add(_BlockInfo.fromLine(line, block.block));
      }
    }

    final productNames = <String>{};
    final mergedLines = <_BlockInfo>[];

    for (final group in lineGroups.values) {
      if (group.length == 1) {
        mergedLines.add(group.first);
      } else {
        for (final line in group) {
          mergedLines.add(line);
        }
      }
    }

    mergedLines.sort((a, b) => a.yCenter.compareTo(b.yCenter));

    for (final line in mergedLines) {
      final text = line.text;

      if (_isPriceLike(text) || _isStatusOnly(text)) continue;

      String cleaned = text;
      cleaned = cleaned.replaceAll(RegExp(r'[×xX\*]\s*\d+\s*$'), '').trim();
      cleaned = cleaned.replaceAll(RegExp(r'[¥￥]\s*[\d,.]+$'), '').trim();
      cleaned = cleaned.replaceAll(RegExp(r'^\s*[\d,.]+\s*'), '').trim();

      if (cleaned.isEmpty) continue;
      if (cleaned.length < 2) continue;

      if (_looksLikeProduct(cleaned)) {
        productNames.add(cleaned);
      }
    }

    if (productNames.isEmpty) {
      for (final block in blocks) {
        if (block.yCenter < headerEnd || block.yCenter > footerStart) continue;
        for (final line in block.block.lines) {
          final text = line.text.trim();
          if (text.length >= 3 && text.length <= 80 &&
              !_isPriceLike(text) && !_isStatusOnly(text) &&
              text.contains(RegExp(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]')) &&
              !_isNonProductLine(text)) {
            productNames.add(text);
          }
        }
      }
    }

    return productNames.toList();
  }

  bool _isNonProductLine(String text) {
    final noisePatterns = [
      RegExp(r'物流|快递|运费|配送|免邮|包邮|邮费'),
      RegExp(r'优惠券|满减|红包|折扣|津贴|返利|淘金币|京豆|集分宝|抵扣'),
      RegExp(r'退款|售后|退货|换货|维权|投诉|举报'),
      RegExp(r'客服|联系|咨询|电话|微信号|QQ'),
      RegExp(r'店铺|收藏|关注|分享|评价|好评|差评|追评'),
      RegExp(r'首页|搜索|购物车|我的|分类|推荐|猜你|发现'),
      RegExp(r'收货地址|收货人|手机号|详细地址|所在地区'),
      RegExp(r'支付方式|付款方式|银行卡|支付宝|微信支付|花呗|白条'),
      RegExp(r'发票|税号|抬头'),
      RegExp(r'订单编号|订单号|创建时间|付款时间|发货时间|成交时间'),
      RegExp(r'实付款|实付|合计|总计|共\d+件|商品总额|应付'),
      RegExp(r'查看物流|查看详情|确认收货|提醒发货|延长收货|申请售后'),
      RegExp(r'保障|正品|假一赔|七天无理由|极速退款|放心购|品质'),
      RegExp(r'已签收|已收货|已评价|已追评|交易成功|交易关闭'),
      RegExp(r'颜色分类|尺码|套餐类型|版本类型|数量'),
      RegExp(r'匿名|分享有礼|新人|会员|积分|签到'),
      RegExp(r'温馨提示|免责声明|使用说明|购买须知'),
    ];

    for (final pattern in noisePatterns) {
      if (pattern.hasMatch(text)) return true;
    }

    return false;
  }

  bool _isPriceLike(String text) {
    if (RegExp(r'^[¥￥]\s*[\d,.]+$').hasMatch(text)) return true;
    if (RegExp(r'^[\d,.]+$').hasMatch(text) && text.length <= 10) return true;
    if (RegExp(r'^[¥￥]\d').hasMatch(text) && text.length <= 15) return true;
    if (RegExp(r'^[×xX\*]\s*\d+$').hasMatch(text)) return true;
    if (RegExp(r'^[\d,.]+\s*[×xX\*]\s*[\d,.]+$').hasMatch(text)) return true;
    if (RegExp(r'^[\d,.]+$').hasMatch(RegExp(r'\d').allMatches(text).join()) && text.length <= 12) {
      return true;
    }
    return false;
  }

  bool _isStatusOnly(String text) {
    return text.length <= 5 &&
        RegExp(r'^(已付款|已发货|已收货|待付款|待发货|交易成功|交易关闭|退款中|已完成|待评价)$').hasMatch(text);
  }

  bool _looksLikeProduct(String text) {
    if (text.contains(RegExp(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]'))) return true;

    final productKeywords = RegExp(
      r'手办|模型|周边|盲盒|挂件|立牌|徽章|抱枕|T恤|卫衣|外套|毛绒|公仔|福袋|扭蛋'
      r'|景品|PVC|粘土|场景|贴纸|海报|明信片|色纸|色卡|吧唧|亚克力|钥匙扣|手机壳'
      r'|摆件|装饰|正版|限定|特典|初回|DX|套装|豪华',
    );
    if (productKeywords.hasMatch(text)) return true;

    if (text.length >= 4) return true;

    return false;
  }

  void dispose() {
    _recognizer.close();
  }
}