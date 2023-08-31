// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/horizon/account.dart';
import 'package:http/http.dart' as http;
import '../wallet.dart';

/// Abstract class to provide wallet signer methods.
abstract class WalletSigner {
  signWithClientAccount(
      {required flutter_sdk.AbstractTransaction tnx,
      required flutter_sdk.Network network,
      required AccountKeyPair account});
  Future<String> signWithDomainAccount(
      {required String transactionXDR, required String networkPassPhrase});
}

class DefaultSigner extends WalletSigner {
  @override
  signWithClientAccount(
      {required flutter_sdk.AbstractTransaction tnx,
      required flutter_sdk.Network network,
      required AccountKeyPair account}) {
    if (account is SigningKeyPair) {
      account.sign(tnx, network);
    } else {
      throw ArgumentError("Can't sign with provided public keypair");
    }
  }

  @override
  Future<String> signWithDomainAccount(
      {required String transactionXDR,
      required String networkPassPhrase}) async {
    throw UnimplementedError("This signer can't sign transaction with domain");
  }
}

/// Wallet signer that supports signing with a client domain.
class DomainSigner extends DefaultSigner {
  String url;
  late http.Client httpClient;
  late Map<String, String> requestHeaders;

  DomainSigner(this.url,
      {http.Client? httpClient, Map<String, String>? requestHeaders}) {
    if (httpClient != null) {
      this.httpClient = httpClient;
    } else {
      this.httpClient = http.Client();
    }

    if (requestHeaders != null) {
      this.requestHeaders = requestHeaders;
    } else {
      this.requestHeaders = Wallet.requestHeaders;
      this.requestHeaders["Content-Type"] = "application/json";
    }
  }

  @override
  Future<String> signWithDomainAccount(
      {required String transactionXDR,
      required String networkPassPhrase}) async {
    Uri callURI = Uri.parse(url);
    Map<String, String> jsonData = {
      "transaction": transactionXDR,
      "network_passphrase": networkPassPhrase
    };

    String result = await httpClient
        .post(callURI, body: json.encode(jsonData), headers: requestHeaders)
        .then((response) {
      switch (response.statusCode) {
        case 200:
          Map<String, dynamic> jsonResponse = json.decode(response.body);
          if (jsonResponse["transaction"] == null) {
            throw DomainSignerUnexpectedResponseException(response);
          }
          return jsonResponse["transaction"]!;
        default:
          throw DomainSignerUnexpectedResponseException(response);
      }
    }).catchError((onError) {
      throw onError;
    });
    return result;
  }
}
