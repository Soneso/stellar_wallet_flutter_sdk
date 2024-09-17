// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/asset/asset_id.dart';
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/horizon/account.dart';

abstract class CommonTxBuilder<T> {
  late flutter_sdk.TransactionBuilder sdkBuilder;
  late flutter_sdk.TransactionBuilderAccount sourceAccount;

  CommonTxBuilder(this.sourceAccount) {
    sdkBuilder = flutter_sdk.TransactionBuilder(sourceAccount);
  }

  CommonTxBuilder<T> addAccountSigner(
      AccountKeyPair signerAddress, int signerWeight) {
    var signer = signerAddress.keyPair.xdrSignerKey;
    var op = flutter_sdk.SetOptionsOperationBuilder()
        .setSourceAccount(sourceAccount.accountId)
        .setSigner(signer, signerWeight)
        .build();
    sdkBuilder.addOperation(op);
    return this;
  }

  CommonTxBuilder<T> removeAccountSigner(AccountKeyPair signerAddress) {
    if (signerAddress.address == sourceAccount.accountId) {
      throw Exception(
          "This method can't be used to remove master signer key, call the lockAccountMasterKey method instead");
    }
    return addAccountSigner(signerAddress, 0);
  }

  CommonTxBuilder<T> lockAccountMasterKey() {
    var op = flutter_sdk.SetOptionsOperationBuilder()
        .setSourceAccount(sourceAccount.accountId)
        .setMasterKeyWeight(0)
        .build();
    sdkBuilder.addOperation(op);
    return this;
  }

  CommonTxBuilder<T> addAssetSupport(IssuedAssetId asset,
      {String limit = '922337203685.4775807'}) {
    var op = flutter_sdk.ChangeTrustOperationBuilder(asset.toAsset(), limit)
        .setSourceAccount(sourceAccount.accountId)
        .build();
    sdkBuilder.addOperation(op);
    return this;
  }

  CommonTxBuilder<T> removeAssetSupport(IssuedAssetId asset) {
    return addAssetSupport(asset, limit: "0");
  }

  CommonTxBuilder<T> setThreshold(
      {required int low, required int medium, required int high}) {
    var op = flutter_sdk.SetOptionsOperationBuilder()
        .setSourceAccount(sourceAccount.accountId)
        .setLowThreshold(low)
        .setMediumThreshold(medium)
        .setHighThreshold(high)
        .build();
    sdkBuilder.addOperation(op);
    return this;
  }

  flutter_sdk.Transaction build() {
    return sdkBuilder.build();
  }
}

/// Used for building transactions.
class TxBuilder extends CommonTxBuilder<TxBuilder> {
  TxBuilder(super.sourceAccount);

  TxBuilder setMemo(flutter_sdk.Memo memo) {
    sdkBuilder.addMemo(memo);
    return this;
  }

  TxBuilder setTimeBounds(flutter_sdk.TimeBounds timeBounds) {
    var preconditions = flutter_sdk.TransactionPreconditions();
    preconditions.timeBounds = timeBounds;
    sdkBuilder.addPreconditions(preconditions);
    return this;
  }

  TxBuilder setBaseFee(int baseFeeInStoops) {
    sdkBuilder.setMaxOperationFee(baseFeeInStoops);
    return this;
  }

  TxBuilder createAccount(AccountKeyPair newAccount,
      {String startingBalance = "1"}) {
    if (double.parse(startingBalance) < 1) {
      throw InvalidStartingBalanceException();
    }

    var op = flutter_sdk.CreateAccountOperationBuilder(
            newAccount.address, startingBalance)
        .setSourceAccount(sourceAccount.accountId)
        .build();
    sdkBuilder.addOperation(op);
    return this;
  }

  /// Merges account into a destination account.
  /// **Warning**: This operation will give full control of the account to the destination account,
  /// effectively removing the merged account from the network.
  /// Params: [destinationAddress] of the stellar account to merge into.
  /// Optional [sourceAddress] account id of the account that is being merged. If not given then will default to
  /// the TransactionBuilder source account.
  TxBuilder accountMerge({required String destinationAddress, String? sourceAddress}) {
    var op = flutter_sdk.AccountMergeOperationBuilder(
        destinationAddress)
        .setSourceAccount(sourceAddress ?? sourceAccount.accountId)
        .build();
    sdkBuilder.addOperation(op);
    return this;
  }

  TxBuilder transfer(
      String destinationAddress, StellarAssetId assetId, String amount) {
    var op = flutter_sdk.PaymentOperationBuilder(
            destinationAddress, assetId.toAsset(), amount)
        .setSourceAccount(sourceAccount.accountId)
        .build();
    sdkBuilder.addOperation(op);
    return this;
  }

  /// Creates and adds a path payment operation to the transaction builder.
  /// Params: The [destinationAddress] to which the payment is sent, the [sendAsset] - asset to be sent.
  /// The [destinationAsset] the destination will receive. The amount to be sent [sendAmount],
  /// The [destAmount] to be received by the destination. Must specify either [sendAmount] or
  /// [destAmount], but not both. [destMin] - the minimum amount of the destination asset to be receive. This is a
  /// protective measure, it allows you to specify a lower bound for an acceptable conversion. Only used
  /// if using [sendAmount] (optional, default is ".0000001"). [sendMax] - the maximum amount of the destination
  /// asset to be sent. This is a protective measure, it allows you to specify an upper bound for an acceptable
  /// conversion. Only used if using [destAmount] (optional, default is int64 max).
  /// And optional the payment [path], that can be selected from the result
  /// of using [Stellar.findStrictSendPathForDestinationAddress] or [Stellar.findStrictSendPathForDestinationAssets] if
  /// [sendAmount] is given, or [Stellar.findStrictReceivePathForSourceAssets] or [Stellar.findStrictReceivePathForSourceAddress]
  /// if [destAmount] is given.
  /// Returns the current instance of the TransactionBuilder for method chaining.
  TxBuilder pathPay({
    required String destinationAddress,
    required StellarAssetId sendAsset,
    required StellarAssetId destinationAsset,
    String? sendAmount,
    String? destAmount,
    String? destMin,
    String? sendMax,
    List<StellarAssetId>? path,
  }) {
    if ((sendAmount != null && destAmount != null) ||
        (sendAmount == null && destAmount == null)) {
      throw PathPayOnlyOneAmountException();
    }

    if (sendAmount != null) {
      return strictSend(
          sendAssetId: sendAsset,
          sendAmount: sendAmount,
          destinationAddress: destinationAddress,
          destinationAssetId: destinationAsset,
          destinationMinAmount: destMin,
          path: path);
    } else {
      return strictReceive(
          sendAssetId: sendAsset,
          sendMaxAmount: sendMax,
          destinationAddress: destinationAddress,
          destinationAssetId: destinationAsset,
          destinationAmount: destAmount!,
          path: path);
    }
  }

  /// Swap assets using the Stellar network. This swaps using the
  /// pathPaymentStrictSend operation. Params: The source asset to be sent [fromAsset].
  /// The destination asset to receive [toAsset]. The [amount] of the source asset to be sent.
  /// (Optional) The minimum amount of the destination asset to be received [destMin].
  /// And optional the payment [path], that can be selected from the result
  /// of using [Stellar.findStrictSendPathForDestinationAddress] or [Stellar.findStrictSendPathForDestinationAssets]
  /// Returns the current instance of the TransactionBuilder for method chaining.
  TxBuilder swap({
    required StellarAssetId fromAsset,
    required StellarAssetId toAsset,
    required String amount,
    String? destMin,
    List<StellarAssetId>? path,
  }) {
    return pathPay(destinationAddress: sourceAccount.accountId,
        sendAsset: fromAsset, destinationAsset: toAsset,
        sendAmount: amount, destMin: destMin, path: path);
  }

  /// Creates and adds a strict send path payment operation to the transaction builder.
  /// Params: The [sendAssetId] - asset to be sent. The amount to be sent [sendAmount],
  /// The [destinationAddress] to which the payment is sent, the asset identified by [destinationAssetId] the
  /// destination will receive. [destinationMinAmount] - the minimum amount of the destination asset to be receive.
  /// This is a protective measure, it allows you to specify a lower bound for an acceptable conversion
  /// (optional, default is ".0000001"). And optional the payment [path], that can be selected from the result
  /// of using [Stellar.findStrictSendPathForDestinationAddress] or [Stellar.findStrictSendPathForDestinationAssets].
  TxBuilder strictSend(
      {required StellarAssetId sendAssetId,
      required String sendAmount,
      required String destinationAddress,
      required StellarAssetId destinationAssetId,
      String? destinationMinAmount,
      List<StellarAssetId>? path}) {
    var opBuilder = flutter_sdk.PathPaymentStrictSendOperationBuilder(
            sendAssetId.toAsset(),
            sendAmount,
            destinationAddress,
            destinationAssetId.toAsset(),
            destinationMinAmount ?? '0.0000001')
        .setSourceAccount(sourceAccount.accountId);
    if (path != null) {
      List<flutter_sdk.Asset> assetPath =
          List<flutter_sdk.Asset>.empty(growable: true);
      for (var assetId in path) {
        assetPath.add(assetId.toAsset());
      }
      opBuilder.setPath(assetPath);
    }
    sdkBuilder.addOperation(opBuilder.build());
    return this;
  }

  /// Creates and adds a strict receive path payment operation to the transaction builder.
  /// Params: The [sendAsset] - asset to be sent. The [destinationAddress] to which the payment
  /// is sent, the asset identified by [destinationAssetId] the destination will receive.
  /// The [destinationAmount] to be received by the destination.
  /// Optional [sendMaxAmount] - the maximum amount of the destination asset to be sent.
  /// This is a protective measure, it allows you to specify an upper bound for an acceptable
  /// conversion (optional, default is int64 max).  And optional the payment [path], that can be selected from the result
  /// of using [Stellar.findStrictReceivePathForSourceAssets] or [Stellar.findStrictReceivePathForSourceAddress].
  TxBuilder strictReceive(
      {required StellarAssetId sendAssetId,
      required String destinationAddress,
      required StellarAssetId destinationAssetId,
      required String destinationAmount,
        required String? sendMaxAmount,
      List<StellarAssetId>? path}) {
    var opBuilder = flutter_sdk.PathPaymentStrictReceiveOperationBuilder(
            sendAssetId.toAsset(),
            sendMaxAmount ?? '922337203685.4775807',
            destinationAddress,
            destinationAssetId.toAsset(),
            destinationAmount)
        .setSourceAccount(sourceAccount.accountId);
    if (path != null) {
      List<flutter_sdk.Asset> assetPath =
          List<flutter_sdk.Asset>.empty(growable: true);
      for (var assetId in path) {
        assetPath.add(assetId.toAsset());
      }
      opBuilder.setPath(assetPath);
    }
    sdkBuilder.addOperation(opBuilder.build());
    return this;
  }

  TxBuilder addOperation(flutter_sdk.Operation operation) {
    sdkBuilder.addOperation(operation);
    return this;
  }

  TxBuilder sponsoring(AccountKeyPair sponsorAccount,
      Function(SponsoringBuilder builder) buildingFunction,
      {AccountKeyPair? sponsoredAccount}) {
    var sponsoredAccountId = sponsoredAccount != null
        ? sponsoredAccount.address
        : sourceAccount.accountId;
    var beginSponsoringOp =
        flutter_sdk.BeginSponsoringFutureReservesOperationBuilder(
                sponsoredAccountId)
            .setSourceAccount(sponsorAccount.address)
            .build();
    sdkBuilder.addOperation(beginSponsoringOp);
    var builderAccount = flutter_sdk.Account(sponsoredAccountId, BigInt.zero);
    var opBuilder = SponsoringBuilder(builderAccount, sponsorAccount);
    buildingFunction(opBuilder);
    var tx = opBuilder.build();
    for (var op in tx.operations) {
      sdkBuilder.addOperation(op);
    }
    var endSponsoringOp =
        flutter_sdk.EndSponsoringFutureReservesOperationBuilder()
            .setSourceAccount(sponsoredAccountId)
            .build();
    sdkBuilder.addOperation(endSponsoringOp);
    return this;
  }
}

class SponsoringBuilder extends CommonTxBuilder<SponsoringBuilder> {
  AccountKeyPair sponsorAccount;

  SponsoringBuilder(super.sourceAccount, this.sponsorAccount);

  SponsoringBuilder addManageDataOperation(
      flutter_sdk.ManageDataOperation operation) {
    sdkBuilder.addOperation(operation);
    return this;
  }

  SponsoringBuilder addManageBuyOfferOperation(
      flutter_sdk.ManageBuyOfferOperation operation) {
    sdkBuilder.addOperation(operation);
    return this;
  }

  SponsoringBuilder addManageSellOfferOperation(
      flutter_sdk.ManageSellOfferOperation operation) {
    sdkBuilder.addOperation(operation);
    return this;
  }

  SponsoringBuilder addSetOptionsOperation(
      flutter_sdk.SetOptionsOperation operation) {
    sdkBuilder.addOperation(operation);
    return this;
  }

  SponsoringBuilder createAccount(AccountKeyPair newAccount,
      {String startingBalance = "0"}) {
    if (double.parse(startingBalance) < 0) {
      throw InvalidStartingBalanceException();
    }

    var op = flutter_sdk.CreateAccountOperationBuilder(
            newAccount.address, startingBalance)
        .setSourceAccount(sponsorAccount.address)
        .build();
    sdkBuilder.addOperation(op);
    return this;
  }
}
