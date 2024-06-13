// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/wallet.dart';

/// Stellar account's key pair. It can be either [PublicKeyPair] obtained from public key, or
/// [SigningKeyPair], obtained from private key. Existing account in string format can be converted
/// to public key pair via calling [toPublicKeyPair] helper function.
abstract class AccountKeyPair {
  flutter_sdk.KeyPair keyPair;
  AccountKeyPair(this.keyPair);

  String get address => keyPair.accountId;
  Uint8List get publicKey => keyPair.publicKey;
}

class PublicKeyPair extends AccountKeyPair {
  PublicKeyPair(super.keyPair);

  static PublicKeyPair fromAccountId(String accountId) {
    var kp = flutter_sdk.KeyPair.fromAccountId(accountId);
    return PublicKeyPair(kp);
  }
}

class SigningKeyPair extends AccountKeyPair {
  SigningKeyPair(super.keyPair) {
    if (keyPair.privateKey == null) {
      throw ValidationException(
          "This keypair doesn't have private key and can't sign");
    }
  }

  String get secretKey => keyPair.secretSeed;

  static SigningKeyPair random() {
    return SigningKeyPair(flutter_sdk.KeyPair.random());
  }

  sign(flutter_sdk.AbstractTransaction transaction,
      flutter_sdk.Network network) {
    transaction.sign(keyPair, network);
  }

  static SigningKeyPair fromSecret(String secret) {
    return SigningKeyPair(flutter_sdk.KeyPair.fromSecretSeed(secret));
  }

  PublicKeyPair toPublicKeyPair() {
    return PublicKeyPair(flutter_sdk.KeyPair.fromAccountId(address));
  }
}

class AccountService {
  Config cfg;
  AccountService(this.cfg);

  /// Generate new account keypair (public and secret key). This key pair can be used to create a
  /// Stellar account.
  SigningKeyPair createKeyPair() {
    return SigningKeyPair.random();
  }

  Future <flutter_sdk.AccountResponse> getInfo(String accountAddress) async {
    var horizonUrl = cfg.stellar.horizonUrl;
    flutter_sdk.StellarSDK sdk = flutter_sdk.StellarSDK(horizonUrl);
    try {
      return  await sdk.accounts.account(accountAddress);
    } catch (e) {
      if (e is flutter_sdk.ErrorResponse) {
        if (e.code != 404) {
          throw HorizonRequestFailedException(e);
        } else {
          throw ValidationException("Account dose not exist");
        }
      } else {
        rethrow;
      }
    }
  }

  Future <bool> accountExists(String accountAddress) async {
    var horizonUrl = cfg.stellar.horizonUrl;
    flutter_sdk.StellarSDK sdk = flutter_sdk.StellarSDK(horizonUrl);
    try {
      await sdk.accounts.account(accountAddress);
      return true;
    } catch (e) {
      if (e is flutter_sdk.ErrorResponse) {
        if (e.code != 404) {
          throw HorizonRequestFailedException(e);
        } else {
          return false;
        }
      } else {
        rethrow;
      }
    }
  }

  Future<bool> fundTestNetAccount(String address) async {
    return await flutter_sdk.FriendBot.fundTestAccount(address);
  }

  /// checks if a given address (accountId) is valid or not.
  /// if valid returns true, otherwise false.
  static bool validateAddress(String address) {
    try {
      PublicKeyPair.fromAccountId(address);
      return true;
    } catch (e) {
      return false;
    }
  }

}

/// Account weights threshold
class AccountThreshold {
  int low;
  int medium;
  int high;

  /// Constructor
  /// [low] threshold weight
  /// [medium] threshold weight
  /// [high] threshold weight
  AccountThreshold(this.low, this.medium, this.high);
}