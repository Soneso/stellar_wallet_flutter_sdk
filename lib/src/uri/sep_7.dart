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
  Map<String, String> queryParameters = {};
  Sep7OperationType operationType;
  late flutter_sdk.URIScheme uriScheme;

  Sep7Base(
      {required this.operationType,
      http.Client? httpClient,
      Map<String, String>? httpRequestHeaders}) {
    uriScheme = flutter_sdk.URIScheme(
        httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
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
    return getParam(flutter_sdk.URIScheme.messageParameterName);
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
    setParam(flutter_sdk.URIScheme.networkPassphraseParameterName,
        networkPassphrase);
  }

  /// Sets the uri 'network_passphrase' param by using the value from the given [network].
  /// Deletes the uri 'network_passphrase' param if [network] is set as null.
  /// Only need to set it if this transaction is for a network other than
  /// the public network.
  setNetwork(flutter_sdk.Network? network) {
    setParam(flutter_sdk.URIScheme.networkPassphraseParameterName,
        network?.networkPassphrase);
  }

  /// Returns a URL-decoded version of the uri 'origin_domain' param if any.
  /// This should be a fully qualified domain name that specifies the originating
  /// domain of the URI request.
  String? getOriginDomain() {
    return getParam(flutter_sdk.URIScheme.originDomainParameterName);
  }

  /// Sets and URL-encodes the uri 'origin_domain' param.
  /// Deletes the uri 'origin_domain' param if [originDomain] is set as null.
  setOriginDomain(String? originDomain) {
    setParam(flutter_sdk.URIScheme.originDomainParameterName, originDomain);
  }

  /// Sets and URL-encodes a [key] = [value] uri param.
  /// Deletes the uri param if [value] set as null.
  setParam(String key, String? value) {
    if (value == null) {
      queryParameters.remove(key);
    } else {
      queryParameters[key] = value;
    }
  }

  ///  Finds the uri param related to the inputted [key], if any, and returns
  /// a URL-decoded version of it. Returns null if [key] param not found.
  String? getParam(String key) {
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
    final signedUrl = uriScheme.signURI(toString(), keypair.keyPair);
    final signedUri = Uri.parse(signedUrl);
    final signature = signedUri
        .queryParameters[flutter_sdk.URIScheme.signatureParameterName]!;
    setParam(flutter_sdk.URIScheme.signatureParameterName, signature);
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
          httpClient: uriScheme.httpClient,
          httpRequestHeaders: uriScheme.httpRequestHeaders);
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

class Sep7Tx extends Sep7Base {
  Sep7Tx({super.httpClient,
    super.httpRequestHeaders}) :super(operationType:Sep7OperationType.tx);

  /// Sets and URL-encodes the uri [xdr] param.
  setXdr(String xdr) {
    setParam(flutter_sdk.URIScheme.xdrParameterName,
        xdr);
  }

  /// Returns a URL-decoded version of the uri 'xdr' param if any.
  String? getXdr() {
    return getParam(flutter_sdk.URIScheme.xdrParameterName);
  }

  /// Sets and URL-encodes the uri [pubKey] param.
  setPubKey(String pubKey) {
    setParam(flutter_sdk.URIScheme.publicKeyParameterName,
        pubKey);
  }

  /// Returns a URL-decoded version of the uri 'pubKey' param if any.
  String? getPubKey() {
    return getParam(flutter_sdk.URIScheme.publicKeyParameterName);
  }

  /// Sets and URL-encodes the uri [chain] param.
  setChain(String chain) {
    setParam(flutter_sdk.URIScheme.chainParameterName,
        chain);
  }

  /// Returns a URL-decoded version of the uri 'chain' param if any.
  String? getChain() {
    return getParam(flutter_sdk.URIScheme.chainParameterName);
  }

}

class Sep7Pay extends Sep7Base {
  Sep7Pay({super.httpClient,
    super.httpRequestHeaders}) :super(operationType: Sep7OperationType.pay);

  /// Sets and URL-encodes the uri [destination] param.
  setDestination(String destination) {
    setParam(flutter_sdk.URIScheme.destinationParameterName,
        destination);
  }

  /// Returns a URL-decoded version of the uri 'destination' param if any.
  String? getDestination() {
    return getParam(flutter_sdk.URIScheme.destinationParameterName);
  }

  /// Sets and URL-encodes the uri [amount] param.
  setAmount(String amount) {
    setParam(flutter_sdk.URIScheme.amountParameterName,
        amount);
  }

  /// Returns a URL-decoded version of the uri 'amount' param if any.
  String? getAmount() {
    return getParam(flutter_sdk.URIScheme.amountParameterName);
  }

  /// Sets and URL-encodes the uri [assetCode] param.
  setAssetCode(String assetCode) {
    setParam(flutter_sdk.URIScheme.assetCodeParameterName,
        assetCode);
  }

  /// Returns a URL-decoded version of the uri 'assetCode' param if any.
  String? getAssetCode() {
    return getParam(flutter_sdk.URIScheme.assetCodeParameterName);
  }

  /// Sets and URL-encodes the uri [assetIssuer] param.
  setAssetIssuer(String assetIssuer) {
    setParam(flutter_sdk.URIScheme.assetIssuerParameterName,
        assetIssuer);
  }

  /// Returns a URL-decoded version of the uri 'assetIssuer' param if any.
  String? getAssetIssuer() {
    return getParam(flutter_sdk.URIScheme.assetIssuerParameterName);
  }

  /// Sets and URL-encodes the uri [memo] param.
  setMemo(String memo) {
    setParam(flutter_sdk.URIScheme.memoCodeParameterName,
        memo);
  }

  /// Returns a URL-decoded version of the uri 'memo' param if any.
  String? getMemo() {
    return getParam(flutter_sdk.URIScheme.memoCodeParameterName);
  }

  /// Sets and URL-encodes the uri [memo] param.
  setMemoType(String memoType) {
    setParam(flutter_sdk.URIScheme.memoTypeIssuerParameterName,
        memoType);
  }

  /// Returns a URL-decoded version of the uri 'memoType' param if any.
  String? getMemoType() {
    return getParam(flutter_sdk.URIScheme.memoTypeIssuerParameterName);
  }
}
