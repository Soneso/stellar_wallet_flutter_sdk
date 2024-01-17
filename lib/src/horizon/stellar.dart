// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/horizon/transaction.dart';
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
}
