// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/anchor/sep_24.dart';
import 'package:stellar_wallet_flutter_sdk/src/anchor/sep_6.dart';
import 'package:stellar_wallet_flutter_sdk/src/auth/sep_10.dart';
import 'package:stellar_wallet_flutter_sdk/src/customer/sep_12.dart';
import 'package:stellar_wallet_flutter_sdk/src/quote/sep_38.dart';
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/toml/stellar_toml.dart';
import 'package:stellar_wallet_flutter_sdk/src/wallet.dart';
import 'package:http/http.dart' as http;

/// Build on/off ramps with anchors.
class Anchor {
  Config cfg;
  String homeDomain;
  http.Client? httpClient;
  Map<String, String>? httpRequestHeaders;
  String? lang;
  late InfoHolder infoHolder;

  Anchor(this.cfg, this.homeDomain,
      {this.httpClient, this.httpRequestHeaders, this.lang}) {

    httpClient ??= cfg.app.defaultClient;
    httpRequestHeaders ??= cfg.app.defaultHttpRequestHeaders;

    infoHolder = InfoHolder(cfg.stellar.network, homeDomain,
        httpClient: httpClient,
        httpRequestHeaders: httpRequestHeaders,
        lang: lang);
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
        httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
  }

  /// Create new customer object to handle customer records with the anchor using SEP-12.
  /// Returns [Sep12] object.
  /// Throws [KYCServerNotFoundException] if SEP-12 is not configured.
  Future<Sep12> sep12(AuthToken token) async {
    TomlInfo toml = await infoHolder.info;
    if (toml.kycServer == null) {
      throw KYCServerNotFoundException();
    }
    return Sep12(token, toml.kycServer!,
        httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
  }

  /// Creates new interactive flow for given anchor. It can be used for withdrawal or deposit.
  /// Returns [Sep24] object representing the interactive flow service.
  Sep24 sep24() {
    return Sep24(this,
        httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
  }

  /// Creates new transfer service as described in SEP-6 for given anchor.
  /// Returns [Sep6] object representing the transfer service.
  Sep6 sep6() {
    return Sep6(this,
        httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
  }

  /// Creates a quote service as described in SEP-38.
  /// Returns [Sep38] object.
  /// Throws [AnchorQuoteServerNotFoundException] if SEP-38 is not configured.
  Future<Sep38> sep38({AuthToken? authToken}) async {
    TomlInfo toml = await infoHolder.info;
    if (toml.anchorQuoteServer == null) {
      throw AnchorQuoteServerNotFoundException();
    }
    return Sep38(toml.anchorQuoteServer!,
        token: authToken,
        httpClient: httpClient,
        httpRequestHeaders: httpRequestHeaders);
  }
}

class InfoHolder {
  flutter_sdk.Network network;
  String homeDomain;
  http.Client? httpClient;
  Map<String, String>? httpRequestHeaders;
  String? lang;

  TomlInfo? _info;
  AnchorServiceInfo? _serviceInfo;

  InfoHolder(this.network, this.homeDomain,
      {this.httpClient, this.httpRequestHeaders, this.lang});

  Future<TomlInfo> get info async {
    if (_info != null) {
      return _info!;
    }
    try {
      flutter_sdk.StellarToml stellarToml =
          await flutter_sdk.StellarToml.fromDomain(homeDomain,
              httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
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
            httpClient: httpClient,
            httpRequestHeaders: httpRequestHeaders);
    flutter_sdk.SEP24InfoResponse sep24InfoResponse =
        await sep24Service.info(lang);
    _serviceInfo = AnchorServiceInfo.from(sep24InfoResponse);
    return _serviceInfo!;
  }
}

class TransactionStatus {
  final String _value;
  const TransactionStatus._internal(this._value);
  @override
  toString() => 'TransactionStatus.$_value';
  TransactionStatus(this._value);
  get value => _value;

  /// There is not yet enough information for this transaction to be initiated. Perhaps the user has
  /// not yet entered necessary info in an interactive flow
  static const incomplete = TransactionStatus._internal("incomplete");

  /// The user has not yet initiated their transfer to the anchor. This is the next necessary step in
  /// any deposit or withdrawal flow after transitioning from `incomplete`
  static const pendingUserTransferStart =
      TransactionStatus._internal("pending_user_transfer_start");

  /// The Stellar payment has been successfully received by the anchor and the off-chain funds are
  /// available for the customer to pick up. Only used for withdrawal transactions.
  static const pendingUserTransferComplete =
      TransactionStatus._internal("pending_user_transfer_complete");

  /// Pending External deposit/withdrawal has been submitted to external network, but is not yet
  /// confirmed. This is the status when waiting on Bitcoin or other external crypto network to
  /// complete a transaction, or when waiting on a bank transfer.
  static const pendingExternal =
      TransactionStatus._internal("pending_external");

  /// Deposit/withdrawal is being processed internally by anchor. This can also be used when the
  /// anchor must verify KYC information prior to deposit/withdrawal.
  static const pendingAnchor = TransactionStatus._internal("pending_anchor");

  /// Deposit/withdrawal operation has been submitted to Stellar network, but is not yet confirmed.
  static const pendingStellar = TransactionStatus._internal("pending_stellar");

  /// The user must add a trustline for the asset for the deposit to complete.
  static const pendingTrust = TransactionStatus._internal("pending_trust");

  /// The user must take additional action before the deposit / withdrawal can complete, for example
  /// an email or 2fa confirmation of a withdrawal.
  static const pendingUser = TransactionStatus._internal("pending_user");

  /// Deposit/withdrawal fully completed
  static const completed = TransactionStatus._internal("completed");

  /// The deposit/withdrawal is fully refunded
  static const refunded = TransactionStatus._internal("refunded");

  /// Funds were never received by the anchor and the transaction is considered abandoned by the
  /// user. Anchors are responsible for determining when transactions are considered expired.
  static const expired = TransactionStatus._internal("expired");

  /// Could not complete deposit because no satisfactory asset/XLM market was available
  /// to create the account
  static const noMarket = TransactionStatus._internal("no_market");

  /// Deposit/withdrawal size less than min_amount.
  static const tooSmall = TransactionStatus._internal("too_small");

  /// Deposit/withdrawal size exceeded max_amount.
  static const tooLarge = TransactionStatus._internal("too_large");

  /// Catch-all for any error not enumerated above.
  static const error = TransactionStatus._internal("error");

  /// Sep6 only: Certain pieces of information need to be updated by the user.
  static const pendingCustomerInfoUpdate =
      TransactionStatus._internal("pending_customer_info_update");

  /// Sep6 only: Certain pieces of information need to be updated by the user.
  static const pendingTransactionInfoUpdate =
      TransactionStatus._internal("pending_transaction_info_update");

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return (other is TransactionStatus && other.value == value);
  }

  @override
  int get hashCode => Object.hash(value, value);

  bool isError() {
    return (this == TransactionStatus.error ||
        this == TransactionStatus.noMarket ||
        this == TransactionStatus.tooLarge ||
        this == TransactionStatus.tooSmall);
  }

  bool isTerminal() {
    return (this == TransactionStatus.completed ||
        this == TransactionStatus.refunded ||
        this == TransactionStatus.expired ||
        isError());
  }

  static TransactionStatus? fromString(String? statusString) {
    if (incomplete.value == statusString) {
      return incomplete;
    }
    if (pendingUserTransferStart.value == statusString) {
      return pendingUserTransferStart;
    }
    if (pendingUserTransferComplete.value == statusString) {
      return pendingUserTransferComplete;
    }
    if (pendingExternal.value == statusString) {
      return pendingExternal;
    }
    if (pendingAnchor.value == statusString) {
      return pendingAnchor;
    }
    if (pendingStellar.value == statusString) {
      return pendingStellar;
    }
    if (pendingTrust.value == statusString) {
      return pendingTrust;
    }
    if (pendingUser.value == statusString) {
      return pendingUser;
    }
    if (pendingCustomerInfoUpdate.value == statusString) {
      return pendingCustomerInfoUpdate;
    }
    if (pendingTransactionInfoUpdate.value == statusString) {
      return pendingTransactionInfoUpdate;
    }
    if (completed.value == statusString) {
      return completed;
    }
    if (refunded.value == statusString) {
      return refunded;
    }
    if (expired.value == statusString) {
      return expired;
    }
    if (tooSmall.value == statusString) {
      return tooSmall;
    }
    if (tooLarge.value == statusString) {
      return tooLarge;
    }
    if (error.value == statusString) {
      return error;
    }

    return null;
  }
}

abstract class AnchorTransaction {
  String id;
  TransactionStatus status;
  String? message;

  AnchorTransaction(this.id, this.status, {this.message});
}

enum TransactionKind {
  deposit,
  withdrawal,
  depositExchange,
  withdrawalExchange
}

class MemoType {
  final String _value;
  const MemoType._internal(this._value);
  @override
  toString() => 'MemoType.$_value';
  MemoType(this._value);
  get value => _value;

  static const text = MemoType._internal("text");
  static const hash = MemoType._internal("hash");
  static const id = MemoType._internal("id");

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return (other is MemoType && other.value == value);
  }

  @override
  int get hashCode => Object.hash(value, value);
}
