// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/anchor/watcher.dart';
import 'package:stellar_wallet_flutter_sdk/src/asset/asset_id.dart';
import 'package:stellar_wallet_flutter_sdk/src/auth/sep_10.dart';
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/toml/stellar_toml.dart';

import 'anchor.dart';
import 'package:http/http.dart' as http;

/// Interactive flow for deposit and withdrawal using SEP-24.
class Sep24 {
  Anchor anchor;
  http.Client? httpClient;


  Sep24(this.anchor, {this.httpClient});

  /// Initiates interactive withdrawal using
  /// [SEP-24](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md).
  ///
  /// Uses the Stellar or muxed [withdrawalAccount] as the source of the withdrawal payment
  /// to the anchor, which defaults to the account authenticated via SEP-10 if not
  /// specified. The Stellar asset to withdraw must be given by [assetId]. It also needs
  /// the [authToken] token from the anchor (account's authentication using SEP-10).
  /// Optional parameters are: [extraFields] representing additional customer information
  /// to pass to the anchor.
  /// @return [InteractiveFlowResponse] object from the anchor
  /// @throws [AnchorAssetException] if asset was refused by the anchor
  Future<InteractiveFlowResponse> withdraw(
      StellarAssetId assetId, AuthToken authToken,
      {Map<String, String>? extraFields,
      Map<String, Uint8List>? extraFiles,
      String? withdrawalAccount}) async {
    TomlInfo tomlInfo = await anchor.sep1();
    if (tomlInfo.services.sep24 == null) {
      throw AnchorInteractiveFlowNotSupported();
    } else if (!tomlInfo.services.sep24!.hasAuth) {
      throw AnchorAuthNotSupported();
    }

    flutter_sdk.SEP24WithdrawRequest request =
        flutter_sdk.SEP24WithdrawRequest();
    request.jwt = authToken.jwt;
    if (assetId is IssuedAssetId) {
      request.assetCode = assetId.code;
      request.assetIssuer = assetId.issuer;
    } else if (assetId is NativeAssetId) {
      request.assetCode = assetId.id;
    }
    request.customFields = extraFields;
    request.customFiles = extraFiles;
    request.account = withdrawalAccount;

    AnchorServiceInfo serviceInfo = await getServiceInfo();
    AnchorServiceAsset? asset = serviceInfo.getWithdrawServiceAssetFor(assetId);

    if (asset == null) {
      throw AssetNotAcceptedForWithdrawalException(assetId);
    } else if (!asset.enabled) {
      throw AssetNotEnabledForWithdrawalException(assetId);
    }

    flutter_sdk.TransferServerSEP24Service service =
        flutter_sdk.TransferServerSEP24Service(
            tomlInfo.services.sep24!.transferServerSep24,
            httpClient: httpClient);
    flutter_sdk.SEP24InteractiveResponse response =
        await service.withdraw(request);
    return InteractiveFlowResponse.from(response);
  }

  /// Initiates interactive deposit using
  /// [SEP-24](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md).
  ///
  /// The Stellar asset to deposit must be given by [assetId]. It also needs
  /// the [authToken] token from the anchor (account's authentication using SEP-10).
  /// Optional parameters are: [extraFields] representing additional customer information
  /// to pass to the anchor, [destinationAccount] representing the Stellar or muxed account the client wants to use as the
  /// destination of the payment sent by the anchor. It defaults to the account authenticated via SEP-10
  /// if not specified. [destinationMemo] and [destinationMemoType] are also optional.
  /// @return [InteractiveFlowResponse] object from the anchor
  /// @throws [AnchorAssetException] if asset was refused by the anchor
  Future<InteractiveFlowResponse> deposit(
      StellarAssetId assetId, AuthToken authToken,
      {Map<String, String>? extraFields,
      Map<String, Uint8List>? extraFiles,
      String? destinationAccount,
      String? destinationMemo,
      MemoType? destinationMemoType}) async {
    TomlInfo tomlInfo = await anchor.sep1();
    if (tomlInfo.services.sep24 == null) {
      throw AnchorInteractiveFlowNotSupported();
    } else if (!tomlInfo.services.sep24!.hasAuth) {
      throw AnchorAuthNotSupported();
    }

    flutter_sdk.SEP24DepositRequest request = flutter_sdk.SEP24DepositRequest();
    request.jwt = authToken.jwt;
    if (assetId is IssuedAssetId) {
      request.assetCode = assetId.code;
      request.assetIssuer = assetId.issuer;
    } else if (assetId is NativeAssetId) {
      request.assetCode = assetId.id;
    }
    request.customFields = extraFields;
    request.customFiles = extraFiles;
    request.account = destinationAccount;

    AnchorServiceInfo serviceInfo = await getServiceInfo();
    AnchorServiceAsset? asset = serviceInfo.getDepositServiceAssetFor(assetId);

    if (asset == null) {
      throw AssetNotAcceptedForDepositException(assetId);
    } else if (!asset.enabled) {
      throw AssetNotEnabledForDepositException(assetId);
    }

    flutter_sdk.TransferServerSEP24Service service =
        flutter_sdk.TransferServerSEP24Service(
            tomlInfo.services.sep24!.transferServerSep24,
            httpClient: httpClient);
    flutter_sdk.SEP24InteractiveResponse response =
        await service.deposit(request);
    return InteractiveFlowResponse.from(response);
  }

  /// Available anchor services and information about them. For example, limits,
  /// currency, fees, payment methods.
  Future<AnchorServiceInfo> getServiceInfo() async {
    return anchor.infoHolder.serviceInfo;
  }

  /// Creates new transaction watcher.
  /// You can pass the [pollInterval] in which requests to the Anchor are being made.
  /// If not specified, it defaults to 5 seconds. You can also pass your own [exceptionHandler].
  /// By default, [RetryExceptionHandler] is being used.
  Watcher watcher(
      {Duration pollDelay = const Duration(seconds: 5),
      WalletExceptionHandler? exceptionHandler}) {
    return Watcher(
        anchor, pollDelay, exceptionHandler ?? RetryExceptionHandler());
  }

  /// Get single transaction's current status and details.
  /// Pass the [transactionId] and the [authToken] of the account authenticated with the anchor.
  /// Returns an [AnchorTransaction] object and throws [AnchorInteractiveFlowNotSupported]
  /// if SEP-24 interactive flow is not configured or [AnchorAuthNotSupported]
  /// if auth is not supported by the anchor. [AnchorTransactionNotFoundException] if any other error occurs.
  Future<AnchorTransaction> getTransaction(
      String transactionId, AuthToken authToken) async {
    flutter_sdk.SEP24TransactionRequest request =
        flutter_sdk.SEP24TransactionRequest();
    request.id = transactionId;
    request.jwt = authToken.jwt;

    TomlInfo tomlInfo = await anchor.sep1();
    if (tomlInfo.services.sep24 == null) {
      throw AnchorInteractiveFlowNotSupported();
    } else if (!tomlInfo.services.sep24!.hasAuth) {
      throw AnchorAuthNotSupported();
    }

    flutter_sdk.TransferServerSEP24Service service =
        flutter_sdk.TransferServerSEP24Service(
            tomlInfo.services.sep24!.transferServerSep24,
            httpClient: httpClient);
    try {
      flutter_sdk.SEP24TransactionResponse response =
      await service.transaction(request);
      return AnchorTransaction.fromTx(response.transaction);
    } on Exception catch(e) {
      throw AnchorTransactionNotFoundException("Transaction not found", e);
    }
  }

  /// Get single transaction's current status and details. One of the [id], [stellarTransactionId],
  /// [externalTransactionId] must be provided, otherwise it throws a [ValidationException].
  /// [authToken] of the account authenticated with the anchor is also mandatory.
  /// Returns an [AnchorTransaction] object and throws [AnchorInteractiveFlowNotSupported]
  /// if SEP-24 interactive flow is not configured or [AnchorAuthNotSupported] if
  /// auth is not supported by the anchor. [AnchorTransactionNotFoundException] if any other error occurs.
  Future<AnchorTransaction> getTransactionBy(AuthToken authToken,
      {String? id,
      String? stellarTransactionId,
      String? externalTransactionId,
      String? lang}) async {
    if (id == null &&
        stellarTransactionId == null &&
        externalTransactionId == null) {
      throw ValidationException(
          "One of id, stellarTransactionId or externalTransactionId is required.");
    }

    TomlInfo tomlInfo = await anchor.sep1();
    if (tomlInfo.services.sep24 == null) {
      throw AnchorInteractiveFlowNotSupported();
    } else if (!tomlInfo.services.sep24!.hasAuth) {
      throw AnchorAuthNotSupported();
    }

    flutter_sdk.SEP24TransactionRequest request =
        flutter_sdk.SEP24TransactionRequest();
    request.id = id;
    request.stellarTransactionId = stellarTransactionId;
    request.externalTransactionId = externalTransactionId;
    request.lang = lang;
    request.jwt = authToken.jwt;

    flutter_sdk.TransferServerSEP24Service service =
        flutter_sdk.TransferServerSEP24Service(
            tomlInfo.services.sep24!.transferServerSep24,
            httpClient: httpClient);

    try {
      flutter_sdk.SEP24TransactionResponse response =
      await service.transaction(request);
      return AnchorTransaction.fromTx(response.transaction);
    } on Exception catch(e) {
      throw AnchorTransactionNotFoundException("Transaction not found", e);
    }
  }

  /// Get all account's transactions by specified asset. See SEP-24 specification for parameters
  /// [asset] is the target asset to query for. [authToken] of the account authenticated with the anchor is also mandatory.
  /// Optional parameters: [noOlderThan] - The response should contain transactions starting on or after this date &
  /// time. The response should contain at most [limit] transactions. The [kind] of transaction that is desired.
  /// [pagingId] - The response should contain transactions starting prior to this ID (exclusive).
  /// [lang] - Language to use - [RFC 4646](https://www.rfc-editor.org/rfc/rfc4646), default is `en`
  /// Returns a list of [AnchorTransaction] objects and throws [AnchorInteractiveFlowNotSupported]
  /// if SEP-24 interactive flow is not configured or [AnchorAuthNotSupported] if
  /// auth is not supported by the anchor.
  Future<List<AnchorTransaction>> getTransactionsForAsset(
      AssetId asset, AuthToken authToken,
      {DateTime? noOlderThan,
      int? limit,
      TransactionKind? kind,
      String? pagingId,
      String? lang}) async {
    TomlInfo tomlInfo = await anchor.sep1();
    if (tomlInfo.services.sep24 == null) {
      throw AnchorInteractiveFlowNotSupported();
    } else if (!tomlInfo.services.sep24!.hasAuth) {
      throw AnchorAuthNotSupported();
    }

    flutter_sdk.SEP24TransactionsRequest request =
        flutter_sdk.SEP24TransactionsRequest();
    request.jwt = authToken.jwt;
    if (asset is IssuedAssetId) {
      request.assetCode = asset.code;
    } else {
      request.assetCode = asset.id;
    }
    request.noOlderThan = noOlderThan;
    request.limit = limit;
    if (kind != null) {
      switch (kind) {
        case TransactionKind.deposit:
          request.kind = "deposit";
        case TransactionKind.withdrawal:
          request.kind = "withdrawal";
      }
    }
    request.pagingId = pagingId;
    request.lang = lang;

    flutter_sdk.TransferServerSEP24Service service =
        flutter_sdk.TransferServerSEP24Service(
            tomlInfo.services.sep24!.transferServerSep24,
            httpClient: httpClient);
    flutter_sdk.SEP24TransactionsResponse response =
        await service.transactions(request);
    List<AnchorTransaction> result =
        List<AnchorTransaction>.empty(growable: true);
    for (flutter_sdk.SEP24Transaction tx in response.transactions) {
      result.add(AnchorTransaction.fromTx(tx));
    }
    return result;
  }

  /// Get all successfully finished (either completed or refunded) account transactions for specified
  /// asset. Optional field implementation depends on anchor.
  /// [asset] is the asset to query for. [authToken] of the account authenticated with the anchor is also mandatory.
  /// Optional parameters: [noOlderThan] - The response should contain transactions starting on or after this date &
  /// time. The response should contain at most [limit] transactions.
  /// [pagingId] - The response should contain transactions starting prior to this ID (exclusive).
  /// [lang] - Language to use - [RFC 4646](https://www.rfc-editor.org/rfc/rfc4646), default is `en`
  /// Returns a list of [AnchorTransaction] objects and throws [AnchorInteractiveFlowNotSupported]
  /// if SEP-24 interactive flow is not configured or [AnchorAuthNotSupported] if
  /// auth is not supported by the anchor. Also throws [AssetNotSupportedException]
  /// if the given [asset] is not supported by the anchor.
  Future<List<AnchorTransaction>> getHistory(AssetId asset, AuthToken authToken,
      {DateTime? noOlderThan,
      int? limit,
      String? pagingId,
      String? lang}) async {
    flutter_sdk.SEP24TransactionsRequest request =
        flutter_sdk.SEP24TransactionsRequest();
    request.jwt = authToken.jwt;
    if (asset is IssuedAssetId) {
      request.assetCode = asset.code;
    } else {
      request.assetCode = asset.id;
    }
    request.noOlderThan = noOlderThan;
    request.limit = limit;
    request.pagingId = pagingId;
    request.lang = lang;

    TomlInfo tomlInfo = await anchor.sep1();
    if (tomlInfo.services.sep24 == null) {
      throw AnchorInteractiveFlowNotSupported();
    } else if (!tomlInfo.services.sep24!.hasAuth) {
      throw AnchorAuthNotSupported();
    }

    bool currencySupported = false;
    if (tomlInfo.currencies != null) {
      for (InfoCurrency currency in tomlInfo.currencies!) {
        if (currency.code == request.assetCode) {
          currencySupported = true;
        }
      }
    }
    if (!currencySupported) {
      throw AssetNotSupportedException(asset);
    }

    flutter_sdk.TransferServerSEP24Service service =
        flutter_sdk.TransferServerSEP24Service(
            tomlInfo.services.sep24!.transferServerSep24,
            httpClient: httpClient);
    flutter_sdk.SEP24TransactionsResponse response =
        await service.transactions(request);
    List<AnchorTransaction> result =
        List<AnchorTransaction>.empty(growable: true);
    for (flutter_sdk.SEP24Transaction tx in response.transactions) {
      result.add(AnchorTransaction.fromTx(tx));
    }
    return result;
  }
}

class InteractiveFlowResponse {
  String id;
  String url;
  String type;

  InteractiveFlowResponse(this.id, this.url, this.type);

  static InteractiveFlowResponse from(
      flutter_sdk.SEP24InteractiveResponse response) {
    return InteractiveFlowResponse(response.id, response.url, response.type);
  }
}

class AnchorTransactionStatusResponse {
  AnchorTransaction transaction;
  AnchorTransactionStatusResponse(this.transaction);
}

class AnchorAllTransactionsResponse {
  List<AnchorTransaction> transactions;

  AnchorAllTransactionsResponse(this.transactions);
}

class AnchorServiceAsset {
  bool enabled;
  double? minAmount;
  double? maxAmount;
  double? feeFixed;
  double? feePercent;
  double? feeMinimum;

  AnchorServiceAsset(this.enabled);

  static AnchorServiceAsset fromSep24DepositAsset(
      flutter_sdk.SEP24DepositAsset sep24DepositAsset) {
    AnchorServiceAsset result = AnchorServiceAsset(sep24DepositAsset.enabled);
    result.minAmount = sep24DepositAsset.minAmount;
    result.maxAmount = sep24DepositAsset.maxAmount;
    result.feeFixed = sep24DepositAsset.feeFixed;
    result.feePercent = sep24DepositAsset.feePercent;
    result.feeMinimum = sep24DepositAsset.feeMinimum;
    return result;
  }

  static AnchorServiceAsset fromSep24WithdrawAsset(
      flutter_sdk.SEP24WithdrawAsset sep24WithdrawAsset) {
    AnchorServiceAsset result = AnchorServiceAsset(sep24WithdrawAsset.enabled);
    result.minAmount = sep24WithdrawAsset.minAmount;
    result.maxAmount = sep24WithdrawAsset.maxAmount;
    result.feeFixed = sep24WithdrawAsset.feeFixed;
    result.feePercent = sep24WithdrawAsset.feePercent;
    result.feeMinimum = sep24WithdrawAsset.feeMinimum;
    return result;
  }
}

class AnchorServiceFeatures {
  bool accountCreation;
  bool claimableBalances;

  AnchorServiceFeatures(this.accountCreation, this.claimableBalances);

  static AnchorServiceFeatures from(flutter_sdk.FeatureFlags flags) {
    return AnchorServiceFeatures(
        flags.accountCreation, flags.claimableBalances);
  }
}

class AnchorServiceFee {
  bool enabled;
  bool authenticationRequired;
  AnchorServiceFee(this.enabled, this.authenticationRequired);

  static AnchorServiceFee from(flutter_sdk.FeeEndpointInfo feeInfo) {
    return AnchorServiceFee(feeInfo.enabled, feeInfo.authenticationRequired);
  }
}

class AnchorServiceInfo {
  Map<String, AnchorServiceAsset> deposit;
  Map<String, AnchorServiceAsset> withdraw;
  AnchorServiceFee fee;
  AnchorServiceFeatures? features;

  AnchorServiceInfo(this.deposit, this.withdraw, this.fee, {this.features});

  static AnchorServiceInfo from(flutter_sdk.SEP24InfoResponse infoResponse) {
    Map<String, AnchorServiceAsset> deposit = <String, AnchorServiceAsset>{};
    Map<String, AnchorServiceAsset> withdraw = <String, AnchorServiceAsset>{};
    if (infoResponse.depositAssets != null) {
      infoResponse.depositAssets!.forEach((key, value) {
        deposit[key] = AnchorServiceAsset.fromSep24DepositAsset(value);
      });
    }
    if (infoResponse.withdrawAssets != null) {
      infoResponse.withdrawAssets!.forEach((key, value) {
        withdraw[key] = AnchorServiceAsset.fromSep24WithdrawAsset(value);
      });
    }

    AnchorServiceFee fee = AnchorServiceFee(false, false);
    if (infoResponse.feeEndpointInfo != null) {
      fee = AnchorServiceFee.from(infoResponse.feeEndpointInfo!);
    }

    AnchorServiceFeatures? features;
    if (infoResponse.featureFlags != null) {
      features = AnchorServiceFeatures.from(infoResponse.featureFlags!);
    }
    return AnchorServiceInfo(deposit, withdraw, fee, features: features);
  }

  AnchorServiceAsset? getWithdrawServiceAssetFor(StellarAssetId assetId) {
    String assetKey = assetId is IssuedAssetId ? assetId.code : assetId.id;
    if (withdraw.containsKey(assetKey)) {
      return withdraw[assetKey];
    }
    return null;
  }

  AnchorServiceAsset? getDepositServiceAssetFor(StellarAssetId assetId) {
    String assetKey = assetId is IssuedAssetId ? assetId.code : assetId.id;
    if (withdraw.containsKey(assetKey)) {
      return withdraw[assetKey];
    }
    return null;
  }
}

class Payment {
  String amount;
  String fee;
  String id;
  String idType;

  Payment(this.amount, this.fee, this.id, this.idType);

  static Payment from(flutter_sdk.RefundPayment refundPayment) {
    return Payment(refundPayment.amount, refundPayment.fee, refundPayment.id,
        refundPayment.idType);
  }
}

class Refunds {
  String amountFee;
  String amountRefunded;
  List<Payment> payments;

  Refunds(this.amountFee, this.amountRefunded, this.payments);

  static Refunds from(flutter_sdk.Refund refund) {
    List<Payment> payments = List<Payment>.empty(growable: true);
    for (flutter_sdk.RefundPayment refundPayment in refund.payments) {
      payments.add(Payment.from(refundPayment));
    }
    return Refunds(refund.amountFee, refund.amountRefunded, payments);
  }
}

abstract class AnchorTransaction {
  String id;
  TransactionStatus status;
  String moreInfoUrl;
  DateTime startedAt;
  String? message;

  AnchorTransaction(this.id, this.status, this.moreInfoUrl, this.startedAt,
      {this.message});

  static AnchorTransaction fromTx(flutter_sdk.SEP24Transaction tx) {
    TransactionStatus status = TransactionStatus(tx.status);
    String kind = tx.kind;

    if (kind == "withdrawal") {
      if (status == TransactionStatus.incomplete) {
        return IncompleteWithdrawalTransaction.fromTx(tx);
      } else if (status == TransactionStatus.error) {
        return ErrorTransaction.fromTx(tx, TransactionKind.withdrawal);
      } else {
        return WithdrawalTransaction.fromTx(tx);
      }
    } else if (kind == "deposit") {
      if (status == TransactionStatus.incomplete) {
        return IncompleteDepositTransaction.fromTx(tx);
      } else if (status == TransactionStatus.error) {
        return ErrorTransaction.fromTx(tx, TransactionKind.deposit);
      } else {
        return DepositTransaction.fromTx(tx);
      }
    } else {
      throw InvalidDataException("invalid anchor transaction kind $kind");
    }
  }
}

abstract class ProcessingAnchorTransaction extends AnchorTransaction {
  int? statusEta;
  bool? kycVerified;
  String? amountInAsset;
  String? amountIn;
  String? amountOutAsset;
  String? amountOut;
  String? amountFeeAsset;
  String? amountFee;
  DateTime? completedAt;
  DateTime? updatedAt;
  String? stellarTransactionId;
  String? externalTransactionId;
  Refunds? refunds;

  ProcessingAnchorTransaction(super.id, super.status, super.moreInfoUrl,
      super.startedAt, this.amountIn, this.amountOut, this.amountFee,
      {super.message});

  void fillOptionalFieldsFrom(flutter_sdk.SEP24Transaction tx) {
    statusEta = tx.statusEta;
    kycVerified = tx.kycVerified;
    amountInAsset = tx.amountInAsset;
    amountOutAsset = tx.amountOutAsset;
    amountFeeAsset = tx.amountFeeAsset;
    if (tx.completedAt != null) {
      completedAt = DateTime.parse(tx.completedAt!);
    }
    if (tx.updatedAt != null) {
      updatedAt = DateTime.parse(tx.updatedAt!);
    }
    stellarTransactionId = tx.stellarTransactionId;
    externalTransactionId = tx.externalTransactionId;
    if (tx.refunds != null) {
      refunds = Refunds.from(tx.refunds!);
    }
  }
}

abstract class IncompleteAnchorTransaction extends AnchorTransaction {
  IncompleteAnchorTransaction(
      super.id, super.status, super.moreInfoUrl, super.startedAt,
      {super.message});
}

class DepositTransaction extends ProcessingAnchorTransaction {
  String? from;
  String? to;
  String? depositMemo;
  String? depositMemoType;
  String? claimableBalanceId;

  DepositTransaction(super.id, super.status, super.moreInfoUrl, super.startedAt,
      super.amountIn, super.amountOut, super.amountFee,
      {super.message});

  static DepositTransaction fromTx(flutter_sdk.SEP24Transaction tx) {
    DepositTransaction result = DepositTransaction(
        tx.id,
        TransactionStatus(tx.status),
        tx.moreInfoUrl,
        DateTime.parse(tx.startedAt),
        tx.amountIn,
        tx.amountOut,
        tx.amountFee,
        message: tx.message);
    result.fillOptionalFieldsFrom(tx);
    return result;
  }

  @override
  void fillOptionalFieldsFrom(flutter_sdk.SEP24Transaction tx) {
    from = tx.from;
    to = tx.to;
    depositMemo = tx.depositMemo;
    depositMemoType = tx.depositMemoType;
    claimableBalanceId = tx.claimableBalanceId;
    super.fillOptionalFieldsFrom(tx);
  }
}

class WithdrawalTransaction extends ProcessingAnchorTransaction {
  String? from;
  String? to;
  String? withdrawalMemo;
  String? withdrawalMemoType;
  String? withdrawAnchorAccount;

  WithdrawalTransaction(super.id, super.status, super.moreInfoUrl,
      super.startedAt, super.amountIn, super.amountOut, super.amountFee,
      {super.message});

  static WithdrawalTransaction fromTx(flutter_sdk.SEP24Transaction tx) {
    WithdrawalTransaction result = WithdrawalTransaction(
        tx.id,
        TransactionStatus(tx.status),
        tx.moreInfoUrl,
        DateTime.parse(tx.startedAt),
        tx.amountIn,
        tx.amountOut,
        tx.amountFee,
        message: tx.message);
    result.fillOptionalFieldsFrom(tx);
    return result;
  }

  @override
  void fillOptionalFieldsFrom(flutter_sdk.SEP24Transaction tx) {
    from = tx.from;
    to = tx.to;
    withdrawalMemo = tx.withdrawMemo;
    withdrawalMemoType = tx.withdrawMemoType;
    withdrawAnchorAccount = tx.withdrawAnchorAccount;
    super.fillOptionalFieldsFrom(tx);
  }
}

class IncompleteWithdrawalTransaction extends IncompleteAnchorTransaction {
  String? from;
  IncompleteWithdrawalTransaction(
      super.id, super.status, super.moreInfoUrl, super.startedAt,
      {super.message});

  static IncompleteWithdrawalTransaction fromTx(
      flutter_sdk.SEP24Transaction tx) {
    IncompleteWithdrawalTransaction result = IncompleteWithdrawalTransaction(
        tx.id,
        TransactionStatus(tx.status),
        tx.moreInfoUrl,
        DateTime.parse(tx.startedAt),
        message: tx.message);
    result.message = tx.message;
    result.from = tx.from;
    return result;
  }
}

class IncompleteDepositTransaction extends IncompleteAnchorTransaction {
  String? to;
  IncompleteDepositTransaction(
      super.id, super.status, super.moreInfoUrl, super.startedAt,
      {super.message});

  static IncompleteDepositTransaction fromTx(flutter_sdk.SEP24Transaction tx) {
    IncompleteDepositTransaction result = IncompleteDepositTransaction(
        tx.id,
        TransactionStatus(tx.status),
        tx.moreInfoUrl,
        DateTime.parse(tx.startedAt),
        message: tx.message);
    result.message = tx.message;
    result.to = tx.to;
    return result;
  }
}

class ErrorTransaction extends AnchorTransaction {
  TransactionKind kind;

  // Fields from withdrawal/deposit transactions that may present in error transaction

  int? statusEta;
  bool? kycVerified;
  String? amountInAsset;
  String? amountIn;
  String? amountOutAsset;
  String? amountOut;
  String? amountFeeAsset;
  String? amountFee;
  String? quoteId;
  DateTime? completedAt;
  String? stellarTransactionId;
  String? externalTransactionId;
  bool? refunded;
  Refunds? refunds;
  String? from;
  String? to;
  String? depositMemo;
  String? depositMemoType;
  String? claimableBalanceId;
  String? withdrawalMemo;
  String? withdrawalMemoType;
  String? withdrawAnchorAccount;

  ErrorTransaction(
      this.kind, super.id, super.status, super.moreInfoUrl, super.startedAt,
      {super.message});

  static ErrorTransaction fromTx(
      flutter_sdk.SEP24Transaction tx, TransactionKind kind) {
    ErrorTransaction result = ErrorTransaction(
        kind,
        tx.id,
        TransactionStatus(tx.status),
        tx.moreInfoUrl,
        DateTime.parse(tx.startedAt),
        message: tx.message);
    result.statusEta = tx.statusEta;
    result.kycVerified = tx.kycVerified;
    result.amountInAsset = tx.amountInAsset;
    result.amountIn = tx.amountIn;
    result.amountOutAsset = tx.amountOutAsset;
    result.amountOut = tx.amountOut;
    result.amountFeeAsset = tx.amountFeeAsset;
    result.amountFee = tx.amountFee;
    result.quoteId = tx.quoteId;
    if (tx.completedAt != null) {
      result.completedAt = DateTime.parse(tx.completedAt!);
    }
    result.stellarTransactionId = tx.stellarTransactionId;
    result.externalTransactionId = tx.externalTransactionId;
    result.refunded = tx.refunded;
    if (tx.refunds != null) {
      result.refunds = Refunds.from(tx.refunds!);
    }
    result.from = tx.from;
    result.to = tx.to;
    result.depositMemo = tx.depositMemo;
    result.depositMemoType = tx.depositMemoType;
    result.claimableBalanceId = tx.claimableBalanceId;
    result.withdrawalMemo = tx.withdrawMemo;
    result.withdrawalMemoType = tx.withdrawMemoType;
    return result;
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

enum TransactionKind { deposit, withdrawal }

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
