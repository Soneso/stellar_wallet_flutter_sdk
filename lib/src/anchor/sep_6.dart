// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/anchor/watcher.dart';
import 'package:stellar_wallet_flutter_sdk/src/auth/sep_10.dart';
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/toml/stellar_toml.dart';
import 'package:stellar_wallet_flutter_sdk/src/asset/asset_id.dart';

import 'anchor.dart';
import 'package:http/http.dart' as http;

class Sep6 {
  Anchor anchor;
  http.Client? httpClient;
  Map<String, String>? httpRequestHeaders;

  Sep6(this.anchor, {this.httpClient, this.httpRequestHeaders});

  /// Get basic info from the anchor about what their TRANSFER_SERVER supports.
  /// [language] (optional) Defaults to en if not specified or if the specified
  /// language is not supported. Language code specified using RFC 4646.
  /// Error fields and other human readable messages in the response should
  /// be in this language.
  /// optional [authToken] token previously received from the anchor via the SEP-10
  /// authentication flow.
  /// Throws [AnchorDepositAndWithdrawalAPINotSupported] if the anchor does not support SEP-06.
  Future<Sep6Info> info({String? language, AuthToken? authToken}) async {
    var service = await _transferService();
    var response = await service.info(language: language, jwt: authToken?.jwt);
    return Sep6Info.fromSep6InfoResponse(response);
  }

  /// A deposit is when a user sends an external token (BTC via Bitcoin,
  /// USD via bank transfer, etc...) to an address held by an anchor. In turn,
  /// the anchor sends an equal amount of tokens on the Stellar network
  /// (minus fees) to the user's Stellar account.
  ///
  /// If the anchor supports SEP-38 quotes, it can also provide a bridge
  /// between non-equivalent tokens. For example, the anchor can receive ARS
  /// via bank transfer and in return send the equivalent value (minus fees)
  /// as USDC on the Stellar network to the user's Stellar account.
  /// That kind of deposit is covered in GET /deposit-exchange.
  ///
  /// The deposit endpoint allows a wallet to get deposit information from
  /// an anchor, so a user has all the information needed to initiate a deposit.
  /// It also lets the anchor specify additional information (if desired) that
  /// the user must submit via SEP-12 to be able to deposit.
  Future<Sep6TransferResponse> deposit(
      Sep6DepositParams params, AuthToken authToken) async {
    var service = await _transferService();

    try {
      var request = params.toDepositRequest();
      request.jwt = authToken.jwt;
      var response = await service.deposit(request);
      return Sep6DepositSuccess.fromDepositResponse(response);
    } on flutter_sdk.CustomerInformationNeededException catch (e) {
      return Sep6MissingKYC.fromCustomerInformationNeededResponse(e.response);
    } on flutter_sdk.CustomerInformationStatusException catch (e) {
      return Sep6Pending.fromCustomerInformationStatusResponse(e.response);
    }
  }

  /// If the anchor supports SEP-38 quotes, it can provide a deposit that makes
  /// a bridge between non-equivalent tokens by receiving, for instance BRL
  /// via bank transfer and in return sending the equivalent value (minus fees)
  /// as USDC to the user's Stellar account.
  ///
  /// The /deposit-exchange endpoint allows a wallet to get deposit information
  /// from an anchor when the user intends to make a conversion between
  /// non-equivalent tokens. With this endpoint, a user has all the information
  /// needed to initiate a deposit and it also lets the anchor specify
  /// additional information (if desired) that the user must submit via SEP-12.
  Future<Sep6TransferResponse> depositExchange(
      Sep6DepositExchangeParams params, AuthToken authToken) async {
    var service = await _transferService();

    try {
      var request = params.toDepositExchangeRequest();
      request.jwt = authToken.jwt;
      var response = await service.depositExchange(request);
      return Sep6DepositSuccess.fromDepositResponse(response);
    } on flutter_sdk.CustomerInformationNeededException catch (e) {
      return Sep6MissingKYC.fromCustomerInformationNeededResponse(e.response);
    } on flutter_sdk.CustomerInformationStatusException catch (e) {
      return Sep6Pending.fromCustomerInformationStatusResponse(e.response);
    }
  }

  /// A withdraw is when a user redeems an asset currently on the
  /// Stellar network for its equivalent off-chain asset via the Anchor.
  /// For instance, a user redeeming their NGNT in exchange for fiat NGN.
  ///
  /// If the anchor supports SEP-38 quotes, it can also provide a bridge
  /// between non-equivalent tokens. For example, the anchor can receive USDC
  /// from the Stellar network and in return send the equivalent value
  /// (minus fees) as NGN to the user's bank account.
  /// That kind of withdrawal is covered in GET /withdraw-exchange.
  ///
  /// The /withdraw endpoint allows a wallet to get withdrawal information
  /// from an anchor, so a user has all the information needed to initiate
  /// a withdrawal. It also lets the anchor specify additional information
  /// (if desired) that the user must submit via SEP-12 to be able to withdraw.
  Future<Sep6TransferResponse> withdraw(
      Sep6WithdrawParams params, AuthToken authToken) async {
    var service = await _transferService();

    try {
      var request = params.toWithdrawRequest();
      request.jwt = authToken.jwt;
      var response = await service.withdraw(request);
      return Sep6WithdrawSuccess.fromWithdrawResponse(response);
    } on flutter_sdk.CustomerInformationNeededException catch (e) {
      return Sep6MissingKYC.fromCustomerInformationNeededResponse(e.response);
    } on flutter_sdk.CustomerInformationStatusException catch (e) {
      return Sep6Pending.fromCustomerInformationStatusResponse(e.response);
    }
  }

  /// If the anchor supports SEP-38 quotes, it can provide a withdraw that makes
  /// a bridge between non-equivalent tokens by receiving, for instance USDC
  /// from the Stellar network and in return sending the equivalent value
  /// (minus fees) as NGN to the user's bank account.
  ///
  /// The /withdraw-exchange endpoint allows a wallet to get withdraw
  /// information from an anchor when the user intends to make a conversion
  /// between non-equivalent tokens. With this endpoint, a user has all the
  /// information needed to initiate a withdraw and it also lets the anchor
  /// specify additional information (if desired) that the user must submit
  /// via SEP-12.
  Future<Sep6TransferResponse> withdrawExchange(
      Sep6WithdrawExchangeParams params, AuthToken authToken) async {
    var service = await _transferService();

    try {
      var request = params.toWithdrawExchangeRequest();
      request.jwt = authToken.jwt;
      var response = await service.withdrawExchange(request);
      return Sep6WithdrawSuccess.fromWithdrawResponse(response);
    } on flutter_sdk.CustomerInformationNeededException catch (e) {
      return Sep6MissingKYC.fromCustomerInformationNeededResponse(e.response);
    } on flutter_sdk.CustomerInformationStatusException catch (e) {
      return Sep6Pending.fromCustomerInformationStatusResponse(e.response);
    }
  }

  /// The transaction history endpoint helps anchors enable a better
  /// experience for users using an external wallet.
  /// With it, wallets can display the status of deposits and withdrawals
  /// while they process and a history of past transactions with the anchor.
  /// It's only for transactions that are deposits to or withdrawals from
  /// the anchor.
  Future<List<Sep6Transaction>> getTransactionsForAsset(
      {required AuthToken authToken,
      required String assetCode,
      DateTime? noOlderThan,
      int? limit,
      TransactionKind? kind,
      String? pagingId,
      String? lang}) async {
    var service = await _transferService();

    var request = flutter_sdk.AnchorTransactionsRequest(
        assetCode: assetCode,
        account: authToken.account,
        noOlderThan: noOlderThan,
        limit: limit,
        pagingId: pagingId,
        lang: lang,
        jwt: authToken.jwt);

    if (kind != null) {
      switch (kind) {
        case TransactionKind.deposit:
          request.kind = "deposit";
        case TransactionKind.withdrawal:
          request.kind = "withdrawal";
        case TransactionKind.depositExchange:
          request.kind = "deposit-exchange";
        case TransactionKind.withdrawalExchange:
          request.kind = "withdrawal-exchange";
      }
    }

    request.jwt = authToken.jwt;
    var response = await service.transactions(request);

    List<Sep6Transaction> transactions =
        List<Sep6Transaction>.empty(growable: true);
    for (flutter_sdk.AnchorTransaction anchorTx in response.transactions) {
      transactions.add(Sep6Transaction.fromAnchorTransaction(anchorTx));
    }
    return transactions;
  }

  /// The transaction endpoint enables clients to query/validate a
  /// specific transaction at an anchor.
  Future<Sep6Transaction> getTransactionBy(
      {required AuthToken authToken,
      String? id,
      String? stellarTransactionId,
      String? externalTransactionId,
      String? lang}) async {
    var service = await _transferService();

    var request = flutter_sdk.AnchorTransactionRequest();
    request.id = id;
    request.stellarTransactionId = stellarTransactionId;
    request.externalTransactionId = externalTransactionId;
    request.lang = lang;
    request.jwt = authToken.jwt;
    var response = await service.transaction(request);
    return Sep6Transaction.fromAnchorTransaction(response.transaction);
  }

  /// Creates new transaction watcher.
  /// You can pass the [pollInterval] in which requests to the Anchor are being made.
  /// If not specified, it defaults to 5 seconds. You can also pass your own [exceptionHandler].
  /// By default, [RetryExceptionHandler] is being used.
  Watcher watcher(
      {Duration pollDelay = const Duration(seconds: 5),
      WalletExceptionHandler? exceptionHandler}) {
    return Watcher(anchor, pollDelay,
        exceptionHandler ?? RetryExceptionHandler(), WatcherKind.sep6);
  }

  Future<flutter_sdk.TransferServerService> _transferService() async {
    TomlInfo tomlInfo = await anchor.sep1();
    if (tomlInfo.services.sep6 == null) {
      throw AnchorDepositAndWithdrawalAPINotSupported();
    }

    return flutter_sdk.TransferServerService(
        tomlInfo.services.sep6!.transferServer,
        httpClient: httpClient,
        httpRequestHeaders: httpRequestHeaders);
  }
}

class Sep6Transaction extends AnchorTransaction {
  /// deposit, deposit-exchange, withdrawal or withdrawal-exchange.
  String kind;

  /// (optional) Estimated number of seconds until a status change is expected.
  int? statusEta;

  /// (optional) Amount received by anchor at start of transaction as a
  /// string with up to 7 decimals. Excludes any fees charged before the
  /// anchor received the funds. Should be equals to quote.sell_asset if
  /// a quote_id was used.
  String? amountIn;

  /// optional) The asset received or to be received by the Anchor.
  /// Must be present if the deposit/withdraw was made using quotes.
  /// The value must be in SEP-38 Asset Identification Format.
  String? amountInAsset;

  /// (optional) Amount sent by anchor to user at end of transaction as
  /// a string with up to 7 decimals. Excludes amount converted to XLM to
  /// fund account and any external fees. Should be equals to quote.buy_asset
  /// if a quote_id was used.
  String? amountOut;

  /// (optional) The asset delivered or to be delivered to the user.
  /// Must be present if the deposit/withdraw was made using quotes.
  /// The value must be in SEP-38 Asset Identification Format.
  String? amountOutAsset;

  /// (deprecated, optional) Amount of fee charged by anchor.
  /// Should be equals to quote.fee.total if a quote_id was used.
  String? amountFee;

  /// (deprecated, optional) The asset in which fees are calculated in.
  /// Must be present if the deposit/withdraw was made using quotes.
  /// The value must be in SEP-38 Asset Identification Format.
  /// Should be equals to quote.fee.asset if a quote_id was used.
  String? amountFeeAsset;

  /// Description of fee charged by the anchor.
  /// If quote_id is present, it should match the referenced quote's fee object.
  Sep6ChargedFee? chargedFeeInfo;

  /// (optional) The ID of the quote used to create this transaction.
  /// Should be present if a quote_id was included in the POST /transactions
  /// request. Clients should be aware though that the quote_id may not be
  /// present in older implementations.
  String? quoteId;

  /// (optional) Sent from address (perhaps BTC, IBAN, or bank account in
  /// the case of a deposit, Stellar address in the case of a withdrawal).
  String? from;

  /// (optional) Sent to address (perhaps BTC, IBAN, or bank account in
  /// the case of a withdrawal, Stellar address in the case of a deposit).
  String? to;

  /// (optional) Extra information for the external account involved.
  /// It could be a bank routing number, BIC, or store number for example.
  String? externalExtra;

  /// (optional) Text version of external_extra.
  /// This is the name of the bank or store
  String? externalExtraText;

  /// (optional) If this is a deposit, this is the memo (if any)
  /// used to transfer the asset to the to Stellar address
  String? depositMemo;

  /// (optional) Type for the depositMemo.
  String? depositMemoType;

  /// (optional) If this is a withdrawal, this is the anchor's Stellar account
  /// that the user transferred (or will transfer) their issued asset to.
  String? withdrawAnchorAccount;

  /// (optional) Memo used when the user transferred to withdrawAnchorAccount.
  String? withdrawMemo;

  /// (optional) Memo type for withdrawMemo.
  String? withdrawMemoType;

  DateTime? startedAt;

  /// (optional) The date and time of transaction reaching the current status.
  DateTime? updatedAt;

  /// (optional) Completion date and time of transaction - UTC ISO 8601 string.
  DateTime? completedAt;

  /// (optional) transaction_id on Stellar network of the transfer that either
  /// completed the deposit or started the withdrawal.
  String? stellarTransactionId;

  /// (optional) ID of transaction on external network that either started
  /// the deposit or completed the withdrawal.
  String? externalTransactionId;

  /// (deprecated, optional) This field is deprecated in favor of the refunds
  /// object. True if the transaction was refunded in full. False if the
  /// transaction was partially refunded or not refunded. For more details
  /// about any refunds, see the refunds object.
  bool? refunded;

  /// (optional) An object describing any on or off-chain refund associated
  /// with this transaction.
  Sep6Refunds? refunds;

  /// (optional) A human-readable message indicating any errors that require
  /// updated information from the user.
  String? requiredInfoMessage;

  /// (optional) A set of fields that require update from the user described in
  /// the same format as /info. This field is only relevant when status is
  /// pending_transaction_info_update.
  Map<String, Sep6FieldInfo>? requiredInfoUpdates;

  /// (optional) JSON object containing the SEP-9 financial account fields that
  /// describe how to complete the off-chain deposit in the same format as
  /// the /deposit response. This field should be present if the instructions
  /// were provided in the /deposit response or if it could not have been
  /// previously provided synchronously. This field should only be present
  /// once the status becomes pending_user_transfer_start, not while the
  /// transaction has any statuses that precede it such as incomplete,
  /// pending_anchor, or pending_customer_info_update.
  Map<String, Sep6DepositInstruction>? instructions;

  /// (optional) ID of the Claimable Balance used to send the asset initially
  /// requested. Only relevant for deposit transactions.
  String? claimableBalanceId;

  /// (optional) A URL the user can visit if they want more information
  /// about their account / status.
  String? moreInfoUrl;

  Sep6Transaction(super.id, super.status,
      {required this.kind,
      super.message,
      this.statusEta,
      this.moreInfoUrl,
      this.amountIn,
      this.amountInAsset,
      this.amountOut,
      this.amountOutAsset,
      this.amountFee,
      this.amountFeeAsset,
      this.chargedFeeInfo,
      this.quoteId,
      this.from,
      this.to,
      this.externalExtra,
      this.externalExtraText,
      this.depositMemo,
      this.depositMemoType,
      this.withdrawAnchorAccount,
      this.withdrawMemo,
      this.withdrawMemoType,
      this.startedAt,
      this.updatedAt,
      this.completedAt,
      this.stellarTransactionId,
      this.externalTransactionId,
      this.refunded,
      this.refunds,
      this.requiredInfoMessage,
      this.requiredInfoUpdates,
      this.instructions,
      this.claimableBalanceId});

  static Sep6Transaction fromAnchorTransaction(
      flutter_sdk.AnchorTransaction anchorTx) {
    Sep6ChargedFee? chargedFeeInfo;
    if (anchorTx.feeDetails != null) {
      chargedFeeInfo = Sep6ChargedFee.fromFeeDetails(anchorTx.feeDetails!);
    }

    Sep6Refunds? refunds;
    if (anchorTx.refunds != null) {
      refunds = Sep6Refunds.from(anchorTx.refunds!);
    }

    Map<String, Sep6FieldInfo>? requiredInfoUpdates;
    if (anchorTx.requiredInfoUpdates != null) {
      requiredInfoUpdates = {};
      anchorTx.requiredInfoUpdates!.forEach((key, value) {
        requiredInfoUpdates![key] = Sep6FieldInfo.fromSep6AnchorField(value);
      });
    }

    Map<String, Sep6DepositInstruction>? instructions;
    if (anchorTx.instructions != null) {
      instructions = {};
      anchorTx.instructions!.forEach((key, value) {
        instructions![key] =
            Sep6DepositInstruction.fromDepositInstruction(value);
      });
    }

    return Sep6Transaction(anchorTx.id, TransactionStatus(anchorTx.status),
        kind: anchorTx.kind,
        statusEta: anchorTx.statusEta,
        moreInfoUrl: anchorTx.moreInfoUrl,
        amountIn: anchorTx.amountIn,
        amountInAsset: anchorTx.amountInAsset,
        amountOut: anchorTx.amountOut,
        amountOutAsset: anchorTx.amountOutAsset,
        amountFee: anchorTx.amountFee,
        amountFeeAsset: anchorTx.amountFeeAsset,
        chargedFeeInfo: chargedFeeInfo,
        quoteId: anchorTx.quoteId,
        from: anchorTx.from,
        to: anchorTx.to,
        externalExtra: anchorTx.externalExtra,
        externalExtraText: anchorTx.externalExtraText,
        depositMemo: anchorTx.depositMemo,
        depositMemoType: anchorTx.depositMemoType,
        withdrawAnchorAccount: anchorTx.withdrawAnchorAccount,
        withdrawMemo: anchorTx.withdrawMemo,
        withdrawMemoType: anchorTx.withdrawMemoType,
        startedAt: anchorTx.startedAt != null
            ? DateTime.parse(anchorTx.startedAt!)
            : null,
        updatedAt: anchorTx.updatedAt != null
            ? DateTime.parse(anchorTx.updatedAt!)
            : null,
        completedAt: anchorTx.completedAt != null
            ? DateTime.parse(anchorTx.completedAt!)
            : null,
        stellarTransactionId: anchorTx.stellarTransactionId,
        externalTransactionId: anchorTx.externalTransactionId,
        message: anchorTx.message,
        refunded: anchorTx.refunded,
        refunds: refunds,
        requiredInfoMessage: anchorTx.requiredInfoMessage,
        requiredInfoUpdates: requiredInfoUpdates,
        instructions: instructions,
        claimableBalanceId: anchorTx.claimableBalanceId);
  }
}

class Sep6Refunds {
  String amountFee;
  String amountRefunded;
  List<Sep6Payment> payments;

  Sep6Refunds(this.amountFee, this.amountRefunded, this.payments);

  static Sep6Refunds from(flutter_sdk.TransactionRefunds refund) {
    List<Sep6Payment> payments = List<Sep6Payment>.empty(growable: true);
    for (flutter_sdk.TransactionRefundPayment refundPayment
        in refund.payments) {
      payments.add(Sep6Payment.from(refundPayment));
    }
    return Sep6Refunds(refund.amountFee, refund.amountRefunded, payments);
  }
}

class Sep6Payment {
  String amount;
  String fee;
  String id;
  String idType;

  Sep6Payment(this.amount, this.fee, this.id, this.idType);

  static Sep6Payment from(flutter_sdk.TransactionRefundPayment refundPayment) {
    return Sep6Payment(refundPayment.amount, refundPayment.fee,
        refundPayment.id, refundPayment.idType);
  }
}

class Sep6ChargedFee {
  /// The total amount of fee applied.
  String total;

  /// The asset in which the fee is applied, represented through the
  /// Asset Identification Format.
  String asset;

  /// (optional) An array of objects detailing the fees that were used to
  /// calculate the conversion price. This can be used to datail the price
  /// components for the end-user.
  List<Sep6ChargedFeeDetail>? details;

  Sep6ChargedFee(this.total, this.asset, {this.details});

  static Sep6ChargedFee fromFeeDetails(flutter_sdk.FeeDetails feeDetails) {
    List<Sep6ChargedFeeDetail>? details;
    if (feeDetails.details != null) {
      details = List<Sep6ChargedFeeDetail>.empty(growable: true);
      for (var detail in feeDetails.details!) {
        details.add(Sep6ChargedFeeDetail.fromFeeDetailsDetails(detail));
      }
    }
    return Sep6ChargedFee(feeDetails.total, feeDetails.asset, details: details);
  }
}

class Sep6ChargedFeeDetail {
  /// The name of the fee, for example ACH fee, Brazilian conciliation fee,
  /// Service fee, etc.
  String name;

  /// The amount of asset applied. If fee_details.details is provided,
  /// sum(fee_details.details.amount) should be equals fee_details.total.
  String amount;

  /// (optional) A text describing the fee.
  String? description;

  Sep6ChargedFeeDetail(this.name, this.amount, {this.description});

  static Sep6ChargedFeeDetail fromFeeDetailsDetails(
      flutter_sdk.FeeDetailsDetails feeDetailsDetails) {
    return Sep6ChargedFeeDetail(
        feeDetailsDetails.name, feeDetailsDetails.amount,
        description: feeDetailsDetails.description);
  }
}

abstract class Sep6TransferResponse {}

class Sep6MissingKYC extends Sep6TransferResponse {
  /// A list of field names that need to be transmitted via
  /// SEP-12 for the deposit or withdrawal to proceed.
  List<String> fields;

  Sep6MissingKYC(this.fields);

  static Sep6MissingKYC fromCustomerInformationNeededResponse(
      flutter_sdk.CustomerInformationNeededResponse response) {
    return Sep6MissingKYC(response.fields ?? []);
  }
}

class Sep6Pending extends Sep6TransferResponse {
  /// Status of customer information processing. One of: pending, denied.
  String status;

  /// (optional) A URL the user can visit if they want more information
  /// about their account / status.
  String? moreInfoUrl;

  /// (optional) Estimated number of seconds until the customer information
  /// status will update.
  int? eta;

  Sep6Pending(this.status, this.moreInfoUrl, this.eta);

  static fromCustomerInformationStatusResponse(
      flutter_sdk.CustomerInformationStatusResponse response) {
    return Sep6Pending(
        response.status ?? 'pending', response.moreInfoUrl, response.eta);
  }
}

class Sep6WithdrawSuccess extends Sep6TransferResponse {
  /// (optional) The account the user should send its token back to.
  /// This field can be omitted if the anchor cannot provide this information
  /// at the time of the request.
  String? accountId;

  /// (optional) Type of memo to attach to transaction, one of text, id or hash.
  String? memoType;

  /// (optional) Value of memo to attach to transaction, for hash this should
  /// be base64-encoded. The anchor should use this memo to match the Stellar
  /// transaction with the database entry associated created to represent it.
  String? memo;

  /// (optional) The anchor's ID for this withdrawal. The wallet will use this
  /// ID to query the /transaction endpoint to check status of the request.
  String? id;

  /// (optional) Estimate of how long the withdrawal will take to credit
  /// in seconds.
  int? eta;

  /// (optional) Minimum amount of an asset that a user can withdraw.
  double? minAmount;

  /// (optional) Maximum amount of asset that a user can withdraw.
  double? maxAmount;

  /// (optional) If there is a fee for withdraw. In units of the withdrawn
  /// asset.
  double? feeFixed;

  /// (optional) If there is a percent fee for withdraw.
  double? feePercent;

  /// (optional) Any additional data needed as an input for this withdraw,
  /// example: Bank Name.
  Sep6ExtraInfo? extraInfo;

  Sep6WithdrawSuccess(
      {this.accountId,
      this.memoType,
      this.memo,
      this.id,
      this.eta,
      this.minAmount,
      this.maxAmount,
      this.feeFixed,
      this.feePercent,
      this.extraInfo});

  static Sep6WithdrawSuccess fromWithdrawResponse(
      flutter_sdk.WithdrawResponse response) {
    Sep6ExtraInfo? extraInfo;
    if (response.extraInfo != null) {
      extraInfo == Sep6ExtraInfo.fromExtraInfo(response.extraInfo!);
    }
    return Sep6WithdrawSuccess(
        accountId: response.accountId,
        memoType: response.memoType,
        memo: response.memo,
        id: response.id,
        eta: response.eta,
        minAmount: response.minAmount,
        maxAmount: response.maxAmount,
        feeFixed: response.feeFixed,
        feePercent: response.feePercent,
        extraInfo: extraInfo);
  }
}

class Sep6DepositSuccess extends Sep6TransferResponse {
  /// (deprecated, use instructions instead) Terse but complete instructions
  /// for how to deposit the asset. In the case of most cryptocurrencies it is
  /// just an address to which the deposit should be sent.
  String? how;

  /// (optional) The anchor's ID for this deposit. The wallet will use this ID
  /// to query the /transaction endpoint to check status of the request.
  String? id;

  /// (optional) Estimate of how long the deposit will take to credit in seconds.
  int? eta;

  /// (optional) Minimum amount of an asset that a user can deposit.
  double? minAmount;

  /// (optional) Maximum amount of asset that a user can deposit.
  double? maxAmount;

  /// (optional) Fixed fee (if any). In units of the deposited asset.
  double? feeFixed;

  /// (optional) Percentage fee (if any). In units of percentage points.
  double? feePercent;

  /// (optional) Additional information about the deposit process.
  Sep6ExtraInfo? extraInfo;

  /// (optional) A Map containing details that describe how to complete
  /// the off-chain deposit. The map has SEP-9 financial account fields as keys
  /// and its values are DepositInstruction objects.
  Map<String, Sep6DepositInstruction>? instructions;

  Sep6DepositSuccess(
      {this.how,
      this.id,
      this.eta,
      this.minAmount,
      this.maxAmount,
      this.feeFixed,
      this.feePercent,
      this.extraInfo,
      this.instructions});

  static Sep6DepositSuccess fromDepositResponse(
      flutter_sdk.DepositResponse response) {
    Map<String, Sep6DepositInstruction>? instructions;
    if (response.instructions != null) {
      instructions = {};
      response.instructions!.forEach((key, value) {
        instructions![key] =
            Sep6DepositInstruction.fromDepositInstruction(value);
      });
    }
    Sep6ExtraInfo? extraInfo;
    if (response.extraInfo != null) {
      extraInfo = Sep6ExtraInfo.fromExtraInfo(response.extraInfo!);
    }
    return Sep6DepositSuccess(
        how: response.how,
        id: response.id,
        eta: response.eta,
        minAmount: response.minAmount,
        feeFixed: response.feeFixed,
        feePercent: response.feePercent,
        extraInfo: extraInfo,
        instructions: instructions);
  }
}

class Sep6DepositInstruction {
  /// The value of the field.
  String value;

  /// A human-readable description of the field. This can be used by an anchor
  /// to provide any additional information about fields that are not defined
  /// in the SEP-9 standard.
  String description;

  Sep6DepositInstruction(this.value, this.description);

  static Sep6DepositInstruction fromDepositInstruction(
      flutter_sdk.DepositInstruction instruction) {
    return Sep6DepositInstruction(instruction.value, instruction.description);
  }
}

class Sep6ExtraInfo {
  /// Message with additional details about the (deposit or withdrawal) process
  String? message;

  Sep6ExtraInfo(this.message);

  static Sep6ExtraInfo fromExtraInfo(flutter_sdk.ExtraInfo extraInfo) {
    return Sep6ExtraInfo(extraInfo.message);
  }
}

class Sep6Info {
  /// supported deposit assets and their info
  Map<String, Sep6DepositInfo>? deposit;

  /// supported deposit exchange assets and their info
  Map<String, Sep6DepositExchangeInfo>? depositExchange;

  /// supported withdrawal assets and their info
  Map<String, Sep6WithdrawInfo>? withdraw;

  /// supported withdrawal exchange assets and their info
  Map<String, Sep6WithdrawExchangeInfo>? withdrawExchange;

  /// fee endpoint info
  Sep6EndpointInfo? fee;

  /// transactions endpoint info
  Sep6EndpointInfo? transactions;

  /// single transaction endpoint info
  Sep6EndpointInfo? transaction;

  /// anchor features info
  Sep6FeaturesInfo? features;

  Sep6Info(
      this.deposit,
      this.depositExchange,
      this.withdraw,
      this.withdrawExchange,
      this.fee,
      this.transactions,
      this.transaction,
      this.features);

  static Sep6Info fromSep6InfoResponse(flutter_sdk.InfoResponse response) {
    Map<String, Sep6DepositInfo>? deposit;
    if (response.depositAssets != null) {
      deposit = {};
      response.depositAssets!.forEach((key, value) {
        deposit![key] = Sep6DepositInfo.fromSep6DepositAsset(value);
      });
    }

    Map<String, Sep6DepositExchangeInfo>? depositExchange;
    if (response.depositExchangeAssets != null) {
      depositExchange = {};
      response.depositExchangeAssets!.forEach((key, value) {
        depositExchange![key] =
            Sep6DepositExchangeInfo.fromSep6DepositExchangeAsset(value);
      });
    }

    Map<String, Sep6WithdrawInfo>? withdraw;
    if (response.withdrawAssets != null) {
      withdraw = {};
      response.withdrawAssets!.forEach((key, value) {
        withdraw![key] = Sep6WithdrawInfo.fromSep6WithdrawAsset(value);
      });
    }

    Map<String, Sep6WithdrawExchangeInfo>? withdrawExchange;
    if (response.withdrawExchangeAssets != null) {
      withdrawExchange = {};
      response.withdrawExchangeAssets!.forEach((key, value) {
        withdrawExchange![key] =
            Sep6WithdrawExchangeInfo.fromSep6WithdrawExchangeAsset(value);
      });
    }

    Sep6EndpointInfo? fee = response.feeInfo != null
        ? Sep6EndpointInfo.fromSep6AnchorFeeInfo(response.feeInfo!)
        : null;
    Sep6EndpointInfo? transaction = response.transactionInfo != null
        ? Sep6EndpointInfo.fromSep6AnchorTransactionInfo(
            response.transactionInfo!)
        : null;
    Sep6EndpointInfo? transactions = response.transactionsInfo != null
        ? Sep6EndpointInfo.fromSep6AnchorTransactionsInfo(
            response.transactionsInfo!)
        : null;
    Sep6FeaturesInfo? features = response.featureFlags != null
        ? Sep6FeaturesInfo.fromSep6AnchorFeatureFlags(response.featureFlags!)
        : null;

    return Sep6Info(deposit, depositExchange, withdraw, withdrawExchange, fee,
        transactions, transaction, features);
  }
}

class Sep6FieldInfo {
  /// description of field to show to user.
  String? description;

  /// if field is optional. Defaults to false.
  bool? optional;

  /// list of possible values for the field.
  List<String>? choices;

  Sep6FieldInfo(this.description, this.optional, this.choices);

  static Sep6FieldInfo fromSep6AnchorField(
      flutter_sdk.AnchorField anchorField) {
    return Sep6FieldInfo(
        anchorField.description, anchorField.optional, anchorField.choices);
  }
}

class Sep6DepositInfo {
  /// true if SEP-6 deposit for this asset is supported.
  bool enabled;

  /// Optional. true if client must be authenticated before accessing the
  /// deposit endpoint for this asset. false if not specified.
  bool? authenticationRequired;

  /// Optional fixed (flat) fee for deposit, in units of the Stellar asset.
  /// Null if there is no fee or the fee schedule is complex.
  double? feeFixed;

  /// Optional percentage fee for deposit, in percentage points of the Stellar
  /// asset. Null if there is no fee or the fee schedule is complex.
  double? feePercent;

  /// Optional minimum amount. No limit if not specified.
  double? minAmount;

  /// Optional maximum amount. No limit if not specified.
  double? maxAmount;

  /// (Deprecated) Accepting personally identifiable information through
  /// request parameters is a security risk due to web server request logging.
  /// KYC information should be supplied to the Anchor via SEP-12).
  Map<String, Sep6FieldInfo>? fieldsInfo;

  Sep6DepositInfo(this.enabled, this.authenticationRequired, this.feeFixed,
      this.feePercent, this.minAmount, this.maxAmount, this.fieldsInfo);

  static Sep6DepositInfo fromSep6DepositAsset(flutter_sdk.DepositAsset asset) {
    Map<String, Sep6FieldInfo>? fieldsInfo;
    if (asset.fields != null) {
      fieldsInfo = {};
      asset.fields!.forEach((key, value) {
        fieldsInfo![key] = Sep6FieldInfo.fromSep6AnchorField(value);
      });
    }

    return Sep6DepositInfo(
        asset.enabled,
        asset.authenticationRequired,
        asset.feeFixed,
        asset.feePercent,
        asset.minAmount,
        asset.maxAmount,
        fieldsInfo);
  }
}

class Sep6DepositExchangeInfo {
  /// true if SEP-6 deposit for this asset is supported
  bool enabled;

  /// Optional. true if client must be authenticated before accessing the
  /// deposit endpoint for this asset. false if not specified.
  bool? authenticationRequired;

  /// (Deprecated) Accepting personally identifiable information through
  /// request parameters is a security risk due to web server request logging.
  /// KYC information should be supplied to the Anchor via SEP-12).
  Map<String, Sep6FieldInfo>? fieldsInfo;

  Sep6DepositExchangeInfo(
      this.enabled, this.authenticationRequired, this.fieldsInfo);

  static Sep6DepositExchangeInfo fromSep6DepositExchangeAsset(
      flutter_sdk.DepositExchangeAsset asset) {
    Map<String, Sep6FieldInfo>? fieldsInfo;
    if (asset.fields != null) {
      fieldsInfo = {};
      asset.fields!.forEach((key, value) {
        fieldsInfo![key] = Sep6FieldInfo.fromSep6AnchorField(value);
      });
    }

    return Sep6DepositExchangeInfo(
        asset.enabled, asset.authenticationRequired, fieldsInfo);
  }
}

class Sep6WithdrawInfo {
  /// true if SEP-6 withdrawal for this asset is supported
  bool enabled;

  /// Optional. true if client must be authenticated before accessing
  /// the withdraw endpoint for this asset. false if not specified.
  bool? authenticationRequired;

  /// Optional fixed (flat) fee for withdraw, in units of the Stellar asset.
  /// Null if there is no fee or the fee schedule is complex.
  double? feeFixed;

  /// Optional percentage fee for withdraw, in percentage points of the
  /// Stellar asset. Null if there is no fee or the fee schedule is complex.
  double? feePercent;

  /// Optional minimum amount. No limit if not specified.
  double? minAmount;

  /// Optional maximum amount. No limit if not specified.
  double? maxAmount;

  /// A map with each type of withdrawal supported for that asset as a key.
  /// Each type can specify a field info object explaining what fields
  /// are needed and what they do. Anchors are encouraged to use SEP-9
  /// financial account fields, but can also define custom fields if necessary.
  /// If a fields object is not specified, the wallet should assume that no
  /// extra field info are needed for that type of withdrawal. In the case that
  /// the Anchor requires additional fields for a withdrawal, it should set the
  /// transaction status to pending_customer_info_update. The wallet can query
  /// the /transaction endpoint to get the field info needed to complete the
  /// transaction in required_customer_info_updates and then use SEP-12 to
  /// collect the information from the user.
  Map<String, Map<String, Sep6FieldInfo>?>? types;

  Sep6WithdrawInfo(this.enabled, this.authenticationRequired, this.feeFixed,
      this.feePercent, this.minAmount, this.maxAmount, this.types);

  static Sep6WithdrawInfo fromSep6WithdrawAsset(
      flutter_sdk.WithdrawAsset asset) {
    Map<String, Map<String, Sep6FieldInfo>?>? types;
    if (asset.types != null) {
      types = {};
      asset.types!.forEach((key, value) {
        Map<String, Sep6FieldInfo>? fieldsInfo;
        if (value != null) {
          fieldsInfo = {};
          value.forEach((fieldKey, fieldValue) {
            fieldsInfo![fieldKey] =
                Sep6FieldInfo.fromSep6AnchorField(fieldValue);
          });
        }
        types![key] = fieldsInfo;
      });
    }

    return Sep6WithdrawInfo(
        asset.enabled,
        asset.authenticationRequired,
        asset.feeFixed,
        asset.feePercent,
        asset.minAmount,
        asset.maxAmount,
        types);
  }
}

class Sep6DepositParams {
  /// The on-chain asset the user wants to get from the Anchor
  /// after doing an off-chain deposit. The value passed must match one of the
  /// codes listed in the /info response's deposit object.
  String assetCode;

  /// The stellar or muxed account ID of the user that wants to deposit.
  /// This is where the asset token will be sent. Note that the account
  /// specified in this request could differ from the account authenticated
  /// via SEP-10.
  String account;

  /// (optional) Type of memo that the anchor should attach to the Stellar
  /// payment transaction, one of text, id or hash.
  MemoType? memoType;

  /// (optional) Value of memo to attach to transaction, for hash this should
  /// be base64-encoded. Because a memo can be specified in the SEP-10 JWT for
  /// Shared Accounts, this field as well as memoType can be different than the
  /// values included in the SEP-10 JWT. For example, a client application
  /// could use the value passed for this parameter as a reference number used
  /// to match payments made to account.
  String? memo;

  /// (optional) Email address of depositor. If desired, an anchor can use
  /// this to send email updates to the user about the deposit.
  String? emailAddress;

  /// (optional) Type of deposit. If the anchor supports multiple deposit
  /// methods (e.g. SEPA or SWIFT), the wallet should specify type. This field
  /// may be necessary for the anchor to determine which KYC fields to collect.
  String? type;

  /// (deprecated, optional) In communications / pages about the deposit,
  /// anchor should display the wallet name to the user to explain where funds
  /// are going. However, anchors should use client_domain (for non-custodial)
  /// and sub value of JWT (for custodial) to determine wallet information.
  String? walletName;

  /// (deprecated,optional) Anchor should link to this when notifying the user
  /// that the transaction has completed. However, anchors should use
  /// client_domain (for non-custodial) and sub value of JWT (for custodial)
  /// to determine wallet information.
  String? walletUrl;

  /// (optional) Defaults to en. Language code specified using ISO 639-1.
  /// error fields in the response should be in this language.
  String? lang;

  /// (optional) A URL that the anchor should POST a JSON message to when the
  /// status property of the transaction created as a result of this request
  /// changes. The JSON message should be identical to the response format
  /// for the /transaction endpoint.
  String? onChangeCallback;

  /// (optional) The amount of the asset the user would like to deposit with
  /// the anchor. This field may be necessary for the anchor to determine
  /// what KYC information is necessary to collect.
  String? amount;

  ///  (optional) The ISO 3166-1 alpha-3 code of the user's current address.
  ///  This field may be necessary for the anchor to determine what KYC
  ///  information is necessary to collect.
  String? countryCode;

  /// (optional) true if the client supports receiving deposit transactions as
  /// a claimable balance, false otherwise.
  String? claimableBalanceSupported;

  /// (optional) id of an off-chain account (managed by the anchor) associated
  /// with this user's Stellar account (identified by the JWT's sub field).
  /// If the anchor supports SEP-12, the customerId field should match the
  /// SEP-12 customer's id. customerId should be passed only when the off-chain
  /// id is know to the client, but the relationship between this id and the
  /// user's Stellar account is not known to the Anchor.
  String? customerId;

  /// (optional) id of the chosen location to drop off cash
  String? locationId;

  Sep6DepositParams(
      {required this.assetCode,
      required this.account,
      this.memoType,
      this.memo,
      this.emailAddress,
      this.type,
      this.walletName,
      this.walletUrl,
      this.lang,
      this.onChangeCallback,
      this.amount,
      this.countryCode,
      this.claimableBalanceSupported,
      this.customerId,
      this.locationId});

  flutter_sdk.DepositRequest toDepositRequest() {
    return flutter_sdk.DepositRequest(
        assetCode: assetCode,
        account: account,
        memoType: memoType?.value,
        memo: memo,
        emailAddress: emailAddress,
        type: type,
        walletName: walletName,
        walletUrl: walletUrl,
        lang: lang,
        onChangeCallback: onChangeCallback,
        amount: amount,
        countryCode: countryCode,
        claimableBalanceSupported: claimableBalanceSupported,
        customerId: customerId,
        locationId: locationId);
  }
}

class Sep6DepositExchangeParams {
  /// The on-chain asset the user wants to get from the Anchor
  /// after doing an off-chain deposit. The value passed must match one of the
  /// codes listed in the /info response's exchange object.
  String destinationAssetCode;

  /// The off-chain asset the Anchor will receive from the user. The value must
  /// match one of the asset values included in a SEP-38
  /// GET /prices?buy_asset=stellar:<destination_asset>:<asset_issuer> response
  /// using SEP-38 Asset Identification Format.
  FiatAssetId sourceAssetId;

  /// The amount of the source_asset the user would like to deposit to the
  /// anchor's off-chain account. This field may be necessary for the anchor
  /// to determine what KYC information is necessary to collect. Should be
  /// equals to quote.sell_amount if a quote_id was used.
  String amount;

  /// The stellar or muxed account ID of the user that wants to deposit.
  /// This is where the asset token will be sent. Note that the account
  /// specified in this request could differ from the account authenticated
  /// via SEP-10.
  String account;

  /// (optional) The id returned from a SEP-38 POST /quote response.
  /// If this parameter is provided and the user delivers the deposit funds
  /// to the Anchor before the quote expiration, the Anchor should respect the
  /// conversion rate agreed in that quote. If the values of destination_asset,
  /// source_asset and amount conflict with the ones used to create the
  /// SEP-38 quote, this request should be rejected with a 400.
  String? quoteId;

  /// (optional) Type of memo that the anchor should attach to the
  /// Stellar payment transaction, one of text, id or hash.
  MemoType? memoType;

  /// (optional) (optional) Value of memo to attach to transaction, for hash
  /// this should be base64-encoded. Because a memo can be specified in the
  /// SEP-10 JWT for Shared Accounts, this field as well as memo_type can
  /// be different than the values included in the SEP-10 JWT. For example,
  /// a client application could use the value passed for this parameter
  /// as a reference number used to match payments made to account.
  String? memo;

  /// (optional) Email address of depositor. If desired, an anchor can use
  /// this to send email updates to the user about the deposit.
  String? emailAddress;

  /// (optional) Type of deposit. If the anchor supports multiple deposit
  /// methods (e.g. SEPA or SWIFT), the wallet should specify type. This field
  /// may be necessary for the anchor to determine which KYC fields to collect.
  String? type;

  /// (deprecated, optional) In communications / pages about the deposit,
  /// anchor should display the wallet name to the user to explain where funds
  /// are going. However, anchors should use client_domain (for non-custodial)
  /// and sub value of JWT (for custodial) to determine wallet information.
  String? walletName;

  /// (deprecated, optional) Anchor should link to this when notifying the user
  /// that the transaction has completed. However, anchors should use
  /// client_domain (for non-custodial) and sub value of JWT (for custodial)
  /// to determine wallet information.
  String? walletUrl;

  /// (optional) Defaults to en if not specified or if the specified language
  /// is not supported. Language code specified using RFC 4646. error fields
  /// and other human readable messages in the response should be in
  /// this language.
  String? lang;

  /// (optional) A URL that the anchor should POST a JSON message to when the
  /// status property of the transaction created as a result of this request
  /// changes. The JSON message should be identical to the response format for
  /// the /transaction endpoint. The callback needs to be signed by the anchor
  /// and the signature needs to be verified by the wallet according to
  /// the callback signature specification.
  String? onChangeCallback;

  /// (optional) The ISO 3166-1 alpha-3 code of the user's current address.
  /// This field may be necessary for the anchor to determine what KYC
  /// information is necessary to collect.
  String? countryCode;

  /// (optional) true if the client supports receiving deposit transactions
  /// as a claimable balance, false otherwise.
  String? claimableBalanceSupported;

  /// (optional) id of an off-chain account (managed by the anchor) associated
  /// with this user's Stellar account (identified by the JWT's sub field).
  /// If the anchor supports SEP-12, the customerId field should match the
  /// SEP-12 customer's id. customerId should be passed only when the off-chain
  /// id is know to the client, but the relationship between this id and the
  /// user's Stellar account is not known to the Anchor.
  String? customerId;

  /// (optional) id of the chosen location to drop off cash
  String? locationId;

  Sep6DepositExchangeParams(
      {required this.destinationAssetCode,
      required this.sourceAssetId,
      required this.amount,
      required this.account,
      this.quoteId,
      this.memoType,
      this.memo,
      this.emailAddress,
      this.type,
      this.walletName,
      this.walletUrl,
      this.lang,
      this.onChangeCallback,
      this.countryCode,
      this.claimableBalanceSupported,
      this.customerId,
      this.locationId});

  flutter_sdk.DepositExchangeRequest toDepositExchangeRequest() {
    return flutter_sdk.DepositExchangeRequest(
        destinationAsset: destinationAssetCode,
        sourceAsset: sourceAssetId.sep38,
        amount: amount,
        account: account,
        quoteId: quoteId,
        memoType: memoType?.value,
        memo: memo,
        emailAddress: emailAddress,
        type: type,
        walletName: walletName,
        walletUrl: walletUrl,
        lang: lang,
        onChangeCallback: onChangeCallback,
        countryCode: countryCode,
        claimableBalanceSupported: claimableBalanceSupported,
        customerId: customerId,
        locationId: locationId);
  }
}

class Sep6WithdrawParams {
  /// The on-chain asset the user wants to withdraw.
  /// The value passed must match one of the codes listed in the /info response's withdraw object.
  String assetCode;

  /// Type of withdrawal. Can be: crypto, bank_account, cash, mobile,
  /// bill_payment or other custom values. This field may be necessary
  /// for the anchor to determine what KYC information is necessary to collect.
  String type;

  /// (Deprecated) The account that the user wants to withdraw their funds to.
  /// This can be a crypto account, a bank account number, IBAN, mobile number,
  /// or email address.
  String? dest;

  /// (Deprecated, optional) Extra information to specify withdrawal location.
  /// For crypto it may be a memo in addition to the dest address.
  /// It can also be a routing number for a bank, a BIC, or the name of a
  /// partner handling the withdrawal.
  String? destExtra;

  /// (optional) The Stellar or muxed account the client will use as the source
  /// of the withdrawal payment to the anchor. If SEP-10 authentication is not
  /// used, the anchor can use account to look up the user's KYC information.
  /// Note that the account specified in this request could differ from the
  /// account authenticated via SEP-10.
  String? account;

  /// (optional) This field should only be used if SEP-10 authentication is not.
  /// It was originally intended to distinguish users of the same Stellar account.
  /// However if SEP-10 is supported, the anchor should use the sub value
  /// included in the decoded SEP-10 JWT instead.
  String? memo;

  /// (Deprecated, optional) Type of memo. One of text, id or hash.
  /// Deprecated because memos used to identify users of the same
  /// Stellar account should always be of type of id.
  MemoType? memoType;

  /// (deprecated, optional) In communications / pages about the withdrawal,
  /// anchor should display the wallet name to the user to explain where funds
  /// are coming from. However, anchors should use client_domain
  /// (for non-custodial) and sub value of JWT (for custodial) to determine
  /// wallet information.
  String? walletName;

  /// (deprecated, optional) Anchor can show this to the user when referencing
  /// the wallet involved in the withdrawal (ex. in the anchor's transaction
  /// history). However, anchors should use client_domain (for non-custodial)
  /// and sub value of JWT (for custodial) to determine wallet information.
  String? walletUrl;

  /// (optional) (optional) Defaults to en if not specified or if the
  /// specified language is not supported. Language code specified using
  /// RFC 4646. error fields and other human readable messages in the
  /// response should be in this language.
  String? lang;

  /// (optional) A URL that the anchor should POST a JSON message to when the
  /// status property of the transaction created as a result of this request
  /// changes. The JSON message should be identical to the response format
  /// for the /transaction endpoint.
  String? onChangeCallback;

  /// (optional) The amount of the asset the user would like to withdraw.
  /// This field may be necessary for the anchor to determine what KYC
  /// information is necessary to collect.
  String? amount;

  /// (optional) The ISO 3166-1 alpha-3 code of the user's current address.
  /// This field may be necessary for the anchor to determine what KYC
  /// information is necessary to collect.
  String? countryCode;

  /// (optional) The memo the anchor must use when sending refund payments back
  /// to the user. If not specified, the anchor should use the same memo used
  /// by the user to send the original payment. If specified, refundMemoType
  /// must also be specified.
  String? refundMemo;

  /// (optional) The type of the refund_memo. Can be id, text, or hash.
  /// If specified, refundMemo must also be specified.
  MemoType? refundMemoType;

  /// (optional) id of an off-chain account (managed by the anchor) associated
  /// with this user's Stellar account (identified by the JWT's sub field).
  /// If the anchor supports SEP-12, the customer_id field should match the
  /// SEP-12 customer's id. customer_id should be passed only when the
  /// off-chain id is know to the client, but the relationship between this id
  /// and the user's Stellar account is not known to the Anchor.
  String? customerId;

  /// (optional) id of the chosen location to pick up cash
  String? locationId;

  Sep6WithdrawParams(
      {required this.assetCode,
      required this.type,
      this.dest,
      this.destExtra,
      this.account,
      this.memo,
      this.memoType,
      this.walletName,
      this.walletUrl,
      this.lang,
      this.onChangeCallback,
      this.amount,
      this.countryCode,
      this.refundMemo,
      this.refundMemoType,
      this.customerId,
      this.locationId});

  flutter_sdk.WithdrawRequest toWithdrawRequest() {
    return flutter_sdk.WithdrawRequest(
        assetCode: assetCode,
        type: type,
        dest: dest,
        destExtra: destExtra,
        account: account,
        memo: memo,
        memoType: memoType?.value,
        walletName: walletName,
        walletUrl: walletUrl,
        lang: lang,
        onChangeCallback: onChangeCallback,
        amount: amount,
        countryCode: countryCode,
        refundMemo: refundMemo,
        refundMemoType: refundMemoType?.value,
        customerId: customerId,
        locationId: locationId);
  }
}

class Sep6WithdrawExchangeParams {
  /// The on-chain asset the user wants to withdraw. The value passed
  /// must match one of the codes listed in the /info response's
  /// withdraw-exchange object.
  String sourceAssetCode;

  /// The off-chain asset the Anchor will deliver to the user's account.
  /// The value must match one of the asset values included in a SEP-38
  /// GET /prices?sell_asset=stellar:<source_asset>:<asset_issuer> response
  /// using SEP-38 Asset Identification Format.
  FiatAssetId destinationAssetId;

  /// The amount of the on-chain asset (source_asset) the user would like to
  /// send to the anchor's Stellar account. This field may be necessary for
  /// the anchor to determine what KYC information is necessary to collect.
  /// Should be equals to quote.sell_amount if a quote_id was used.
  String amount;

  /// Type of withdrawal. Can be: crypto, bank_account, cash, mobile,
  /// bill_payment or other custom values. This field may be necessary for the
  /// anchor to determine what KYC information is necessary to collect.
  String type;

  /// (Deprecated) The account that the user wants to withdraw their
  /// funds to. This can be a crypto account, a bank account number, IBAN,
  /// mobile number, or email address.
  String? dest;

  /// (Deprecated, optional) Extra information to specify withdrawal
  /// location. For crypto it may be a memo in addition to the dest address.
  /// It can also be a routing number for a bank, a BIC, or the name of a
  /// partner handling the withdrawal.
  String? destExtra;

  /// (optional) The id returned from a SEP-38 POST /quote response.
  /// If this parameter is provided and the Stellar transaction used to send
  /// the asset to the Anchor has a created_at timestamp earlier than the
  /// quote's expires_at attribute, the Anchor should respect the conversion
  /// rate agreed in that quote. If the values of destination_asset,
  /// source_asset and amount conflict with the ones used to create the
  /// SEP-38 quote, this request should be rejected with a 400.
  String? quoteId;

  /// (optional) The Stellar or muxed account of the user that wants to do the
  /// withdrawal. This is only needed if the anchor requires KYC information
  /// for withdrawal and SEP-10 authentication is not used. Instead, the anchor
  /// can use account to look up the user's KYC information. Note that the
  /// account specified in this request could differ from the account
  /// authenticated via SEP-10.
  String? account;

  /// (optional) This field should only be used if SEP-10 authentication is not.
  /// It was originally intended to distinguish users of the same Stellar
  /// account. However if SEP-10 is supported, the anchor should use the sub
  /// value included in the decoded SEP-10 JWT instead.
  String? memo;

  /// (Deprecated, optional) Type of memo. One of text, id or hash.
  /// Deprecated because memos used to identify users of the same
  /// Stellar account should always be of type of id.
  MemoType? memoType;

  /// (deprecated, optional) In communications / pages about the withdrawal,
  /// anchor should display the wallet name to the user to explain where funds
  /// are coming from. However, anchors should use client_domain
  /// (for non-custodial) and sub value of JWT (for custodial) to determine
  /// wallet information.
  String? walletName;

  /// (deprecated,optional) Anchor can show this to the user when referencing
  /// the wallet involved in the withdrawal (ex. in the anchor's transaction
  /// history). However, anchors should use client_domain (for non-custodial)
  /// and sub value of JWT (for custodial) to determine wallet information.
  String? walletUrl;

  /// (optional) Defaults to en if not specified or if the specified language
  /// is not supported. Language code specified using RFC 4646. error fields
  /// and other human readable messages in the response should be in
  /// this language.
  String? lang;

  /// (optional) A URL that the anchor should POST a JSON message to when the
  /// status property of the transaction created as a result of this request
  /// changes. The JSON message should be identical to the response format for
  /// the /transaction endpoint. The callback needs to be signed by the anchor
  /// and the signature needs to be verified by the wallet according to
  /// the callback signature specification.
  String? onChangeCallback;

  /// (optional) The ISO 3166-1 alpha-3 code of the user's current address.
  /// This field may be necessary for the anchor to determine what KYC
  /// information is necessary to collect.
  String? countryCode;

  /// (optional) true if the client supports receiving deposit transactions
  /// as a claimable balance, false otherwise.
  String? claimableBalanceSupported;

  /// (optional) The memo the anchor must use when sending refund payments back
  /// to the user. If not specified, the anchor should use the same memo used
  /// by the user to send the original payment. If specified, refundMemoType
  /// must also be specified.
  String? refundMemo;

  /// (optional) The type of the refund_memo. Can be id, text, or hash.
  /// If specified, refundMemo must also be specified.
  MemoType? refundMemoType;

  /// (optional) id of an off-chain account (managed by the anchor) associated
  /// with this user's Stellar account (identified by the JWT's sub field).
  /// If the anchor supports SEP-12, the customer_id field should match the
  /// SEP-12 customer's id. customer_id should be passed only when the
  /// off-chain id is know to the client, but the relationship between this id
  /// and the user's Stellar account is not known to the Anchor.
  String? customerId;

  /// (optional) id of the chosen location to pick up cash
  String? locationId;

  Sep6WithdrawExchangeParams(
      {required this.sourceAssetCode,
      required this.destinationAssetId,
      required this.amount,
      required this.type,
      this.dest,
      this.destExtra,
      this.quoteId,
      this.account,
      this.memo,
      this.memoType,
      this.walletName,
      this.walletUrl,
      this.lang,
      this.onChangeCallback,
      this.countryCode,
      this.claimableBalanceSupported,
      this.refundMemo,
      this.refundMemoType,
      this.customerId,
      this.locationId});

  flutter_sdk.WithdrawExchangeRequest toWithdrawExchangeRequest() {
    return flutter_sdk.WithdrawExchangeRequest(
        sourceAsset: sourceAssetCode,
        destinationAsset: destinationAssetId.sep38,
        amount: amount,
        type: type,
        dest: dest,
        destExtra: destExtra,
        quoteId: quoteId,
        account: account,
        memo: memo,
        memoType: memoType?.value,
        walletName: walletName,
        walletUrl: walletUrl,
        lang: lang,
        onChangeCallback: onChangeCallback,
        countryCode: countryCode,
        claimableBalanceSupported: claimableBalanceSupported,
        refundMemo: refundMemo,
        refundMemoType: refundMemoType?.value,
        customerId: customerId,
        locationId: locationId);
  }
}

class Sep6WithdrawExchangeInfo {
  /// true if SEP-6 withdrawal for this asset is supported
  bool enabled;

  /// Optional. true if client must be authenticated before accessing
  /// the withdraw endpoint for this asset. false if not specified.
  bool? authenticationRequired;

  /// A map with each type of withdrawal supported for that asset as a key.
  /// Each type can specify a field info object explaining what fields
  /// are needed and what they do. Anchors are encouraged to use SEP-9
  /// financial account fields, but can also define custom fields if necessary.
  /// If a fields object is not specified, the wallet should assume that no
  /// extra field info are needed for that type of withdrawal. In the case that
  /// the Anchor requires additional fields for a withdrawal, it should set the
  /// transaction status to pending_customer_info_update. The wallet can query
  /// the /transaction endpoint to get the field info needed to complete the
  /// transaction in required_customer_info_updates and then use SEP-12 to
  /// collect the information from the user.
  Map<String, Map<String, Sep6FieldInfo>?>? types;

  Sep6WithdrawExchangeInfo(
      this.enabled, this.authenticationRequired, this.types);

  static Sep6WithdrawExchangeInfo fromSep6WithdrawExchangeAsset(
      flutter_sdk.WithdrawExchangeAsset asset) {
    Map<String, Map<String, Sep6FieldInfo>?>? types;
    if (asset.types != null) {
      types = {};
      asset.types!.forEach((key, value) {
        Map<String, Sep6FieldInfo>? fieldsInfo;
        if (value != null) {
          fieldsInfo = {};
          value.forEach((fieldKey, fieldValue) {
            fieldsInfo![fieldKey] =
                Sep6FieldInfo.fromSep6AnchorField(fieldValue);
          });
        }
        types![key] = fieldsInfo;
      });
    }

    return Sep6WithdrawExchangeInfo(
        asset.enabled, asset.authenticationRequired, types);
  }
}

class Sep6EndpointInfo {
  /// true if the endpoint is available.
  bool enabled;

  /// true if client must be authenticated before accessing the endpoint.
  bool? authenticationRequired;

  /// Optional. Anchors are encouraged to add a description field to the
  /// fee object returned in GET /info containing a short explanation of
  /// how fees are calculated so client applications will be able to display
  /// this message to their users. This is especially important if the
  /// GET /fee endpoint is not supported and fees cannot be models using
  /// fixed and percentage values for each Stellar asset.
  String? description;

  Sep6EndpointInfo(this.enabled, this.authenticationRequired, this.description);

  static Sep6EndpointInfo fromSep6AnchorFeeInfo(
      flutter_sdk.AnchorFeeInfo info) {
    return Sep6EndpointInfo(
        info.enabled ?? false, info.authenticationRequired, info.description);
  }

  static Sep6EndpointInfo fromSep6AnchorTransactionInfo(
      flutter_sdk.AnchorTransactionInfo info) {
    return Sep6EndpointInfo(
        info.enabled ?? false, info.authenticationRequired, null);
  }

  static Sep6EndpointInfo fromSep6AnchorTransactionsInfo(
      flutter_sdk.AnchorTransactionsInfo info) {
    return Sep6EndpointInfo(
        info.enabled ?? false, info.authenticationRequired, null);
  }
}

class Sep6FeaturesInfo {
  /// Whether or not the anchor supports creating accounts for users requesting
  /// deposits. Defaults to true.
  bool accountCreation;

  /// Whether or not the anchor supports sending deposit funds as claimable
  /// balances. This is relevant for users of Stellar accounts without a
  /// trustline to the requested asset. Defaults to false.
  bool claimableBalances;

  Sep6FeaturesInfo(this.accountCreation, this.claimableBalances);

  static Sep6FeaturesInfo fromSep6AnchorFeatureFlags(
      flutter_sdk.AnchorFeatureFlags flags) {
    return Sep6FeaturesInfo(flags.accountCreation, flags.claimableBalances);
  }
}
