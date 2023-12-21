// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:stellar_wallet_flutter_sdk/src/anchor/anchor.dart';
import 'package:stellar_wallet_flutter_sdk/src/auth/wallet_signer.dart';
import 'package:stellar_wallet_flutter_sdk/src/horizon/stellar.dart';
import 'package:stellar_wallet_flutter_sdk/src/recovery/sep_30.dart';

const baseReserveMinCount = 2;
const baseReserve = 0.5;

const xmlPrecision = 1e7;
const decimalPointPrecision = 7;
const stringTrimLength = 8;
const horizonLimitMax = 200;
const horizonLimitDefault = 10;

/// Wallet SDK main entry point. It provides methods to build wallet applications on the Stellar network.
class Wallet {
  static const versionNumber = "0.0.3";
  static final Map<String, String> requestHeaders = {
    "X-Client-Name": "stellar_wallet_flutter_sdk",
    "X-Client-Version": versionNumber
  };
  StellarConfiguration stellarConfiguration;
  late ApplicationConfiguration applicationConfiguration;

  Wallet(this.stellarConfiguration, {ApplicationConfiguration? applicationConfiguration}) {
    if (applicationConfiguration != null) {
      this.applicationConfiguration = applicationConfiguration;
    } else {
      this.applicationConfiguration = ApplicationConfiguration();
    }
  }

  Stellar stellar() {
    Config cfg = Config(stellarConfiguration, applicationConfiguration);
    return Stellar(cfg);
  }

  Anchor anchor(String homeDomain, {http.Client? httpClient}) {
    Config cfg = Config(stellarConfiguration, applicationConfiguration);
    return Anchor(cfg, homeDomain, httpClient: httpClient);
  }

  Recovery recovery(Map<RecoveryServerKey, RecoveryServer> servers, {http.Client? httpClient} ) {
    Config cfg = Config(stellarConfiguration, applicationConfiguration);
    return Recovery(cfg, servers, httpClient: httpClient);
  }
}

/// Configuration for all Stellar-related activity.
class StellarConfiguration {
  static final StellarConfiguration testNet = StellarConfiguration(
      flutter_sdk.Network.TESTNET, "https://horizon-testnet.stellar.org");
  static final StellarConfiguration futureNet = StellarConfiguration(
      flutter_sdk.Network.FUTURENET, "https://horizon-futurenet.stellar.org");
  static final StellarConfiguration publicNet =
      StellarConfiguration(flutter_sdk.Network.PUBLIC, "https://horizon.stellar.org");

  /// network to be used.
  flutter_sdk.Network network;

  /// URL of the Horizons server.
  String horizonUrl;

  /// default [base fee](https://developers.stellar.org/docs/encyclopedia/fees-surge-pricing-fee-strategies#network-fees-on-stellar)
  /// to be used
  int baseFee;

  /// default transaction timeout
  Duration defaultTimeout;

  /// optional HTTP client configuration to be used for Horizon calls.
  http.Client? horizonClient;

  StellarConfiguration(this.network, this.horizonUrl,
      {this.baseFee = 100,
      this.defaultTimeout = const Duration(minutes: 3),
      this.horizonClient});
}

/// Application configuration
class ApplicationConfiguration {

  /// Default signer implementation to be used across application.
  WalletSigner defaultSigner = DefaultSigner();

  /// default client_domain
  String? defaultClientDomain;

  /// optional default HTTP client configuration to be used used across the app.
  http.Client? defaultClient;

  ApplicationConfiguration(
  {WalletSigner? defaultSigner, this.defaultClientDomain, this.defaultClient}) {
    if (defaultSigner != null) {
      this.defaultSigner = defaultSigner;
    }
  }
}

class Config {
  StellarConfiguration stellar;
  ApplicationConfiguration app;

  Config(this.stellar, this.app);
}