// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/horizon/account.dart';
import 'package:http/http.dart' as http;

/// Parsing and constructing SEP-0007 Stellar URIs.
/// [SEP-07](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0007.md).
abstract class Sep7Base {
  static const operationTypeTx = 'tx';
  static const operationTypePay = 'pay';
  static const callbackParamKey = 'callback';
  static const networkPassphraseParamKey = 'network_passphrase';
  static const originDomainParamKey = 'origin_domain';
  static const signatureParamKey = 'signature';
  static const msgParamKey = 'msg';
  static const uriMsgMaxLength = 300;

  Uri uri;
  late http.Client httpClient;
  Map<String, String>? httpRequestHeaders;

  Sep7Base(
      {required this.uri, http.Client? httpClient, this.httpRequestHeaders}) {
    this.httpClient = httpClient ?? http.Client();
  }

  /// Returns a stringfied URL-decoded version of the 'uri' object.
  @override
  String toString() {
    return uri.toString();
  }

  /// Returns uri's pathname as the operation type.
  Sep7OperationType getOperationType() {
    final pathname = uri.path;
    if (uri.path == operationTypeTx) {
      return Sep7OperationType.tx;
    } else if (uri.path == operationTypePay) {
      return Sep7OperationType.pay;
    }
    throw UnsupportedSep7OperationType(
        "operation type '$pathname' is not supported");
  }

  /// Returns a URL-decoded version of the uri 'callback' param without
  /// the 'url:' prefix if any. The URI handler should send the signed XDR to
  /// this callback url, if this value is omitted then the URI handler should
  /// submit it to the network.
  String? getCallback() {
    var callback = uri.queryParameters.containsKey(callbackParamKey)
        ? uri.queryParameters[callbackParamKey]
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
      uri.queryParameters.remove(callbackParamKey);
    } else if (callback.startsWith("url:")) {
      uri.queryParameters[callbackParamKey] = callback;
    } else {
      uri.queryParameters[callbackParamKey] = 'url:$callback';
    }
  }

  /// Returns a URL-decoded version of the uri 'msg' param if any.
  /// This message should indicate any additional information that the website
  /// or application wants to show the user in her wallet.
  String? getMsg() {
    return getParam(msgParamKey);
  }

  /// Sets and URL-encodes the uri 'msg' param, the [msg] param can't
  /// be larger than 300 characters. If larger, throws [Sep7MsgTooLong].
  /// Deletes the uri [msg] param if set as null.
  /// This message should indicate any additional information that the website
  /// or application wants to show the user in her wallet.
  setMsg(String? msg) {
    if (msg == null) {
      uri.queryParameters.remove(msgParamKey);
    } else if (msg.length > uriMsgMaxLength) {
      throw Sep7MsgTooLong(
          "'msg' should be no longer than $uriMsgMaxLength characters");
    } else {
      uri.queryParameters[msgParamKey] = msg;
    }
  }

  /// Returns uri 'network_passphrase' param as [String], if not present returns
  /// the PUBLIC Network value by default: 'Public Global Stellar Network ; September 2015'.
  String getNetworkPassphrase() {
    return uri.queryParameters.containsKey(networkPassphraseParamKey)
        ? uri.queryParameters[networkPassphraseParamKey]!
        : flutter_sdk.Network.PUBLIC.networkPassphrase;
  }

  /// Returns uri 'network_passphrase' param as [flutter_sdk.Network], if not present returns
  /// the PUBLIC Network value [flutter_sdk.Network.PUBLIC]
  flutter_sdk.Network getNetwork() {
    if (uri.queryParameters.containsKey(networkPassphraseParamKey)) {
      return flutter_sdk.Network(
          uri.queryParameters[networkPassphraseParamKey]!);
    }
    return flutter_sdk.Network.PUBLIC;
  }

  /// Sets the uri 'network_passphrase' param.
  /// Deletes the uri [networkPassphrase] param if set as null.
  /// Only need to set it if this transaction is for a network other than
  /// the public network.
  setNetworkPassphrase(String? networkPassphrase) {
    setParam(networkPassphraseParamKey, networkPassphrase);
  }

  /// Sets the uri 'network_passphrase' param by using the value from the given [network].
  /// Deletes the uri 'network_passphrase' param if [network] is set as null.
  /// Only need to set it if this transaction is for a network other than
  /// the public network.
  setNetwork(flutter_sdk.Network? network) {
    setParam(networkPassphraseParamKey, network?.networkPassphrase);
  }

  /// Returns a URL-decoded version of the uri 'origin_domain' param if any.
  /// This should be a fully qualified domain name that specifies the originating
  /// domain of the URI request.
  String? getOriginDomain() {
    return getParam(originDomainParamKey);
  }

  /// Sets and URL-encodes the uri 'origin_domain' param.
  /// Deletes the uri 'origin_domain' param if [originDomain] is set as null.
  setOriginDomain(String? originDomain) {
    setParam(originDomainParamKey, originDomain);
  }

  /// Sets and URL-encodes a [key] = [value] uri param.
  /// Deletes the uri param if [value] set as null.
  setParam(String key, String? value) {
    if (value == null) {
      uri.queryParameters.remove(key);
    } else {
      uri.queryParameters[key] = value;
    }
  }

  ///  Finds the uri param related to the inputted [key], if any, and returns
  /// a URL-decoded version of it. Returns null if [key] param not found.
  String? getParam(String key) {
    return uri.queryParameters.containsKey(key)
        ? uri.queryParameters[key]
        : null;
  }

  /// Returns a URL-decoded version of the uri 'signature' param if any.
  /// This should be a signature of the hash of the URI request (excluding the
  /// 'signature' field and value itself).
  /// Wallets should use the URI_REQUEST_SIGNING_KEY specified in the
  /// origin_domain's stellar.toml file to validate this signature.
  /// If the verification fails, wallets must alert the user.
  String? getSignature() {
    return uri.queryParameters.containsKey(signatureParamKey)
        ? uri.queryParameters[signatureParamKey]
        : null;
  }

  /// Signs the URI with the given [keypair], which means it sets the 'signature' param.
  /// This should be the last step done before generating the URI string,
  /// otherwise the signature will be invalid for the URI.
  /// The given [keypair] (including secret key) is used to sign the request.
  /// This should be the keypair found in the URI_REQUEST_SIGNING_KEY field of the
  /// 'origin_domains' stellar.toml.
  String addSignature(SigningKeyPair keypair) {
    flutter_sdk.URIScheme uriScheme = flutter_sdk.URIScheme();
    final signedUrl = uriScheme.signURI(toString(), keypair.keyPair);
    final signedUri = Uri.parse(signedUrl);
    final signature = signedUri.queryParameters[signatureParamKey]!;
    setParam(signatureParamKey, signature);
    return signature;
  }

  /// Verifies that the signature added to the URI is valid.
  /// returns 'true' if the signature is valid for
  /// the current URI and origin_domain. Returns 'false' if signature verification
  /// fails, or if there is a problem looking up the stellar.toml associated with
  /// the origin_domain.
  Future<bool> verifySignature() async {
    final originDomain = getOriginDomain();
    final signature = getSignature();

    // we can fail fast if neither of them are set since we can't verify without both
    if (originDomain == null || signature == null) {
      return false;
    }

    flutter_sdk.StellarToml? toml;
    try {
      toml = await flutter_sdk.StellarToml.fromDomain(originDomain,
          httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
    } on Exception catch (_) {
      return false;
    }

    final String? uriRequestSigningKey =
        toml.generalInformation.uriRequestSigningKey;
    if (uriRequestSigningKey == null) {
      return false;
    }

    final signerPublicKey =
        flutter_sdk.KeyPair.fromAccountId(uriRequestSigningKey);
    final encodedSignature = Uri.encodeComponent(signature);
    try {
      flutter_sdk.URIScheme uriScheme = flutter_sdk.URIScheme();
      return uriScheme.verify(
          Uri.encodeFull(toString()), encodedSignature, signerPublicKey);
    } on Exception catch (_) {
      return false;
    }
  }
}

enum Sep7OperationType {
  tx,
  pay,
}
