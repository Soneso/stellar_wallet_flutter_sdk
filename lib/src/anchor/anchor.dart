// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/anchor/sep_24.dart';
import 'package:stellar_wallet_flutter_sdk/src/auth/sep_10.dart';
import 'package:stellar_wallet_flutter_sdk/src/customer/sep_12.dart';
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/toml/stellar_toml.dart';
import 'package:stellar_wallet_flutter_sdk/src/wallet.dart';
import 'package:http/http.dart' as http;

/// Build on/off ramps with anchors.
class Anchor {
  Config cfg;
  String homeDomain;
  http.Client? httpClient;
  String? lang;
  late InfoHolder infoHolder;

  Anchor(this.cfg, this.homeDomain, {this.httpClient, this.lang}) {
    infoHolder = InfoHolder(cfg.stellar.network, homeDomain,
        httpClient: httpClient, lang: lang);
  }

  /// Get anchor information from a TOML file.
  /// Returns TOML file content.
  Future<TomlInfo> sep1() async {
    return infoHolder.info;
  }

  /// Get anchor information from a TOML file.
  /// Returns TOML file content.
  Future<TomlInfo> getInfo() async {
    return infoHolder.info;
  }

  /// Create new auth object to authenticate account with the anchor using SEP-10.
  /// Returns [Sep10] object.
  /// Throws [AnchorAuthNotSupported] if SEP-10 is not configured.
  Future<Sep10> sep10() async {
    TomlInfo toml = await infoHolder.info;
    if (toml.webAuthEndpoint == null || toml.signingKey == null) {
      throw AnchorAuthNotSupported();
    }
    return Sep10(cfg, homeDomain, toml.webAuthEndpoint!, toml.signingKey!,
        httpClient: httpClient);
  }

  /// Create new customer object to handle customer records with the anchor using SEP-12.
  /// Returns [Sep12] object.
  /// Throws [KYCServerNotFoundException] if SEP-12 is not configured.
  Future<Sep12> sep12(AuthToken token) async {
    TomlInfo toml = await infoHolder.info;
    if (toml.kycServer == null) {
      throw KYCServerNotFoundException();
    }
    return Sep12(token, toml.kycServer!, httpClient: httpClient);
  }

  /// Creates new interactive flow for given anchor. It can be used for withdrawal or deposit.
  /// Returns [Sep24] object representing the interactive flow service.
  Sep24 sep24() {
    return Sep24(this, httpClient: httpClient);
  }
}

class InfoHolder {
  flutter_sdk.Network network;
  String homeDomain;
  http.Client? httpClient;
  String? lang;

  TomlInfo? _info;
  AnchorServiceInfo? _serviceInfo;

  InfoHolder(this.network, this.homeDomain, {this.httpClient, this.lang});

  Future<TomlInfo> get info async {
    if (_info != null) {
      return _info!;
    }
    try {
      flutter_sdk.StellarToml stellarToml =
          await flutter_sdk.StellarToml.fromDomain(homeDomain,
              httpClient: httpClient);
      _info = TomlInfo.from(stellarToml);
      return _info!;
    } catch (e) {
      throw TomlNotFoundException(e.toString());
    }
  }

  Future<AnchorServiceInfo> get serviceInfo async {
    if (_serviceInfo != null) {
      return _serviceInfo!;
    }

    TomlInfo tomlInfo = await info;
    if (tomlInfo.services.sep24?.transferServerSep24 == null) {
      throw AnchorInteractiveFlowNotSupported();
    }

    flutter_sdk.TransferServerSEP24Service sep24Service =
        flutter_sdk.TransferServerSEP24Service(
            tomlInfo.services.sep24!.transferServerSep24,
            httpClient: httpClient);
    flutter_sdk.SEP24InfoResponse sep24InfoResponse =
        await sep24Service.info(lang);
    _serviceInfo = AnchorServiceInfo.from(sep24InfoResponse);
    return _serviceInfo!;
  }
}
