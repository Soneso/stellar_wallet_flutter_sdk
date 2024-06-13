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
      {String limit = "98398398293"}) {
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

  TxBuilder transfer(
      String destinationAddress, StellarAssetId assetId, String amount) {
    var op = flutter_sdk.PaymentOperationBuilder(
            destinationAddress, assetId.toAsset(), amount)
        .setSourceAccount(sourceAccount.accountId)
        .build();
    sdkBuilder.addOperation(op);
    return this;
  }

  TxBuilder strictSend(
      {required StellarAssetId sendAssetId,
      required String sendAmount,
      required String destinationAddress,
      required StellarAssetId destinationAssetId,
      required String destinationMinAmount,
      List<StellarAssetId>? path}) {
    var opBuilder = flutter_sdk.PathPaymentStrictSendOperationBuilder(
            sendAssetId.toAsset(),
            sendAmount,
            destinationAddress,
            destinationAssetId.toAsset(),
            destinationMinAmount)
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

  TxBuilder strictReceive(
      {required StellarAssetId sendAssetId,
      required String sendMaxAmount,
      required String destinationAddress,
      required StellarAssetId destinationAssetId,
      required String destinationAmount,
      List<StellarAssetId>? path}) {
    var opBuilder = flutter_sdk.PathPaymentStrictReceiveOperationBuilder(
            sendAssetId.toAsset(),
            sendMaxAmount,
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
    var builderAccount = flutter_sdk.Account(sponsoredAccountId, 0);
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
