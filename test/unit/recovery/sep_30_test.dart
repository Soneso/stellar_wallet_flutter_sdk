// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  group('RecoveryAccountAuthMethod Tests', () {
    test('toSEP30AuthMethod maps type value and value verbatim', () {
      final method =
          RecoveryAccountAuthMethod(RecoveryType.email, "user@example.com");

      final sep30 = method.toSEP30AuthMethod();

      expect(sep30, isA<flutter_sdk.SEP30AuthMethod>());
      expect(sep30.type, "email");
      expect(sep30.value, "user@example.com");
    });

    test('toSEP30AuthMethod uses the RecoveryType.value, not the enum object',
        () {
      final method = RecoveryAccountAuthMethod(
          RecoveryType.stellarAddress,
          "GA6UIXXPEWYFILNUIWAC37Y4QPEZMQVDJHDKVWFZJ2KCWUBIU5IXZNDA");

      final sep30 = method.toSEP30AuthMethod();

      expect(sep30.type, "stellar_address");
      expect(sep30.value,
          "GA6UIXXPEWYFILNUIWAC37Y4QPEZMQVDJHDKVWFZJ2KCWUBIU5IXZNDA");
    });

    test('toSEP30AuthMethod supports phone_number type', () {
      final method =
          RecoveryAccountAuthMethod(RecoveryType.phoneNumber, "+10000000000");

      final sep30 = method.toSEP30AuthMethod();

      expect(sep30.type, "phone_number");
      expect(sep30.value, "+10000000000");
    });

    test('toSEP30AuthMethod supports a custom RecoveryType value', () {
      final method =
          RecoveryAccountAuthMethod(RecoveryType("custom_type"), "some-value");

      final sep30 = method.toSEP30AuthMethod();

      expect(sep30.type, "custom_type");
      expect(sep30.value, "some-value");
    });
  });

  group('RecoveryAccountIdentity Tests', () {
    test('toSEP30RequestIdentity maps role value and converts auth methods', () {
      final identity = RecoveryAccountIdentity(RecoveryRole.owner, [
        RecoveryAccountAuthMethod(RecoveryType.email, "owner@example.com"),
        RecoveryAccountAuthMethod(RecoveryType.phoneNumber, "+10000000000"),
      ]);

      final request = identity.toSEP30RequestIdentity();

      expect(request, isA<flutter_sdk.SEP30RequestIdentity>());
      expect(request.role, "owner");
      expect(request.authMethods.length, 2);
      expect(request.authMethods[0].type, "email");
      expect(request.authMethods[0].value, "owner@example.com");
      expect(request.authMethods[1].type, "phone_number");
      expect(request.authMethods[1].value, "+10000000000");
    });

    test('toSEP30RequestIdentity preserves auth method order', () {
      final identity = RecoveryAccountIdentity(RecoveryRole.sender, [
        RecoveryAccountAuthMethod(RecoveryType.phoneNumber, "+1"),
        RecoveryAccountAuthMethod(RecoveryType.email, "a@b.c"),
        RecoveryAccountAuthMethod(RecoveryType.stellarAddress, "addr*b.c"),
      ]);

      final request = identity.toSEP30RequestIdentity();

      expect(request.role, "sender");
      expect(request.authMethods.map((m) => m.type).toList(),
          ["phone_number", "email", "stellar_address"]);
      expect(request.authMethods.map((m) => m.value).toList(),
          ["+1", "a@b.c", "addr*b.c"]);
    });

    test('toSEP30RequestIdentity with empty auth methods yields empty list', () {
      final identity = RecoveryAccountIdentity(RecoveryRole.receiver, []);

      final request = identity.toSEP30RequestIdentity();

      expect(request.role, "receiver");
      expect(request.authMethods, isEmpty);
    });

    test('toSEP30RequestIdentity uses RecoveryRole.value for the role', () {
      final identity = RecoveryAccountIdentity(RecoveryRole("custom_role"), []);

      final request = identity.toSEP30RequestIdentity();

      expect(request.role, "custom_role");
    });
  });

  group('RecoverableSigner Tests', () {
    test('from maps the signer key to a PublicKeyPair with the same address',
        () {
      final kp = flutter_sdk.KeyPair.random();
      final response = flutter_sdk.SEP30ResponseSigner(kp.accountId);

      final signer = RecoverableSigner.from(response);

      expect(signer.key, isA<PublicKeyPair>());
      expect(signer.key.address, kp.accountId);
    });

    test('from leaves added null because the base SDK signer has no added field',
        () {
      // The base SDK SEP30ResponseSigner exposes only `key` (no `added`),
      // so RecoverableSigner.added is correctly null after conversion.
      final kp = flutter_sdk.KeyPair.random();
      final response = flutter_sdk.SEP30ResponseSigner(kp.accountId);

      final signer = RecoverableSigner.from(response);

      expect(signer.added, isNull);
    });
  });

  group('RecoverableIdentity Tests', () {
    test('from maps a present role string to a matching RecoveryRole', () {
      final response =
          flutter_sdk.SEP30ResponseIdentity("owner", authenticated: true);

      final identity = RecoverableIdentity.from(response);

      expect(identity.role, isNotNull);
      expect(identity.role, RecoveryRole.owner);
      expect(identity.role!.value, "owner");
      expect(identity.authenticated, isTrue);
    });

    test('from maps a null role to a null RecoveryRole', () {
      final response =
          flutter_sdk.SEP30ResponseIdentity(null, authenticated: false);

      final identity = RecoverableIdentity.from(response);

      expect(identity.role, isNull);
      expect(identity.authenticated, isFalse);
    });

    test('from preserves a null authenticated flag', () {
      final response = flutter_sdk.SEP30ResponseIdentity("sender");

      final identity = RecoverableIdentity.from(response);

      expect(identity.role, RecoveryRole.sender);
      expect(identity.authenticated, isNull);
    });

    test('from wraps an arbitrary role string into RecoveryRole', () {
      final response =
          flutter_sdk.SEP30ResponseIdentity("other", authenticated: true);

      final identity = RecoverableIdentity.from(response);

      expect(identity.role, isNotNull);
      expect(identity.role!.value, "other");
      expect(identity.authenticated, isTrue);
    });
  });

  group('RecoverableAccountInfo Tests', () {
    test('from maps address, identities and signers from the response', () {
      final accountKp = flutter_sdk.KeyPair.random();
      final signer1Kp = flutter_sdk.KeyPair.random();
      final signer2Kp = flutter_sdk.KeyPair.random();

      final response = flutter_sdk.SEP30AccountResponse(
        accountKp.accountId,
        [
          flutter_sdk.SEP30ResponseIdentity("owner", authenticated: true),
          flutter_sdk.SEP30ResponseIdentity("sender", authenticated: false),
        ],
        [
          flutter_sdk.SEP30ResponseSigner(signer1Kp.accountId),
          flutter_sdk.SEP30ResponseSigner(signer2Kp.accountId),
        ],
      );

      final info = RecoverableAccountInfo.from(response);

      expect(info.address, isA<PublicKeyPair>());
      expect(info.address.address, accountKp.accountId);

      expect(info.identities.length, 2);
      expect(info.identities[0].role, RecoveryRole.owner);
      expect(info.identities[0].authenticated, isTrue);
      expect(info.identities[1].role, RecoveryRole.sender);
      expect(info.identities[1].authenticated, isFalse);

      expect(info.signers.length, 2);
      expect(info.signers[0].key.address, signer1Kp.accountId);
      expect(info.signers[1].key.address, signer2Kp.accountId);
      expect(info.signers[0].added, isNull);
      expect(info.signers[1].added, isNull);
    });

    test('from handles empty identities and signers', () {
      final accountKp = flutter_sdk.KeyPair.random();

      final response = flutter_sdk.SEP30AccountResponse(
        accountKp.accountId,
        [],
        [],
      );

      final info = RecoverableAccountInfo.from(response);

      expect(info.address.address, accountKp.accountId);
      expect(info.identities, isEmpty);
      expect(info.signers, isEmpty);
    });

    test('from maps a null identity role to null', () {
      final accountKp = flutter_sdk.KeyPair.random();
      final signerKp = flutter_sdk.KeyPair.random();

      final response = flutter_sdk.SEP30AccountResponse(
        accountKp.accountId,
        [flutter_sdk.SEP30ResponseIdentity(null)],
        [flutter_sdk.SEP30ResponseSigner(signerKp.accountId)],
      );

      final info = RecoverableAccountInfo.from(response);

      expect(info.identities.length, 1);
      expect(info.identities.first.role, isNull);
      expect(info.identities.first.authenticated, isNull);
      expect(info.signers.single.key.address, signerKp.accountId);
    });
  });

  group('RecoveryType Tests', () {
    test('predefined constants expose their wire values', () {
      expect(RecoveryType.stellarAddress.value, "stellar_address");
      expect(RecoveryType.phoneNumber.value, "phone_number");
      expect(RecoveryType.email.value, "email");
    });

    test('equality is based on value', () {
      expect(RecoveryType("email"), RecoveryType.email);
      expect(RecoveryType("stellar_address"), RecoveryType.stellarAddress);
      expect(RecoveryType("phone_number"), RecoveryType.phoneNumber);
    });

    test('instances with different values are not equal', () {
      expect(RecoveryType.email == RecoveryType.phoneNumber, isFalse);
      expect(RecoveryType("a") == RecoveryType("b"), isFalse);
    });

    test('identical instance equals itself', () {
      const t = RecoveryType.email;
      expect(t == t, isTrue);
    });

    test('hashCode is consistent with equality', () {
      expect(RecoveryType("email").hashCode, RecoveryType.email.hashCode);
      expect(RecoveryType("phone_number").hashCode,
          RecoveryType.phoneNumber.hashCode);
    });

    test('is not equal to objects of other types', () {
      final Object other = "email";
      expect(RecoveryType.email == other, isFalse);
    });
  });

  group('RecoveryRole Tests', () {
    test('predefined constants expose their wire values', () {
      expect(RecoveryRole.owner.value, "owner");
      expect(RecoveryRole.sender.value, "sender");
      expect(RecoveryRole.receiver.value, "receiver");
    });

    test('equality is based on value', () {
      expect(RecoveryRole("owner"), RecoveryRole.owner);
      expect(RecoveryRole("sender"), RecoveryRole.sender);
      expect(RecoveryRole("receiver"), RecoveryRole.receiver);
    });

    test('instances with different values are not equal', () {
      expect(RecoveryRole.owner == RecoveryRole.sender, isFalse);
      expect(RecoveryRole("x") == RecoveryRole("y"), isFalse);
    });

    test('identical instance equals itself', () {
      const r = RecoveryRole.owner;
      expect(r == r, isTrue);
    });

    test('hashCode is consistent with equality', () {
      expect(RecoveryRole("owner").hashCode, RecoveryRole.owner.hashCode);
      expect(RecoveryRole("receiver").hashCode, RecoveryRole.receiver.hashCode);
    });

    test('is not equal to objects of other types', () {
      final Object other = "owner";
      expect(RecoveryRole.owner == other, isFalse);
    });

    test('a role wrapping an arbitrary string keeps that value', () {
      final role = RecoveryRole("other");
      expect(role.value, "other");
      expect(role == RecoveryRole("other"), isTrue);
    });
  });

  group('RecoveryServerKey Tests', () {
    test('equality is based on name', () {
      expect(RecoveryServerKey("first"), RecoveryServerKey("first"));
      expect(RecoveryServerKey("a") == RecoveryServerKey("b"), isFalse);
    });

    test('identical instance equals itself', () {
      final key = RecoveryServerKey("first");
      expect(key == key, isTrue);
    });

    test('hashCode is consistent with equality', () {
      expect(RecoveryServerKey("first").hashCode,
          RecoveryServerKey("first").hashCode);
    });

    test('is not equal to objects of other types', () {
      final Object other = "first";
      expect(RecoveryServerKey("first") == other, isFalse);
    });

    test('works as a Map key by name equality', () {
      final map = <RecoveryServerKey, String>{};
      map[RecoveryServerKey("first")] = "one";
      map[RecoveryServerKey("second")] = "two";

      // A distinct instance with the same name must resolve to the same entry.
      expect(map[RecoveryServerKey("first")], "one");
      expect(map[RecoveryServerKey("second")], "two");
      expect(map.length, 2);

      // Re-inserting with an equal key overwrites rather than adding.
      map[RecoveryServerKey("first")] = "one-updated";
      expect(map.length, 2);
      expect(map[RecoveryServerKey("first")], "one-updated");
    });

    test('containsKey resolves by name equality', () {
      final map = <RecoveryServerKey, int>{RecoveryServerKey("server"): 1};
      expect(map.containsKey(RecoveryServerKey("server")), isTrue);
      expect(map.containsKey(RecoveryServerKey("missing")), isFalse);
    });
  });

  group('createRecoverableWallet Tests', () {
    late Recovery recovery;
    late AccountKeyPair sharedKey;

    setUp(() {
      final wallet = Wallet.testNet;
      final servers = <RecoveryServerKey, RecoveryServer>{
        RecoveryServerKey("first"): RecoveryServer(
            "https://recovery.example.com",
            "https://auth.example.com",
            "recovery.example.com"),
      };
      recovery = wallet.recovery(servers);
      sharedKey =
          PublicKeyPair(flutter_sdk.KeyPair.fromAccountId(
              flutter_sdk.KeyPair.random().accountId));
    });

    test(
        'throws ValidationException when device key equals account key (pre-network guard)',
        () async {
      final config = RecoverableWalletConfig(
        sharedKey,
        sharedKey,
        AccountThreshold(10, 10, 10),
        <RecoveryServerKey, List<RecoveryAccountIdentity>>{},
        SignerWeight(10, 5),
      );

      expect(
        () => recovery.createRecoverableWallet(config),
        throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            "Device key must be different from master (account) key")),
      );
    });

    test(
        'guard compares by address so distinct PublicKeyPair instances with the same address still throw',
        () async {
      final accountId = flutter_sdk.KeyPair.random().accountId;
      final account =
          PublicKeyPair(flutter_sdk.KeyPair.fromAccountId(accountId));
      final device =
          PublicKeyPair(flutter_sdk.KeyPair.fromAccountId(accountId));

      final config = RecoverableWalletConfig(
        account,
        device,
        AccountThreshold(10, 10, 10),
        <RecoveryServerKey, List<RecoveryAccountIdentity>>{},
        SignerWeight(10, 5),
      );

      expect(
        () => recovery.createRecoverableWallet(config),
        throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            "Device key must be different from master (account) key")),
      );
    });
  });
}
