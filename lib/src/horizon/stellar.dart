// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/horizon/account.dart';
import 'package:stellar_wallet_flutter_sdk/src/wallet.dart';

class Stellar {
  Config cfg;

  Stellar(this.cfg);

  AccountService account() {
    return AccountService(cfg);
  }

  Future<bool> submitTransaction(flutter_sdk.AbstractTransaction transaction) async {
      var horizonUrl = cfg.stellar.horizonUrl;
      flutter_sdk.StellarSDK sdk = flutter_sdk.StellarSDK(horizonUrl);
      try {
        var txEnv = transaction.toEnvelopeXdrBase64();
        flutter_sdk.SubmitTransactionResponse response = await sdk
            .submitTransactionEnvelopeXdrBase64(txEnv);
        if (!response.success) {
          throw TransactionSubmitFailedException(response);
        }
        return true;
      } catch(e) {
        if (e is flutter_sdk.SubmitTransactionTimeoutResponseException) {
          // timed out. Resubmitting...
          return await submitTransaction(transaction);
        } else {
          rethrow;
        }
      }
  }
}