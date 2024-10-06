// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/horizon/account.dart';
import 'package:http/http.dart' as http;

/// Parsing and constructing SEP-0007 Stellar URIs.
/// [SEP-07](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0007.md).
abstract class Sep7 {
  Map<String, String> queryParameters = {};
  Sep7OperationType operationType;
  late flutter_sdk.URIScheme uriScheme;

  static const String memoTypeText = "MEMO_TEXT";
  static const String memoTypeId = "MEMO_ID";
  static const String memoTypeHash = "MEMO_HASH";
  static const String memoTypeReturn = "MEMO_RETURN";

  Sep7(
      {required this.operationType,
      http.Client? httpClient,
      Map<String, String>? httpRequestHeaders}) {
    uriScheme = flutter_sdk.URIScheme(
        httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
  }

  static Sep7 parseSep7Uri(String uri,
      {http.Client? httpClient, Map<String, String>? httpRequestHeaders}) {
    final uriScheme = flutter_sdk.URIScheme(
        httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
    final parseResult = uriScheme.tryParseSep7Url(uri);
    if (parseResult == null) {
      final validationResult = uriScheme.isValidSep7Url(uri);
      throw Sep7InvalidUri(validationResult.reason ?? 'invalid sep7 url');
    }
    if (parseResult.operationType == flutter_sdk.URIScheme.operationTypeTx) {
      final result = Sep7Tx(
          httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
      result.queryParameters = parseResult.queryParameters;
      return result;
    } else if (parseResult.operationType ==
        flutter_sdk.URIScheme.operationTypePay) {
      final result = Sep7Pay(
          httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
      result.queryParameters = parseResult.queryParameters;
      return result;
    } else {
      throw Sep7UriTypeNotSupported(
          "Stellar Sep-7 URI operation type '${parseResult.operationType}' is not currently supported");
    }
  }

  static IsValidSep7UriResult isValidSep7Uri(String uri) {
    final uriScheme = flutter_sdk.URIScheme();
    final validationResult = uriScheme.isValidSep7Url(uri);
    return IsValidSep7UriResult(
        result: validationResult.result, reason: validationResult.reason);
  }

  /// Takes a Sep-7 URL-decoded '[replace]' string param and parses it to a list of
  /// [Sep7Replacement] objects for easy of use.
  /// This string identifies the fields to be replaced in the XDR using
  /// the 'Txrep (SEP-0011)' representation, which should be specified in the format of:
  /// txrep_tx_field_name_1:reference_identifier_1,txrep_tx_field_name_2:reference_identifier_2;reference_identifier_1:hint_1,reference_identifier_2:hint_2
  ///
  /// @see https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0011.md
  static List<Sep7Replacement> sep7ReplacementsFromString(String replace) {
    final uriScheme = flutter_sdk.URIScheme();
    final sdkReplacements = uriScheme.uriSchemeReplacementsFromString(replace);
    var result = List<Sep7Replacement>.empty(growable: true);
    for (var item in sdkReplacements) {
      result
          .add(Sep7Replacement(id: item.id, path: item.path, hint: item.hint));
    }
    return result;
  }

  /// Takes a list of [Sep7Replacement] objects and parses it to a string that
  /// could be used as a Sep-7 URI 'replace' param.
  ///
  /// This string identifies the fields to be replaced in the XDR using
  /// the 'Txrep (SEP-0011)' representation, which should be specified in the format of:
  /// txrep_tx_field_name_1:reference_identifier_1,txrep_tx_field_name_2:reference_identifier_2;reference_identifier_1:hint_1,reference_identifier_2:hint_2
  ///
  /// @see https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0011.md
  static String sep7ReplacementsToString(List<Sep7Replacement> replacements) {
    final uriScheme = flutter_sdk.URIScheme();
    var input = List<flutter_sdk.UriSchemeReplacement>.empty(growable: true);
    for (var item in replacements) {
      input
          .add(flutter_sdk.UriSchemeReplacement(item.id, item.path, item.hint));
    }
    return uriScheme.uriSchemeReplacementsToString(input);
  }

  /// Generates the sep7 url.
  @override
  String toString() {
    final path = operationType == Sep7OperationType.tx
        ? flutter_sdk.URIScheme.operationTypeTx
        : flutter_sdk.URIScheme.operationTypePay;

    String result = "web+stellar:$path?";
    for (MapEntry e in queryParameters.entries) {
      result += "${e.key}=${Uri.encodeComponent(e.value)}&";
    }

    if (queryParameters.isNotEmpty) {
      result = result.substring(0, result.length - 1);
    }
    return result;

    /*
    // this is not working because it encodes the blanks to + not %20
    final uri = Uri(
        scheme: "web+stellar",
        pathSegments: [path],
        queryParameters: queryParameters);
    return uri.toString();
    */
  }

  /// Returns uri's pathname as the operation type.
  Sep7OperationType getOperationType() {
    return operationType;
  }

  /// Returns a URL-decoded version of the uri 'callback' param without
  /// the 'url:' prefix if any. The URI handler should send the signed XDR to
  /// this callback url, if this value is omitted then the URI handler should
  /// submit it to the network.
  String? getCallback() {
    var callback =
        queryParameters.containsKey(flutter_sdk.URIScheme.callbackParameterName)
            ? queryParameters[flutter_sdk.URIScheme.callbackParameterName]
            : null;
    if (callback != null && callback.startsWith("url:")) {
      callback = callback.substring(4);
    }
    return callback;
  }

  /// Sets and URL-encodes the uri [callback] param, appends the 'url:'
  /// prefix to it if not yet present. Deletes the uri [callback] param if set as null.
  /// The URI handler should send the signed XDR to this [callback] url, if this
  /// value is omitted then the URI handler should submit it to the network.
  setCallback(String? callback) {
    if (callback == null) {
      queryParameters.remove(flutter_sdk.URIScheme.callbackParameterName);
    } else if (callback.startsWith("url:")) {
      queryParameters[flutter_sdk.URIScheme.callbackParameterName] = callback;
    } else {
      queryParameters[flutter_sdk.URIScheme.callbackParameterName] =
          'url:$callback';
    }
  }

  /// Returns a URL-decoded version of the uri 'msg' param if any.
  /// This message should indicate any additional information that the website
  /// or application wants to show the user in her wallet.
  String? getMsg() {
    return _getParam(flutter_sdk.URIScheme.messageParameterName);
  }

  /// Sets and URL-encodes the uri 'msg' param, the [msg] param can't
  /// be larger than 300 characters. If larger, throws [Sep7MsgTooLong].
  /// Deletes the uri [msg] param if set as null.
  /// This message should indicate any additional information that the website
  /// or application wants to show the user in her wallet.
  setMsg(String? msg) {
    if (msg == null) {
      queryParameters.remove(flutter_sdk.URIScheme.messageParameterName);
    } else if (msg.length > flutter_sdk.URIScheme.messageMaxLength) {
      throw Sep7MsgTooLong(
          "'msg' should be no longer than ${flutter_sdk.URIScheme.messageMaxLength} characters");
    } else {
      queryParameters[flutter_sdk.URIScheme.messageParameterName] = msg;
    }
  }

  /// Returns uri 'network_passphrase' param as [String], if not present returns
  /// the PUBLIC Network value by default: 'Public Global Stellar Network ; September 2015'.
  String getNetworkPassphrase() {
    return queryParameters
            .containsKey(flutter_sdk.URIScheme.networkPassphraseParameterName)
        ? queryParameters[flutter_sdk.URIScheme.networkPassphraseParameterName]!
        : flutter_sdk.Network.PUBLIC.networkPassphrase;
  }

  /// Returns uri 'network_passphrase' param as [flutter_sdk.Network], if not present returns
  /// the PUBLIC Network value [flutter_sdk.Network.PUBLIC]
  flutter_sdk.Network getNetwork() {
    if (queryParameters
        .containsKey(flutter_sdk.URIScheme.networkPassphraseParameterName)) {
      return flutter_sdk.Network(queryParameters[
          flutter_sdk.URIScheme.networkPassphraseParameterName]!);
    }
    return flutter_sdk.Network.PUBLIC;
  }

  /// Sets the uri 'network_passphrase' param.
  /// Deletes the uri [networkPassphrase] param if set as null.
  /// Only need to set it if this transaction is for a network other than
  /// the public network.
  setNetworkPassphrase(String? networkPassphrase) {
    _setParam(flutter_sdk.URIScheme.networkPassphraseParameterName,
        networkPassphrase);
  }

  /// Sets the uri 'network_passphrase' param by using the value from the given [network].
  /// Deletes the uri 'network_passphrase' param if [network] is set as null.
  /// Only need to set it if this transaction is for a network other than
  /// the public network.
  setNetwork(flutter_sdk.Network? network) {
    _setParam(flutter_sdk.URIScheme.networkPassphraseParameterName,
        network?.networkPassphrase);
  }

  /// Returns a URL-decoded version of the uri 'origin_domain' param if any.
  /// This should be a fully qualified domain name that specifies the originating
  /// domain of the URI request.
  String? getOriginDomain() {
    return _getParam(flutter_sdk.URIScheme.originDomainParameterName);
  }

  /// Sets and URL-encodes the uri 'origin_domain' param.
  /// Deletes the uri 'origin_domain' param if [originDomain] is set as null.
  setOriginDomain(String? originDomain) {
    _setParam(flutter_sdk.URIScheme.originDomainParameterName, originDomain);
  }

  /// Sets and URL-encodes a [key] = [value] uri param.
  /// Deletes the uri param if [value] set as null.
  _setParam(String key, String? value) {
    if (value == null) {
      queryParameters.remove(key);
    } else {
      queryParameters[key] = value;
    }
  }

  ///  Finds the uri param related to the inputted [key], if any, and returns
  /// a URL-decoded version of it. Returns null if [key] param not found.
  String? _getParam(String key) {
    return queryParameters.containsKey(key) ? queryParameters[key] : null;
  }

  /// Returns a URL-decoded version of the uri 'signature' param if any.
  /// This should be a signature of the hash of the URI request (excluding the
  /// 'signature' field and value itself).
  /// Wallets should use the URI_REQUEST_SIGNING_KEY specified in the
  /// origin_domain's stellar.toml file to validate this signature.
  /// If the verification fails, wallets must alert the user.
  String? getSignature() {
    return queryParameters
            .containsKey(flutter_sdk.URIScheme.signatureParameterName)
        ? queryParameters[flutter_sdk.URIScheme.signatureParameterName]
        : null;
  }

  /// Signs the URI with the given [keypair], which means it sets the 'signature' param.
  /// This should be the last step done before generating the URI string,
  /// otherwise the signature will be invalid for the URI.
  /// The given [keypair] (including secret key) is used to sign the request.
  /// This should be the keypair found in the URI_REQUEST_SIGNING_KEY field of the
  /// 'origin_domains' stellar.toml.
  String addSignature(SigningKeyPair keypair) {
    final signedUrl = uriScheme.addSignature(toString(), keypair.keyPair);
    final signedUri = Uri.parse(signedUrl);
    final signature = signedUri
        .queryParameters[flutter_sdk.URIScheme.signatureParameterName]!;
    _setParam(flutter_sdk.URIScheme.signatureParameterName, signature);
    return signature;
  }

  /// Verifies that the signature added to the URI is valid.
  /// returns 'true' if the signature is valid for
  /// the current URI and origin_domain. Returns 'false' if signature verification
  /// fails, or if there is a problem looking up the stellar.toml associated with
  /// the origin_domain.
  Future<bool> verifySignature() async {
    final sep7Url = toString();
    final validationResult = await uriScheme.isValidSep7SignedUrl(sep7Url);
    return validationResult.result;
  }
}

class IsValidSep7UriResult {
  bool result;
  String? reason;
  IsValidSep7UriResult({required this.result, this.reason});
}

class Sep7Replacement {
  String id;
  String path;
  String hint;

  Sep7Replacement({required this.id, required this.path, required this.hint});
}

enum Sep7OperationType {
  tx,
  pay,
}

/// The Sep-7 'tx' operation represents a request to sign
/// a specific XDR TransactionEnvelope.
class Sep7Tx extends Sep7 {
  Sep7Tx({super.httpClient, super.httpRequestHeaders})
      : super(operationType: Sep7OperationType.tx);

  /// Creates a Sep7Tx instance with given [transaction].
  /// Sets the 'xdr' param as a Stellar TransactionEnvelope in XDR format that
  /// is base64 encoded and then URL-encoded.
  static Sep7Tx forTransaction(flutter_sdk.AbstractTransaction transaction,
      {http.Client? httpClient, Map<String, String>? httpRequestHeaders}) {
    var sep7tx =
        Sep7Tx(httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
    sep7tx.setXdr(transaction.toEnvelopeXdrBase64());
    return sep7tx;
  }

  /// Sets and URL-encodes the uri [xdr] param.
  setXdr(String xdr) {
    _setParam(flutter_sdk.URIScheme.xdrParameterName, xdr);
  }

  /// Returns a URL-decoded version of the uri 'xdr' param if any.
  String? getXdr() {
    return _getParam(flutter_sdk.URIScheme.xdrParameterName);
  }

  /// Sets and URL-encodes the uri [pubKey] param.
  setPubKey(String pubKey) {
    _setParam(flutter_sdk.URIScheme.publicKeyParameterName, pubKey);
  }

  /// Returns a URL-decoded version of the uri 'pubKey' param if any.
  String? getPubKey() {
    return _getParam(flutter_sdk.URIScheme.publicKeyParameterName);
  }

  /// Sets and URL-encodes the uri [chain] param.
  setChain(String chain) {
    _setParam(flutter_sdk.URIScheme.chainParameterName, chain);
  }

  /// Returns a URL-decoded version of the uri 'chain' param if any.
  String? getChain() {
    return _getParam(flutter_sdk.URIScheme.chainParameterName);
  }

  /// Sets and URL-encodes the uri 'replace' param, which is a list of fields in
  /// the transaction that needs to be replaced.
  ///
  /// Deletes the uri 'replace' param if set as empty array '[]' or 'null'.
  ///
  /// This 'replace' param should be a URL-encoded value that identifies the
  /// fields to be replaced in the XDR using the 'Txrep (SEP-0011)' representation.
  /// This will be specified in the format of:
  /// txrep_tx_field_name_1:reference_identifier_1,txrep_tx_field_name_2:reference_identifier_2;reference_identifier_1:hint_1,reference_identifier_2:hint_2
  ///
  /// @see https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0011.md
  setReplacements(List<Sep7Replacement>? replacements) {
    if (replacements == null || replacements.isEmpty) {
      _setParam(flutter_sdk.URIScheme.replaceParameterName, null);
    } else {
      _setParam(flutter_sdk.URIScheme.replaceParameterName,
          Sep7.sep7ReplacementsToString(replacements));
    }
  }

  /// Gets a list of fields in the transaction that need to be replaced.
  List<Sep7Replacement>? getReplacements() {
    final replaceStr = _getParam(flutter_sdk.URIScheme.replaceParameterName);
    if (replaceStr == null) {
      return null;
    }
    return Sep7.sep7ReplacementsFromString(replaceStr);
  }

  /// Adds an additional [replacement].
  addReplacement(Sep7Replacement replacement) {
    List<Sep7Replacement> replacements =
        getReplacements() ?? List<Sep7Replacement>.empty(growable: true);
    replacements.add(replacement);
    setReplacements(replacements);
  }
}

class Sep7Pay extends Sep7 {
  Sep7Pay({super.httpClient, super.httpRequestHeaders})
      : super(operationType: Sep7OperationType.pay);

  /// Creates a Sep7Pay instance with given [destination].
  static Sep7Pay forDestination(String destination,
      {http.Client? httpClient, Map<String, String>? httpRequestHeaders}) {
    var sep7pay =
        Sep7Pay(httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
    sep7pay.setDestination(destination);
    return sep7pay;
  }

  /// Sets and URL-encodes the uri [destination] param.
  setDestination(String destination) {
    _setParam(flutter_sdk.URIScheme.destinationParameterName, destination);
  }

  /// Returns a URL-decoded version of the uri 'destination' param if any.
  String? getDestination() {
    return _getParam(flutter_sdk.URIScheme.destinationParameterName);
  }

  /// Sets and URL-encodes the uri [amount] param.
  setAmount(String amount) {
    _setParam(flutter_sdk.URIScheme.amountParameterName, amount);
  }

  /// Returns a URL-decoded version of the uri 'amount' param if any.
  String? getAmount() {
    return _getParam(flutter_sdk.URIScheme.amountParameterName);
  }

  /// Sets and URL-encodes the uri [assetCode] param.
  setAssetCode(String assetCode) {
    _setParam(flutter_sdk.URIScheme.assetCodeParameterName, assetCode);
  }

  /// Returns a URL-decoded version of the uri 'assetCode' param if any.
  String? getAssetCode() {
    return _getParam(flutter_sdk.URIScheme.assetCodeParameterName);
  }

  /// Sets and URL-encodes the uri [assetIssuer] param.
  setAssetIssuer(String assetIssuer) {
    _setParam(flutter_sdk.URIScheme.assetIssuerParameterName, assetIssuer);
  }

  /// Returns a URL-decoded version of the uri 'assetIssuer' param if any.
  String? getAssetIssuer() {
    return _getParam(flutter_sdk.URIScheme.assetIssuerParameterName);
  }

  /// Sets and URL-encodes the uri [memo] param.
  setMemo(String memo) {
    _setParam(flutter_sdk.URIScheme.memoParameterName, memo);
  }

  /// Returns a URL-decoded version of the uri 'memo' param if any.
  String? getMemo() {
    return _getParam(flutter_sdk.URIScheme.memoParameterName);
  }

  /// Sets and URL-encodes the uri [memo] param.
  setMemoType(String memoType) {
    _setParam(flutter_sdk.URIScheme.memoTypeParameterName, memoType);
  }

  /// Returns a URL-decoded version of the uri 'memoType' param if any.
  String? getMemoType() {
    return _getParam(flutter_sdk.URIScheme.memoTypeParameterName);
  }
}
