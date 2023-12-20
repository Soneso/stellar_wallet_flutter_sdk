// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/auth/wallet_signer.dart';
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/horizon/account.dart';
import 'package:stellar_wallet_flutter_sdk/src/wallet.dart';
import 'package:http/http.dart' as http;

/// Authenticate to an external server using
/// [SEP-10](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md).
class Sep10 {
  Config cfg;
  String serverHomeDomain;
  String serverAuthEndpoint;
  String serverSigningKey;
  http.Client? httpClient;

  Sep10(this.cfg, this.serverHomeDomain, this.serverAuthEndpoint,
      this.serverSigningKey,
      {this.httpClient});

  /// Authenticates to an external server.
  /// Uses [userKeyPair] to extract the address to sign for. Optionally you can
  /// pass [momoId] to distinguish the account, [clientDomain] representing
  /// the client's domain hosting stellar.toml file containing `SIGNING_KEY`
  /// and a [clientDomainSigner] that can sign the challenge for the client if
  /// needed. Alternatively if you want to sign with the [userKeyPair] it must be a [SigningKeyPair].
  /// Returns the authentication token (jwt). Throws [AnchorAuthException]
  /// if the authentication fails.
  Future<AuthToken> authenticate(AccountKeyPair userKeyPair,
      {int? memoId,
      String? clientDomain,
      WalletSigner? clientDomainSigner}) async {
    flutter_sdk.WebAuth webAuth = flutter_sdk.WebAuth(serverAuthEndpoint,
        cfg.stellar.network, serverSigningKey, serverHomeDomain,
        httpClient: httpClient);
    try {
      String jwtToken;
      if (clientDomain != null && clientDomainSigner != null) {
        jwtToken = await webAuth.jwtToken(
            userKeyPair.address, [userKeyPair.keyPair],
            memo: memoId,
            homeDomain: serverHomeDomain,
            clientDomain: clientDomain,
            clientDomainSigningDelegate: (transaction) async {
          // delegate client signing
          return await clientDomainSigner.signWithDomainAccount(
              transactionXDR: transaction,
              networkPassPhrase: cfg.stellar.network.networkPassphrase);
        });
      } else {
        jwtToken = await webAuth.jwtToken(
            userKeyPair.address, [userKeyPair.keyPair],
            memo: memoId, homeDomain: serverHomeDomain);
      }
      return AuthToken(jwtToken);
    } catch (e) {
      throw AnchorAuthException(e.toString(), e is Exception ? e : null);
    }
  }
}

class AuthToken {
  String jwt;
  late Map<String, dynamic> decodedToken;

  AuthToken(this.jwt) {
    decodedToken = JwtDecoder.decode(jwt);
  }

  String get issuer => decodedToken["iss"];
  String get principalAccount => decodedToken["sub"];
  Duration get tokenTime => JwtDecoder.getTokenTime(jwt);
  DateTime get expiresAt => JwtDecoder.getExpirationDate(jwt);
  String? get clientDomain => decodedToken.containsKey("client_domain")
      ? decodedToken["client_domain"]
      : null;
}
