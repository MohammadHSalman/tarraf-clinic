import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoBox {
  final SecretKey key;
  final AesGcm algorithm = AesGcm.with256bits();
  CryptoBox(this.key);
  Future<String> sealBytes(List<int> bytes, {String context = ''}) async {
    final box = await algorithm.encrypt(
      bytes,
      secretKey: key,
      aad: utf8.encode(context),
    );
    return jsonEncode({
      'v': 2,
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    });
  }

  Future<Uint8List> openBytes(String envelope, {String context = ''}) async {
    final b = jsonDecode(envelope) as Map<String, dynamic>;
    return Uint8List.fromList(
      await algorithm.decrypt(
        SecretBox(
          base64Decode(b['c'] as String),
          nonce: base64Decode(b['n'] as String),
          mac: Mac(base64Decode(b['m'] as String)),
        ),
        secretKey: key,
        aad: utf8.encode(context),
      ),
    );
  }

  Future<String> seal(Map<String, dynamic> data, {required String context}) =>
      sealBytes(utf8.encode(jsonEncode(data)), context: context);
  Future<Map<String, dynamic>> open(
    String data, {
    required String context,
  }) async => Map<String, dynamic>.from(
    jsonDecode(utf8.decode(await openBytes(data, context: context))) as Map,
  );
}
