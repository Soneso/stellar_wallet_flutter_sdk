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
}

class SigningKeyPair extends AccountKeyPair {
  SigningKeyPair(super.keyPair) {
    if (keyPair.privateKey == null) {
      throw ValidationException(
          "This keypair doesn't have private key and can't sign");
    }
  }

  String get secretKey => keyPair.secretSeed;

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
    return SigningKeyPair(flutter_sdk.KeyPair.random());
  }
}