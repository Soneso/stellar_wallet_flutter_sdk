// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/auth/sep_10.dart';
import 'package:stellar_wallet_flutter_sdk/src/auth/wallet_signer.dart';
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/horizon/account.dart';
import 'package:stellar_wallet_flutter_sdk/src/wallet.dart';
import 'package:http/http.dart' as http;

abstract class AbstractAccountRecover {
  Future<flutter_sdk.Transaction> signWithRecoveryServers(
      flutter_sdk.Transaction transaction,
      AccountKeyPair accountAddress,
      Map<RecoveryServerKey, RecoveryServerSigning> serverAuth);

  Future<flutter_sdk.Transaction> replaceDeviceKey(
      AccountKeyPair account,
      AccountKeyPair newKey,
      Map<RecoveryServerKey, RecoveryServerSigning> serverAuth,
      {AccountKeyPair? lostKey,
      AccountKeyPair? sponsorAddress});
}

class AccountRecover extends AbstractAccountRecover {
  StellarConfiguration stellar;
  Map<RecoveryServerKey, RecoveryServer> servers;
  http.Client? httpClient;
  Map<String, String>? httpRequestHeaders;

  AccountRecover(this.stellar, this.servers,
      {this.httpClient, this.httpRequestHeaders});

  /// Replace lost device key with a new key
  /// @account target account
  /// @newKey a key to replace the lost key with
  /// @serverAuth list of servers to use
  /// @lostKey (optional) lost device key. If not specified, try to deduce key from account signers list
  /// @sponsorAddress (optional) sponsor address of the transaction. Please note that not all SEP-30 servers support signing sponsored transactions.
  @override
  Future<flutter_sdk.Transaction> replaceDeviceKey(
      AccountKeyPair account,
      AccountKeyPair newKey,
      Map<RecoveryServerKey, RecoveryServerSigning> serverAuth,
      {AccountKeyPair? lostKey,
      AccountKeyPair? sponsorAddress}) async {
    var sdk = flutter_sdk.StellarSDK(stellar.horizonUrl);
    flutter_sdk.AccountResponse? stellarAccount;
    try {
      stellarAccount = await sdk.accounts.account(account.address);
    } catch (e) {
      if (e is flutter_sdk.ErrorResponse) {
        if (e.code != 404) {
          throw HorizonRequestFailedException(e);
        } else {
          throw ValidationException("Account doesn't exist");
        }
      } else {
        rethrow;
      }
    }

    flutter_sdk.AccountResponse? sponsorAcc;
    if (sponsorAddress != null) {
      try {
        sponsorAcc = await sdk.accounts.account(sponsorAddress.address);
      } catch (e) {
        if (e is flutter_sdk.ErrorResponse) {
          if (e.code != 404) {
            throw HorizonRequestFailedException(e);
          } else {
            throw ValidationException("Sponsor account dose not exist");
          }
        } else {
          rethrow;
        }
      }
    }

    AccountKeyPair? lost;
    int? weight;
    if (lostKey != null) {
      lost = lostKey;
      for (flutter_sdk.Signer signer in stellarAccount.signers) {
        if (signer.key == lostKey.address) {
          weight = signer.weight;
          break;
        }
      }
      if (weight == null) {
        throw ValidationException("Lost key doesn't belong to the account");
      }
    } else {
      flutter_sdk.Signer deduced = _deduceKey(stellarAccount, serverAuth);
      lost = PublicKeyPair(flutter_sdk.KeyPair.fromAccountId(deduced.key));
      weight = deduced.weight;
    }

    flutter_sdk.TransactionBuilder txBuilder =
        flutter_sdk.TransactionBuilder(sponsorAcc ?? stellarAccount);
    if (sponsorAddress != null) {
      flutter_sdk.BeginSponsoringFutureReservesOperationBuilder
          beginSponsoringBuilder =
          flutter_sdk.BeginSponsoringFutureReservesOperationBuilder(
              stellarAccount.accountId);
      beginSponsoringBuilder.setSourceAccount(sponsorAddress.address);
      txBuilder.addOperation(beginSponsoringBuilder.build());
    }
    flutter_sdk.SetOptionsOperationBuilder setOpR =
        flutter_sdk.SetOptionsOperationBuilder();
    setOpR.setSourceAccount(stellarAccount.accountId);
    flutter_sdk.XdrSignerKey sLostKey = flutter_sdk.XdrSignerKey(
        flutter_sdk.XdrSignerKeyType.SIGNER_KEY_TYPE_ED25519);
    sLostKey.ed25519 = flutter_sdk.KeyPair.fromAccountId(lost.address)
        .xdrPublicKey
        .getEd25519();
    setOpR.setSigner(sLostKey, 0); // remove
    txBuilder.addOperation(setOpR.build());

    flutter_sdk.SetOptionsOperationBuilder setOpA =
        flutter_sdk.SetOptionsOperationBuilder();
    setOpA.setSourceAccount(stellarAccount.accountId);
    flutter_sdk.XdrSignerKey sNewKey = flutter_sdk.XdrSignerKey(
        flutter_sdk.XdrSignerKeyType.SIGNER_KEY_TYPE_ED25519);
    sNewKey.ed25519 = flutter_sdk.KeyPair.fromAccountId(newKey.address)
        .xdrPublicKey
        .getEd25519();
    setOpA.setSigner(sNewKey, weight); // add
    txBuilder.addOperation(setOpA.build());

    if (sponsorAddress != null) {
      flutter_sdk.EndSponsoringFutureReservesOperationBuilder
          endSponsorshipBuilder =
          flutter_sdk.EndSponsoringFutureReservesOperationBuilder();
      endSponsorshipBuilder.setSourceAccount(stellarAccount.accountId);
      txBuilder.addOperation(endSponsorshipBuilder.build());
    }

    flutter_sdk.Transaction tx = txBuilder.build();
    return await signWithRecoveryServers(tx, account, serverAuth);
  }

  /// Sign transaction with recovery servers. It is used to recover an account using
  /// [SEP-30](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md).
  /// @transaction Transaction with new signer to be signed by recovery servers
  /// @accountAddress address of the account that is recovered
  /// @serverAuth List of recovery servers to use
  @override
  Future<flutter_sdk.Transaction> signWithRecoveryServers(
      flutter_sdk.Transaction transaction,
      AccountKeyPair accountAddress,
      Map<RecoveryServerKey, RecoveryServerSigning> serverAuth) async {
    List<flutter_sdk.XdrDecoratedSignature> signatures =
        List<flutter_sdk.XdrDecoratedSignature>.empty(growable: true);
    signatures.addAll(transaction.signatures);
    for (var entry in serverAuth.entries) {
      flutter_sdk.XdrDecoratedSignature signature =
          await _getRecoveryServerTxnSignature(
              transaction, accountAddress.address, entry);
      signatures.add(signature);
    }
    transaction.signatures = signatures;
    return transaction;
  }

  Future<flutter_sdk.XdrDecoratedSignature> _getRecoveryServerTxnSignature(
      flutter_sdk.Transaction transaction,
      String accountAddress,
      MapEntry<RecoveryServerKey, RecoveryServerSigning> serverAuth) async {
    if (servers.containsKey(serverAuth.key)) {
      RecoveryServer server = servers[serverAuth.key]!;
      RecoveryServerSigning auth = serverAuth.value;
      flutter_sdk.SEP30RecoveryService service =
          flutter_sdk.SEP30RecoveryService(server.endpoint,
              httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
      flutter_sdk.SEP30SignatureResponse? response;
      try {
        response = await service.signTransaction(
            accountAddress,
            auth.signerAddress,
            transaction.toEnvelopeXdrBase64(),
            auth.authToken);
      } catch (e) {
        if (e is flutter_sdk.SEP30ResponseException) {
          throw RecoveryServerResponseError(e.toString(), cause: e);
        } else {
          rethrow;
        }
      }

      return flutter_sdk.XdrDecoratedSignature(
          flutter_sdk.KeyPair.fromAccountId(auth.signerAddress).signatureHint,
          flutter_sdk.XdrSignature(base64Decode(response.signature)));
    } else {
      throw ValidationException("key not found in servers map");
    }
  }

  /// Try to deduce lost key. If any of these criteria matches, one of signers from the account will
  /// be recognized as a device key:
  /// 1. Only signer that's not in [serverAuth]
  /// 2. All signers in [serverAuth] has the same weight, and potential signer is the only one with a different weight.
  flutter_sdk.Signer _deduceKey(flutter_sdk.AccountResponse stellarAccount,
      Map<RecoveryServerKey, RecoveryServerSigning> serverAuth) {
    List<String> recoverySigners = List<String>.empty(growable: true);
    for (RecoveryServerSigning s in serverAuth.values) {
      recoverySigners.add(s.signerAddress);
    }
    List<flutter_sdk.Signer> nonRecoverySigners =
        List<flutter_sdk.Signer>.empty(growable: true);
    for (flutter_sdk.Signer signer in stellarAccount.signers) {
      if (signer.weight != 0 && !recoverySigners.contains(signer.key)) {
        nonRecoverySigners.add(signer);
      }
    }
    if (nonRecoverySigners.length > 1) {
      Map<int, List<flutter_sdk.Signer>> groupedRecovery = {};
      for (var signer in stellarAccount.signers) {
        if (recoverySigners.contains(signer.key)) {
          if (groupedRecovery.containsKey(signer.weight)) {
            groupedRecovery[signer.weight]!.add(signer);
          } else {
            groupedRecovery[signer.weight] =
                List<flutter_sdk.Signer>.empty(growable: true);
            groupedRecovery[signer.weight]!.add(signer);
          }
        }
      }
      if (groupedRecovery.length == 1) {
        int recoveryWeight = groupedRecovery.entries.first.value.first.weight;
        List<flutter_sdk.Signer> filtered = nonRecoverySigners
            .where((item) => item.weight != recoveryWeight)
            .toList();
        if (filtered.length != 1) {
          throw ValidationException(
              "Couldn't deduce lost key. Please provide lost key explicitly");
        }
        return filtered.first;
      } else {
        throw ValidationException(
            "Couldn't deduce lost key. Please provide lost key explicitly");
      }
    } else {
      if (nonRecoverySigners.isEmpty) {
        throw ValidationException("No device key is setup for this account");
      } else {
        return nonRecoverySigners.first;
      }
    }
  }
}

class Recovery extends AccountRecover {
  Config cfg;

  Recovery(this.cfg, Map<RecoveryServerKey, RecoveryServer> servers,
      {http.Client? httpClient, Map<String, String>? httpRequestHeaders})
      : super(cfg.stellar, servers,
            httpClient: httpClient ?? cfg.app.defaultClient,
            httpRequestHeaders:
                httpRequestHeaders ?? cfg.app.defaultHttpRequestHeaders);

  /// Create new Sep10 object to authenticate account with the recovery server using SEP-10.
  Future<Sep10> sep10Auth(RecoveryServerKey key) async {
    if (servers.containsKey(key)) {
      RecoveryServer server = servers[key]!;
      flutter_sdk.StellarToml? stellarToml;
      try {
        stellarToml = await flutter_sdk.StellarToml.fromDomain(
            server.homeDomain,
            httpClient: httpClient,
            httpRequestHeaders: httpRequestHeaders);
      } catch (e) {
        throw TomlNotFoundException(e.toString());
      }
      if (stellarToml.generalInformation.signingKey == null) {
        throw Sep10AuthNotSupported("Server signing key not found");
      }

      if (stellarToml.generalInformation.webAuthEndpoint == null) {
        throw Sep10AuthNotSupported("Server has no sep 10 web auth endpoint");
      }

      if (stellarToml.generalInformation.webAuthEndpoint !=
          server.authEndpoint) {
        throw Sep10AuthNotSupported(
            "Invalid auth endpoint, not equal to sep 10 web auth endpoint");
      }

      return Sep10(cfg, server.homeDomain, server.authEndpoint,
          stellarToml.generalInformation.signingKey!,
          httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
    } else {
      throw ValidationException("key not found in servers map");
    }
  }

  /// Create new recoverable wallet using [SEP-30](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md).
  /// It registers the account with recovery servers, adds recovery servers and device account as new account signers, and sets threshold weights on the account.
  /// **Warning**: This transaction will lock master key of the account. Make sure you have access to specified [RecoverableWalletConfig.deviceAddress]
  /// This transaction can be sponsored.
  Future<RecoverableWallet> createRecoverableWallet(
      RecoverableWalletConfig config) async {
    if (config.deviceAddress.address == config.accountAddress.address) {
      throw ValidationException(
          "Device key must be different from master (account) key");
    }

    List<String> recoverySigners = await _enrollWithRecoveryServer(
        config.accountAddress, config.accountIdentity);
    List<AccountSigner> signers = List<AccountSigner>.empty(growable: true);
    for (String rs in recoverySigners) {
      var kp = flutter_sdk.KeyPair.fromAccountId(rs);
      AccountSigner as =
          AccountSigner(PublicKeyPair(kp), config.signerWeight.recoveryServer);
      signers.add(as);
    }

    signers
        .add(AccountSigner(config.deviceAddress, config.signerWeight.device));

    flutter_sdk.Transaction tx = await _registerRecoveryServerSigners(
        config.accountAddress,
        signers,
        config.accountThreshold,
        config.sponsorAddress);

    return RecoverableWallet(tx, recoverySigners);
  }

  Future<Map<RecoveryServerKey, RecoverableAccountInfo>> getAccountInfo(
      AccountKeyPair accountAddress,
      Map<RecoveryServerKey, String> auth) async {
    Map<RecoveryServerKey, RecoverableAccountInfo> result = {};
    for (var entry in auth.entries) {
      var key = entry.key;
      var value = entry.value;
      if (servers.containsKey(key)) {
        RecoveryServer server = servers[key]!;

        flutter_sdk.SEP30RecoveryService service =
            flutter_sdk.SEP30RecoveryService(server.endpoint,
                httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);

        flutter_sdk.SEP30AccountResponse? response;
        try {
          response =
              await service.accountDetails(accountAddress.address, value);
        } catch (e) {
          if (e is flutter_sdk.SEP30ResponseException) {
            throw RecoveryServerResponseError(e.toString(), cause: e);
          } else {
            rethrow;
          }
        }
        result[key] = RecoverableAccountInfo.from(response);
      } else {
        throw ValidationException("key not found in servers map");
      }
    }
    return result;
  }

  /// Add recovery servers and device account as new account signers, and set new threshold weights on the account.
  /// This transaction can be sponsored.
  /// @accountSigners A list of account signers and their weights
  /// @accountThreshold Low, medium, and high thresholds to set on the account
  /// @sponsorAddress optional Stellar address of the account sponsoring this transaction
  Future<flutter_sdk.Transaction> _registerRecoveryServerSigners(
      AccountKeyPair account,
      List<AccountSigner> accountSigners,
      AccountThreshold accountThreshold,
      AccountKeyPair? sponsorAddress) async {
    var sdk = flutter_sdk.StellarSDK(cfg.stellar.horizonUrl);
    flutter_sdk.AccountResponse? acc;
    try {
      acc = await sdk.accounts.account(account.address);
    } catch (e) {
      if (e is flutter_sdk.ErrorResponse) {
        if (e.code != 404) {
          throw HorizonRequestFailedException(e);
        }
      } else {
        rethrow;
      }
    }
    bool exists = acc != null;
    if (!exists && sponsorAddress == null) {
      throw ValidationException("Account does not exist and is not sponsored.");
    }
    flutter_sdk.AccountResponse? sponsorAcc;
    if (sponsorAddress != null) {
      try {
        sponsorAcc = await sdk.accounts.account(sponsorAddress.address);
      } catch (e) {
        if (e is flutter_sdk.ErrorResponse) {
          if (e.code != 404) {
            throw HorizonRequestFailedException(e);
          } else {
            throw ValidationException("Sponsor account dose not exist");
          }
        } else {
          rethrow;
        }
      }
    }

    flutter_sdk.AccountResponse source = exists ? acc : sponsorAcc!;
    flutter_sdk.TransactionBuilder txBuilder =
        flutter_sdk.TransactionBuilder(source);
    if (sponsorAcc != null) {
      flutter_sdk.BeginSponsoringFutureReservesOperationBuilder
          beginSponsoringBuilder =
          flutter_sdk.BeginSponsoringFutureReservesOperationBuilder(
              account.address);
      beginSponsoringBuilder.setSourceAccount(sponsorAcc.accountId);
      txBuilder.addOperation(beginSponsoringBuilder.build());
      if (acc == null) {
        flutter_sdk.CreateAccountOperationBuilder createAccountBuilder =
            flutter_sdk.CreateAccountOperationBuilder(account.address, "0");
        txBuilder.addOperation(createAccountBuilder.build());
      }
      txBuilder =
          _register(txBuilder, account, accountSigners, accountThreshold);
      flutter_sdk.EndSponsoringFutureReservesOperationBuilder
          endSponsorshipBuilder =
          flutter_sdk.EndSponsoringFutureReservesOperationBuilder();
      endSponsorshipBuilder.setSourceAccount(account.address);
      txBuilder.addOperation(endSponsorshipBuilder.build());
    } else {
      txBuilder =
          _register(txBuilder, account, accountSigners, accountThreshold);
    }
    return txBuilder.build();
  }

  flutter_sdk.TransactionBuilder _register(
      flutter_sdk.TransactionBuilder txBuilder,
      AccountKeyPair account,
      List<AccountSigner> accountSigners,
      AccountThreshold accountThreshold) {
    flutter_sdk.SetOptionsOperationBuilder setOp =
        flutter_sdk.SetOptionsOperationBuilder();
    setOp.setSourceAccount(account.address);
    setOp.setMasterKeyWeight(0);
    txBuilder.addOperation(setOp.build());
    for (AccountSigner signer in accountSigners) {
      flutter_sdk.XdrSignerKey sKey = flutter_sdk.XdrSignerKey(
          flutter_sdk.XdrSignerKeyType.SIGNER_KEY_TYPE_ED25519);
      sKey.ed25519 = signer.address.keyPair.xdrPublicKey.getEd25519();
      flutter_sdk.SetOptionsOperationBuilder setOpS =
          flutter_sdk.SetOptionsOperationBuilder();
      setOpS.setSourceAccount(account.address);
      setOpS.setSigner(sKey, signer.weight);
      txBuilder.addOperation(setOpS.build());
    }
    flutter_sdk.SetOptionsOperationBuilder setOpT =
        flutter_sdk.SetOptionsOperationBuilder();
    setOpT.setSourceAccount(account.address);
    setOpT.setLowThreshold(accountThreshold.low);
    setOpT.setMediumThreshold(accountThreshold.medium);
    setOpT.setHighThreshold(accountThreshold.high);
    txBuilder.addOperation(setOpT.build());
    return txBuilder;
  }

  Future<List<String>> _enrollWithRecoveryServer(AccountKeyPair account,
      Map<RecoveryServerKey, List<RecoveryAccountIdentity>> identityMap) async {
    List<String> result = List<String>.empty(growable: true);
    for (var entry in servers.entries) {
      var key = entry.key;
      var server = entry.value;
      if (!identityMap.containsKey(key)) {
        throw ValidationException(
            "Account identity for server ${key.name} was not specified");
      }
      List<RecoveryAccountIdentity> accountIdentities = identityMap[key]!;

      Sep10 sep10 = await sep10Auth(key);
      AuthToken authToken = await sep10.authenticate(account,
          clientDomain: server.clientDomain,
          clientDomainSigner: server.walletSigner);
      List<flutter_sdk.SEP30RequestIdentity> identities =
          List<flutter_sdk.SEP30RequestIdentity>.empty(growable: true);
      for (RecoveryAccountIdentity accountIdentity in accountIdentities) {
        identities.add(accountIdentity.toSEP30RequestIdentity());
      }
      flutter_sdk.SEP30Request request = flutter_sdk.SEP30Request(identities);
      flutter_sdk.SEP30RecoveryService service =
          flutter_sdk.SEP30RecoveryService(server.endpoint,
              httpClient: httpClient, httpRequestHeaders: httpRequestHeaders);
      flutter_sdk.SEP30AccountResponse response = await service.registerAccount(
          account.address, request, authToken.jwt);
      if (response.signers.isEmpty) {
        throw NoAccountSignersException();
      }
      result.add(response.signers.first.key);
    }
    return result;
  }
}

/// Configuration for recoverable wallet.
class RecoverableWalletConfig {
  AccountKeyPair accountAddress;
  AccountKeyPair deviceAddress;
  AccountThreshold accountThreshold;
  Map<RecoveryServerKey, List<RecoveryAccountIdentity>> accountIdentity;
  SignerWeight signerWeight;
  AccountKeyPair? sponsorAddress;

  /// Constructor
  /// @accountAddress Stellar address of the account that is registering
  /// @deviceAddress Stellar address of the device that is added as a primary signer. It will
  /// replace the master key of [accountAddress]
  /// @accountThreshold Low, medium, and high thresholds to set on the account
  /// @accountIdentity A list of account identities to be registered with the recovery servers
  /// @signerWeight Signer weight of the device and recovery keys to set
  /// @sponsorAddress optional Stellar address of the account sponsoring this transaction
  RecoverableWalletConfig(this.accountAddress, this.deviceAddress,
      this.accountThreshold, this.accountIdentity, this.signerWeight,
      {this.sponsorAddress});
}

/// Recovery server configuration
class RecoveryServer {
  String endpoint;
  String authEndpoint;
  String homeDomain;
  WalletSigner? walletSigner;
  String? clientDomain;

  /// Constructor
  /// @endpoint main endpoint (root domain) of SEP-30 recovery server. E.g. `https://recovery.example.com` or `https://example.com/recovery`, etc.
  /// @authEndpoint SEP-10 auth endpoint to be used. Should be in format `<https://...>`. E.g. `https://example.com/auth` or `https://auth.example.com` etc. )
  /// @homeDomain is a SEP-10 home domain. E.g. `recovery.example.com` or `example.com`, etc.
  /// @walletSigner optional [WalletSigner] used to sign authentication
  /// @clientDomain optional client domain
  RecoveryServer(this.endpoint, this.authEndpoint, this.homeDomain,
      {this.walletSigner, this.clientDomain});
}

class RecoveryServerSigning {
  String signerAddress;
  String authToken;

  RecoveryServerSigning(this.signerAddress, this.authToken);
}

class RecoveryAccount {
  String address;
  List<RecoveryAccountRole> identities;
  List<RecoveryAccountSigner> signers;

  RecoveryAccount(this.address, this.identities, this.signers);
}

/// A list of identities that if any one is authenticated will be able to gain control of this account.
class RecoveryIdentities {
  List<RecoveryAccountIdentity> identities;

  RecoveryIdentities(this.identities);
}

class RecoveryAccountRole {
  RecoveryRole role;
  bool? authenticated;

  RecoveryAccountRole(this.role, {this.authenticated});
}

class RecoveryAccountSigner {
  String key;

  RecoveryAccountSigner(this.key);
}

class RecoveryType {
  final String _value;
  const RecoveryType._internal(this._value);
  get value => _value;
  static const stellarAddress = RecoveryType._internal("stellar_address");
  static const phoneNumber = RecoveryType._internal("phone_number");
  static const email = RecoveryType._internal("email");

  RecoveryType(this._value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return (other is RecoveryType && other.value == value);
  }

  @override
  int get hashCode => Object.hash(value, value);
}

class RecoveryAccountAuthMethod {
  RecoveryType type;
  String value;

  RecoveryAccountAuthMethod(this.type, this.value);

  flutter_sdk.SEP30AuthMethod toSEP30AuthMethod() {
    return flutter_sdk.SEP30AuthMethod(type.value, value);
  }
}

class RecoveryAccountIdentity {
  RecoveryRole role;
  List<RecoveryAccountAuthMethod> authMethods;

  RecoveryAccountIdentity(this.role, this.authMethods);

  flutter_sdk.SEP30RequestIdentity toSEP30RequestIdentity() {
    List<flutter_sdk.SEP30AuthMethod> auth =
        List<flutter_sdk.SEP30AuthMethod>.empty(growable: true);
    for (RecoveryAccountAuthMethod authMethod in authMethods) {
      auth.add(authMethod.toSEP30AuthMethod());
    }
    return flutter_sdk.SEP30RequestIdentity(role.value, auth);
  }
}

/// The role of the identity. This value is not used by the server and is stored and echoed back in
/// responses as a way for a client to know conceptually who each identity represents
class RecoveryRole {
  final String _value;
  const RecoveryRole._internal(this._value);
  get value => _value;
  static const owner = RecoveryRole._internal("owner");
  static const sender = RecoveryRole._internal("sender");
  static const receiver = RecoveryRole._internal("receiver");

  RecoveryRole(this._value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return (other is RecoveryRole && other.value == value);
  }

  @override
  int get hashCode => Object.hash(value, value);
}

class SignerWeight {
  int device;
  int recoveryServer;

  SignerWeight(this.device, this.recoveryServer);
}

class RecoverableWallet {
  flutter_sdk.Transaction transaction;
  List<String> signers;

  RecoverableWallet(this.transaction, this.signers);
}

class AccountSigner {
  AccountKeyPair address;
  int weight;

  AccountSigner(this.address, this.weight);
}

class RecoverableAccountInfo {
  PublicKeyPair address;
  List<RecoverableIdentity> identities;
  List<RecoverableSigner> signers;

  RecoverableAccountInfo(this.address, this.identities, this.signers);

  static RecoverableAccountInfo from(
      flutter_sdk.SEP30AccountResponse response) {
    PublicKeyPair address =
        PublicKeyPair(flutter_sdk.KeyPair.fromAccountId(response.address));
    List<RecoverableIdentity> identities =
        List<RecoverableIdentity>.empty(growable: true);
    for (var identity in response.identities) {
      identities.add(RecoverableIdentity.from(identity));
    }
    List<RecoverableSigner> signers =
        List<RecoverableSigner>.empty(growable: true);
    for (var signer in response.signers) {
      signers.add(RecoverableSigner.from(signer));
    }
    return RecoverableAccountInfo(address, identities, signers);
  }
}

class RecoverableIdentity {
  RecoveryRole role;
  bool? authenticated;

  RecoverableIdentity(this.role, this.authenticated);

  static RecoverableIdentity from(flutter_sdk.SEP30ResponseIdentity response) {
    return RecoverableIdentity(
        RecoveryRole(response.role), response.authenticated);
  }
}

class RecoverableSigner {
  PublicKeyPair key;
  DateTime? added;

  RecoverableSigner(this.key, {this.added});

  static RecoverableSigner from(flutter_sdk.SEP30ResponseSigner response) {
    return RecoverableSigner(
        PublicKeyPair(flutter_sdk.KeyPair.fromAccountId(response.key)));
  }
}

class RecoveryServerKey {
  String name;

  RecoveryServerKey(this.name);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return (other is RecoveryServerKey && other.name == name);
  }

  @override
  int get hashCode => Object.hash(name, name);
}
