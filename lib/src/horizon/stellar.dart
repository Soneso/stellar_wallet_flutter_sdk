// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

class Stellar {
  /// Configurations.
  Config cfg;

  /// Constructor.
  Stellar(this.cfg);

  /// returns the [AccountService]
  AccountService account() {
    return AccountService(cfg);
  }

  /// Submit a [signedTransaction] to the Stellar Network. Returns true if submitted successfully.
  /// Throws [TransactionSubmitFailedException] when submission fasiled.
  Future<bool> submitTransaction(
      flutter_sdk.AbstractTransaction signedTransaction) async {
    var sdk = server;
    try {
      var txEnv = signedTransaction.toEnvelopeXdrBase64();
      flutter_sdk.SubmitTransactionResponse response =
          await sdk.submitTransactionEnvelopeXdrBase64(txEnv);
      if (!response.success) {
        throw TransactionSubmitFailedException(response);
      }
      return true;
    } catch (e) {
      if (e is flutter_sdk.SubmitTransactionTimeoutResponseException) {
        // timed out. Resubmitting...
        return await submitTransaction(signedTransaction);
      } else {
        rethrow;
      }
    }
  }

  Future<bool> submitWithFeeIncrease(
      {required SigningKeyPair sourceAddress,
      required Duration timeout,
      required int baseFeeIncrease,
      required int maxBaseFee,
      required Function(TxBuilder builder) buildingFunction,
      int? baseFee,
      flutter_sdk.Memo? memo}) async {
    return await submitWithFeeIncreaseAndSignerFunction(
        sourceAddress: sourceAddress,
        timeout: timeout,
        baseFeeIncrease: baseFeeIncrease,
        maxBaseFee: maxBaseFee,
        buildingFunction: (builder) => buildingFunction(builder),
        signerFunction: (transaction) => sign(transaction, sourceAddress),
        baseFee: baseFee,
        memo: memo);
  }

  Future<bool> submitWithFeeIncreaseAndSignerFunction(
      {required AccountKeyPair sourceAddress,
      required Duration timeout,
      required int baseFeeIncrease,
      required int maxBaseFee,
      required Function(TxBuilder builder) buildingFunction,
      required Function(flutter_sdk.AbstractTransaction transaction)
          signerFunction,
      int? baseFee,
      flutter_sdk.Memo? memo}) async {
    var sdk = server;

    var txBuilder = await transaction(sourceAddress,
        timeout: timeout, baseFee: baseFee, memo: memo);
    buildingFunction(txBuilder);

    var tx = txBuilder.build();
    signerFunction(tx);

    try {
      var txEnv = tx.toEnvelopeXdrBase64();
      flutter_sdk.SubmitTransactionResponse response =
          await sdk.submitTransactionEnvelopeXdrBase64(txEnv);
      if (!response.success) {
        throw TransactionSubmitFailedException(response);
      }
      return true;
    } catch (e) {
      if (e is flutter_sdk.SubmitTransactionTimeoutResponseException) {
        // Transaction has expired, Increasing fee.
        var newFee = min(maxBaseFee, tx.fee + baseFeeIncrease);
        print("Transaction has expired. Increasing fee to $newFee Stroops.");
        return await submitWithFeeIncreaseAndSignerFunction(
            sourceAddress: sourceAddress,
            timeout: timeout,
            baseFeeIncrease: baseFeeIncrease,
            maxBaseFee: maxBaseFee,
            buildingFunction: buildingFunction,
            signerFunction: signerFunction,
            baseFee: newFee,
            memo: memo);
      } else {
        rethrow;
      }
    }
  }

  /// Decode transaction from the given [xdr] base 64 string.
  flutter_sdk.AbstractTransaction decodeTransaction(String xdr) {
    return flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(xdr);
  }

  /// Creates builder that allows to form Stellar transaction, adding Stellar's
  /// operations https://developers.stellar.org/docs/fundamentals-and-concepts/list-of-operations#payment
  /// Parameters are the [sourceAddress] of the account initiating a transaction.
  /// [baseFee] that will be used for this transaction. If not specified
  /// [cfg.stellar.baseFee] will be used.
  /// Optional [timeout] Duration after which transaction expires. If not specified,
  /// [cfg.stellar.defaultTimeout] will be used.
  /// optional transaction [memo]. Returns [TxBuilder], the transaction builder.
  Future<TxBuilder> transaction(AccountKeyPair sourceAddress,
      {Duration? timeout, int? baseFee, flutter_sdk.Memo? memo}) async {
    var accountService = account();
    var accountResponse = await accountService.getInfo(sourceAddress.address);
    var txBaseFee = baseFee ?? cfg.stellar.baseFee;
    var txBuilder = TxBuilder(accountResponse).setBaseFee(txBaseFee);
    if (memo != null) {
      txBuilder = txBuilder.setMemo(memo);
    }

    var txTimeout = timeout ?? cfg.stellar.defaultTimeout;
    var timeBounds = flutter_sdk.TimeBounds(
        0, DateTime.now().add(txTimeout).millisecondsSinceEpoch ~/ 1000);
    txBuilder = txBuilder.setTimeBounds(timeBounds);

    return txBuilder;
  }

  /// Server (flutter sdk) allowing you to query data from Horizon.
  flutter_sdk.StellarSDK get server {
    var horizonUrl = cfg.stellar.horizonUrl;
    return flutter_sdk.StellarSDK(horizonUrl);
  }

  /// Signs the transaction with the given keypair. Uses the network from [cfg.stellar.network].
  sign(flutter_sdk.AbstractTransaction tx, SigningKeyPair keyPair) {
    tx.sign(keyPair.keyPair, cfg.stellar.network);
  }

  /// Creates and returns a [FeeBumpTransaction] (see https://developers.stellar.org/docs/encyclopedia/fee-bump-transactions).
  /// for the given [feeAddress] that will pay the transaction's fee and
  /// the [transaction] for which fee should be paid (inner transaction).
  /// Optional parameter is [baseFee] If not specified, [cfg.stellar.baseFee] will be used.
  flutter_sdk.FeeBumpTransaction makeFeeBump(
      AccountKeyPair feeAddress, flutter_sdk.Transaction transaction,
      {int? baseFee}) {
    var txBaseFee = baseFee ?? cfg.stellar.baseFee;
    var txBuilder = flutter_sdk.FeeBumpTransactionBuilder(transaction)
        .setBaseFee(txBaseFee)
        .setFeeAccount(feeAddress.address);
    return txBuilder.build();
  }

  /// Fetches available paths on the Stellar network between the [destinationAddress], and the [sourceAssetId] sent by the source account
  /// considering the given [sourceAmount]. Returns an array of payment paths that can be selected for the transaction.
  /// Returns an empty list if no payment path could be found.
  Future<List<PaymentPath>> findStrictSendPathForDestinationAddress(StellarAssetId sourceAssetId,
      String sourceAmount, String destinationAddress) async {
    final sdk = server;
    List<PaymentPath> result = List<PaymentPath>.empty(growable: true);

    try {
      flutter_sdk.Page<flutter_sdk.PathResponse> strictSendPaths = await sdk
          .strictSendPaths
          .sourceAsset(sourceAssetId.toAsset())
          .sourceAmount(sourceAmount)
          .destinationAccount(destinationAddress)
          .execute();
      if (strictSendPaths.records != null) {
        final records = strictSendPaths.records!;
        for (final record in records) {
          result.add(PaymentPath.fromPathResponse(record));
        }
      }
    } catch (exception) {
      // request failed.
    }

    return result;
  }

  /// Fetches available paths on the Stellar network between the [sourceAssetId] sent by the source account
  /// and the given [destinationAssets] considering the [sourceAmount].
  /// Returns an array of payment paths that can be selected for the transaction.
  /// Returns an empty list if no payment path could be found.
  Future<List<PaymentPath>> findStrictSendPathForDestinationAssets(StellarAssetId sourceAssetId,
      String sourceAmount, List<StellarAssetId> destinationAssets) async {
    final sdk = server;
    List<PaymentPath> result = List<PaymentPath>.empty(growable: true);

    try {
      List<flutter_sdk.Asset> sdkDestinationAssets =
      List<flutter_sdk.Asset>.empty(growable: true);
      for (final asset in destinationAssets) {
        sdkDestinationAssets.add(asset.toAsset());
      }

      flutter_sdk.Page<flutter_sdk.PathResponse> strictSendPaths = await sdk
          .strictSendPaths
          .sourceAsset(sourceAssetId.toAsset())
          .sourceAmount(sourceAmount)
          .destinationAssets(sdkDestinationAssets)
          .execute();
      if (strictSendPaths.records != null) {
        final records = strictSendPaths.records!;
        for (final record in records) {
          result.add(PaymentPath.fromPathResponse(record));
        }
      }
    } catch (exception) {
      // request failed.
    }

    return result;
  }

  /// Fetches available payment paths on the Stellar network between the given [sourceAssets],
  /// the [destinationAssetId] considering the given [destinationAmount] to be received by the destination.
  /// Returns an array of payment paths that can be selected for the transaction.
  /// Returns an empty list if no payment path could be found.
  Future<List<PaymentPath>> findStrictReceivePathForSourceAssets(
      StellarAssetId destinationAssetId,
      String destinationAmount,
      List<StellarAssetId> sourceAssets) async {
    final sdk = server;
    List<PaymentPath> result = List<PaymentPath>.empty(growable: true);

    try {
      List<flutter_sdk.Asset> sdkSourceAssets =
          List<flutter_sdk.Asset>.empty(growable: true);
      for (final asset in sourceAssets) {
        sdkSourceAssets.add(asset.toAsset());
      }

      flutter_sdk.Page<flutter_sdk.PathResponse> strictSendPaths = await sdk
          .strictReceivePaths
          .destinationAsset(destinationAssetId.toAsset())
          .destinationAmount(destinationAmount)
          .sourceAssets(sdkSourceAssets)
          .execute();
      if (strictSendPaths.records != null) {
        final records = strictSendPaths.records!;
        for (final record in records) {
          result.add(PaymentPath.fromPathResponse(record));
        }
      }
    } catch (exception) {
      // request failed.
    }

    return result;
  }

  /// Fetches available payment paths on the Stellar network between the assets hold by the [sourceAddress],
  /// the [destinationAssetId] considering the given [destinationAmount] to be received by the destination.
  /// Returns an array of payment paths that can be selected for the transaction.
  /// Returns an empty list if no payment path could be found.
  Future<List<PaymentPath>> findStrictReceivePathForSourceAddress(
      StellarAssetId destinationAssetId,
      String destinationAmount,
      String sourceAddress) async {
    final sdk = server;
    List<PaymentPath> result = List<PaymentPath>.empty(growable: true);

    try {
      flutter_sdk.Page<flutter_sdk.PathResponse> strictSendPaths = await sdk
          .strictReceivePaths
          .destinationAsset(destinationAssetId.toAsset())
          .destinationAmount(destinationAmount)
          .sourceAccount(sourceAddress)
          .execute();
      if (strictSendPaths.records != null) {
        final records = strictSendPaths.records!;
        for (final record in records) {
          result.add(PaymentPath.fromPathResponse(record));
        }
      }
    } catch (exception) {
      // request failed.
    }

    return result;
  }
}

/// used as a result when fetching path payments.
class PaymentPath {
  String sourceAmount;
  StellarAssetId sourceAsset;

  String destinationAmount;
  StellarAssetId destinationAsset;

  List<StellarAssetId> path;

  PaymentPath(this.sourceAmount, this.sourceAsset, this.destinationAmount,
      this.destinationAsset, this.path);

  static PaymentPath fromPathResponse(flutter_sdk.PathResponse response) {
    final sourceAsset = StellarAssetId.fromAsset(response.sourceAsset);
    final sourceAmount = response.sourceAmount;
    final destinationAsset =
        StellarAssetId.fromAsset(response.destinationAsset);
    final destinationAmount = response.destinationAmount;
    List<StellarAssetId> path = List<StellarAssetId>.empty(growable: true);
    for (final asset in response.path) {
      path.add(StellarAssetId.fromAsset(asset));
    }
    return PaymentPath(
        sourceAmount, sourceAsset, destinationAmount, destinationAsset, path);
  }
}
