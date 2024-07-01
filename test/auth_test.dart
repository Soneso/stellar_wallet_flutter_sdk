@Timeout(Duration(seconds: 400))
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart'
    as wallet_sdk;

void main() {
  String anchorToml = '''
      # Sample stellar.toml
      VERSION="2.0.0"
      
      NETWORK_PASSPHRASE="Test SDF Network ; September 2015"
      WEB_AUTH_ENDPOINT="https://api.anchor.org/auth"
      SIGNING_KEY="GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
     ''';

  String clientToml = '''
      # Sample stellar.toml
      VERSION="2.0.0"
      
      NETWORK_PASSPHRASE="Test SDF Network ; September 2015"
      SIGNING_KEY="GBMR7A2B6O73HNRMH2LA5VZPVXIGGKFDZDXJXJXWUF5NX2RY73N4IFOA"
     ''';

  const anchorDomain = "place.anchor.com";
  const webAuthEndpoint = "https://api.anchor.org/auth";
  const clientSignerUrl = "https://api.client.org/auth";
  const clientDomain = "api.client.org";
  const int testMemo = 19989123;
  const serverAccountId =
      "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP";
  const serverSecretSeed =
      "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W";
  const userAccountId =
      "GB4L7JUU5DENUXYH3ANTLVYQL66KQLDDJTN5SF7MWEDGWSGUA375V44V";
  const userSecretSeed =
      "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX";
  //const clientAccountId = "GBMR7A2B6O73HNRMH2LA5VZPVXIGGKFDZDXJXJXWUF5NX2RY73N4IFOA";
  const clientSecretSeed =
      "SAWJ3S2JBMPI2F2K6DFAUPCROT3RA46XZXAC5EIJAD7K5C7FCUWEKVSB";
  const wrongServerSecretSeed =
      "SAT4GUGO2N7RVVVD2TSL7TZ6T5A6PM7PJD5NUGQI5DDH67XO4KNO2QOW";
  const String successJWTToken =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0";

  final serverKeyPair = KeyPair.fromSecretSeed(serverSecretSeed);
  final clientKeyPair = KeyPair.fromSecretSeed(clientSecretSeed);

  final Random random = Random.secure();

  Uint8List generateNonce([int length = 64]) {
    var values = List<int>.generate(length, (i) => random.nextInt(256));
    return Uint8List.fromList(base64Url.encode(values).codeUnits);
  }

  TransactionPreconditions validTimeBounds() {
    TransactionPreconditions result = TransactionPreconditions();
    result.timeBounds = TimeBounds(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3);
    return result;
  }

  TransactionPreconditions invalidTimeBounds() {
    TransactionPreconditions result = TransactionPreconditions();
    result.timeBounds = TimeBounds(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - 700,
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - 400);
    return result;
  }

  ManageDataOperation validFirstManageDataOp(String accountId) {
    MuxedAccount muxedAccount = MuxedAccount.fromAccountId(accountId)!;
    final ManageDataOperationBuilder builder =
        ManageDataOperationBuilder("$anchorDomain auth", generateNonce())
            .setMuxedSourceAccount(muxedAccount);
    return builder.build();
  }

  ManageDataOperation invalidClientDomainManageDataOp() {
    final ManageDataOperationBuilder builder = ManageDataOperationBuilder(
            "client_domain", Uint8List.fromList("place.client.com".codeUnits))
        .setSourceAccount(serverAccountId);
    return builder.build();
  }

  ManageDataOperation invalidHomeDomainOp(String accountId) {
    final ManageDataOperationBuilder builder =
        ManageDataOperationBuilder("fake.com" " auth", generateNonce())
            .setSourceAccount(accountId);
    return builder.build();
  }

  ManageDataOperation validSecondManageDataOp() {
    final ManageDataOperationBuilder builder = ManageDataOperationBuilder(
            "web_auth_domain", Uint8List.fromList("api.anchor.org".codeUnits))
        .setSourceAccount(serverAccountId);
    return builder.build();
  }

  ManageDataOperation secondManageDataOpInvalidSourceAccount() {
    final ManageDataOperationBuilder builder = ManageDataOperationBuilder(
            "web_auth_domain", Uint8List.fromList("api.anchor.org".codeUnits))
        .setSourceAccount(userAccountId); // invalid, must be server
    return builder.build();
  }

  ManageDataOperation invalidWebAuthOp() {
    final ManageDataOperationBuilder builder = ManageDataOperationBuilder(
            "web_auth_domain", Uint8List.fromList("api.fake.org".codeUnits))
        .setSourceAccount(serverAccountId);
    return builder.build();
  }

  Memo memoForId(int? id) {
    if (id != null) {
      return MemoId(id);
    }
    return Memo.none();
  }

  String requestChallengeSuccess(String accountId, [int? memo]) {
    final transactionAccount = Account(serverAccountId, -1);
    final Transaction transaction = TransactionBuilder(transactionAccount)
        .addOperation(validFirstManageDataOp(accountId))
        .addOperation(validSecondManageDataOp())
        .addMemo(memoForId(memo))
        .addPreconditions(validTimeBounds())
        .build();
    transaction.sign(serverKeyPair, Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestChallengeInvalidSequenceNumber(String accountId) {
    final transactionAccount = Account(serverAccountId, 2803983);
    final Transaction transaction = TransactionBuilder(transactionAccount)
        .addOperation(validFirstManageDataOp(accountId))
        .addOperation(validSecondManageDataOp())
        .addMemo(Memo.none())
        .addPreconditions(validTimeBounds())
        .build();
    transaction.sign(serverKeyPair, Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestChallengeInvalidFirstOpSourceAccount() {
    final transactionAccount = Account(serverAccountId, -1);
    final Transaction transaction = TransactionBuilder(transactionAccount)
        .addOperation(validFirstManageDataOp(
            serverAccountId)) // invalid because must be client account id
        .addOperation(validSecondManageDataOp())
        .addMemo(Memo.none())
        .addPreconditions(validTimeBounds())
        .build();
    transaction.sign(serverKeyPair, Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestChallengeInvalidSecondOpSourceAccount(String accountId) {
    final transactionAccount = Account(serverAccountId, -1);
    final Transaction transaction = TransactionBuilder(transactionAccount)
        .addOperation(validFirstManageDataOp(accountId))
        .addOperation(secondManageDataOpInvalidSourceAccount())
        .addMemo(Memo.none())
        .addPreconditions(validTimeBounds())
        .build();
    transaction.sign(serverKeyPair, Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestChallengeInvalidClientDomainOpSourceAccount(String accountId) {
    final transactionAccount = Account(serverAccountId, -1);
    final Transaction transaction = TransactionBuilder(transactionAccount)
        .addOperation(validFirstManageDataOp(accountId))
        .addOperation(validSecondManageDataOp())
        .addOperation(invalidClientDomainManageDataOp())
        .addMemo(Memo.none())
        .addPreconditions(validTimeBounds())
        .build();
    transaction.sign(serverKeyPair, Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestChallengeInvalidHomeDomain(String accountId) {
    final transactionAccount = Account(serverAccountId, -1);
    final Transaction transaction = TransactionBuilder(transactionAccount)
        .addOperation(invalidHomeDomainOp(accountId))
        .addOperation(validSecondManageDataOp())
        .addMemo(Memo.none())
        .addPreconditions(validTimeBounds())
        .build();
    transaction.sign(serverKeyPair, Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestChallengeInvalidWebAuth(String accountId) {
    final transactionAccount = Account(serverAccountId, -1);
    final Transaction transaction = TransactionBuilder(transactionAccount)
        .addOperation(validFirstManageDataOp(accountId))
        .addOperation(invalidWebAuthOp())
        .addMemo(Memo.none())
        .addPreconditions(validTimeBounds())
        .build();
    transaction.sign(serverKeyPair, Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestChallengeInvalidTimeBounds(String accountId) {
    final transactionAccount = Account(serverAccountId, -1);
    final Transaction transaction = TransactionBuilder(transactionAccount)
        .addOperation(validFirstManageDataOp(accountId))
        .addOperation(validSecondManageDataOp())
        .addMemo(Memo.none())
        .addPreconditions(invalidTimeBounds())
        .build();
    transaction.sign(serverKeyPair, Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestChallengeInvalidOperationType(String accountId) {
    final transactionAccount = Account(serverAccountId, -1);
    final Transaction transaction = TransactionBuilder(transactionAccount)
        .addOperation(validFirstManageDataOp(accountId))
        .addOperation(validSecondManageDataOp())
        .addOperation(
            PaymentOperationBuilder(serverAccountId, Asset.NATIVE, "100")
                .setSourceAccount(serverAccountId)
                .build()) // not allowed.
        .addMemo(Memo.none())
        .addPreconditions(validTimeBounds())
        .build();
    transaction.sign(serverKeyPair, Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestChallengeInvalidSignature(String accountId) {
    final transactionAccount = Account(serverAccountId, -1);
    final Transaction transaction = TransactionBuilder(transactionAccount)
        .addOperation(validFirstManageDataOp(accountId))
        .addOperation(validSecondManageDataOp())
        .addMemo(Memo.none())
        .addPreconditions(validTimeBounds())
        .build();
    final kp = KeyPair.fromSecretSeed(wrongServerSecretSeed);
    transaction.sign(kp, Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestChallengeMultipleSignature(String accountId) {
    final transactionAccount = Account(serverAccountId, -1);
    final Transaction transaction = TransactionBuilder(transactionAccount)
        .addOperation(validFirstManageDataOp(accountId))
        .addOperation(validSecondManageDataOp())
        .addMemo(Memo.none())
        .addPreconditions(validTimeBounds())
        .build();
    transaction.sign(serverKeyPair, Network.TESTNET);
    final kp = KeyPair.fromSecretSeed(wrongServerSecretSeed);
    transaction.sign(kp, Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestJWTSuccess() {
    final mapJson = {'token': successJWTToken};
    return json.encode(mapJson);
  }

  Future<String> signTransaction(
    String transactionXdr,
    List<KeyPair> signers,
  ) async {
    final envelopeXdr = XdrTransactionEnvelope.fromEnvelopeXdrString(
      transactionXdr,
    );

    KeyPair testAccountKeyPair = KeyPair.random();
    await FriendBot.fundTestAccount(testAccountKeyPair.accountId);

    if (envelopeXdr.discriminant != XdrEnvelopeType.ENVELOPE_TYPE_TX) {
      throw ChallengeValidationError("Invalid transaction type");
    }

    final txHash =
        AbstractTransaction.fromEnvelopeXdr(envelopeXdr).hash(Network.TESTNET);

    final signatures = List<XdrDecoratedSignature>.empty(
      growable: true,
    );
    signatures.addAll(envelopeXdr.v1!.signatures);
    for (KeyPair signer in signers) {
      signatures.add(signer.signDecorated(txHash));
    }
    envelopeXdr.v1!.signatures = signatures;
    return envelopeXdr.toEnvelopeXdrBase64();
  }

  test('test basic success', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(requestChallengeSuccess(userAccountId), 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "POST") {
        // validate if the challenge transaction has been signed by the user
        XdrTransactionEnvelope envelopeXdr =
            XdrTransactionEnvelope.fromEnvelopeXdrString(
                json.decode(request.body)['transaction']);
        final signatures = envelopeXdr.v1!.signatures;
        if (signatures.length == 2) {
          final userSignature = envelopeXdr.v1!.signatures[1];
          final userKeyPair = KeyPair.fromAccountId(userAccountId);
          final transactionHash =
              AbstractTransaction.fromEnvelopeXdr(envelopeXdr)
                  .hash(Network.TESTNET);
          final valid = userKeyPair.verify(
              transactionHash, userSignature.signature.signature);
          if (valid) {
            return http.Response(requestJWTSuccess(), 200); // OK
          }
        }
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      assert(sep10.serverAuthEndpoint == webAuthEndpoint);
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } catch (e) {
      //Logger().e(e);
      fail(e.toString());
    }
  });

  test('test client domain success', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().contains(clientDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(clientToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(requestChallengeSuccess(userAccountId), 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "POST") {
        // validate if the challenge transaction has been signed by the user and the client
        XdrTransactionEnvelope envelopeXdr =
            XdrTransactionEnvelope.fromEnvelopeXdrString(
                json.decode(request.body)['transaction']);
        final signatures = envelopeXdr.v1!.signatures;
        if (signatures.length == 3) {
          final clientSignature = envelopeXdr.v1!.signatures[1];
          final userSignature = envelopeXdr.v1!.signatures[2];
          final userKeyPair = KeyPair.fromAccountId(userAccountId);
          final transactionHash =
              AbstractTransaction.fromEnvelopeXdr(envelopeXdr)
                  .hash(Network.TESTNET);
          final userSigValid = userKeyPair.verify(
              transactionHash, userSignature.signature.signature);
          final clientSigValid = clientKeyPair.verify(
              transactionHash, clientSignature.signature.signature);
          if (userSigValid && clientSigValid) {
            return http.Response(requestJWTSuccess(), 200); // OK
          }
        }
      }
      final mapJson = {'error': 'Bad request'};
      return http.Response(json.encode(mapJson), 400);
    });

    http.Client clientMock = MockClient((request) async {
      if (request.url.toString().startsWith(clientSignerUrl) &&
          request.method == "POST") {
        String requestTx = json.decode(request.body)['transaction'];
        String signedTx = await signTransaction(requestTx, [clientKeyPair]);
        final mapJson = {
          'transaction': signedTx,
          "network_passphrase": Network.TESTNET.networkPassphrase
        };
        return http.Response(json.encode(mapJson), 200);
      }
      final mapJson = {'error': 'Bad request'};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair userAuthKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    wallet_sdk.DomainSigner clientDomainSigner =
        wallet_sdk.DomainSigner(clientSignerUrl, httpClient: clientMock);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      assert(sep10.serverAuthEndpoint == webAuthEndpoint);
      wallet_sdk.AuthToken authToken = await sep10.authenticate(userAuthKey,
          clientDomainSigner: clientDomainSigner, clientDomain: clientDomain);
      assert(authToken.jwt == successJWTToken);
    } catch (e, st) {
      fail(st.toString());
    }
  });

  test('test basic memo success', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeSuccess(userAccountId, testMemo), 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "POST") {
        // validate if the challenge transaction has been signed by the user
        XdrTransactionEnvelope envelopeXdr =
            XdrTransactionEnvelope.fromEnvelopeXdrString(
                json.decode(request.body)['transaction']);
        final signatures = envelopeXdr.v1!.signatures;
        if (signatures.length == 2) {
          final userSignature = envelopeXdr.v1!.signatures[1];
          final userKeyPair = KeyPair.fromAccountId(userAccountId);
          final transactionHash =
              AbstractTransaction.fromEnvelopeXdr(envelopeXdr)
                  .hash(Network.TESTNET);
          final valid = userKeyPair.verify(
              transactionHash, userSignature.signature.signature);
          if (valid) {
            return http.Response(requestJWTSuccess(), 200); // OK
          }
        }
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      assert(sep10.serverAuthEndpoint == webAuthEndpoint);
      wallet_sdk.AuthToken authToken =
          await sep10.authenticate(authKey, memoId: testMemo);
      assert(authToken.jwt == successJWTToken);
    } catch (e) {
      fail(e.toString());
    }
  });

  test('test basic get challenge failure', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeRequestErrorResponse);
      return;
    }
    fail("should not reach");
  });

  test('test basic get challenge invalid sequence number', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeInvalidSequenceNumber(userAccountId), 200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeValidationErrorInvalidSeqNr);
      return;
    }
    fail("should not reach");
  });

  test('test basic get challenge invalid first op source account', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeInvalidFirstOpSourceAccount(), 200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeValidationErrorInvalidSourceAccount);
      return;
    }
    fail("should not reach");
  });

  test('test basic get challenge invalid second op source account', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeInvalidSecondOpSourceAccount(userAccountId), 200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeValidationErrorInvalidSourceAccount);
      return;
    }
    fail("should not reach");
  });

  test('test basic get challenge invalid home domain', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeInvalidHomeDomain(userAccountId), 200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeValidationErrorInvalidHomeDomain);
      return;
    }
    fail("should not reach");
  });

  test('test basic get challenge invalid web auth domain', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeInvalidWebAuth(userAccountId), 200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeValidationErrorInvalidWebAuthDomain);
      return;
    }
    fail("should not reach");
  });

  test('test basic get challenge invalid time bounds', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeInvalidTimeBounds(userAccountId), 200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeValidationErrorInvalidTimeBounds);
      return;
    }
    fail("should not reach");
  });

  test('test basic get challenge invalid operation type', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeInvalidOperationType(userAccountId), 200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeValidationErrorInvalidOperationType);
      return;
    }
    fail("should not reach");
  });

  test('test basic get challenge invalid signature', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeInvalidSignature(userAccountId), 200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeValidationErrorInvalidSignature);
      return;
    }
    fail("should not reach");
  });

  test('test basic get challenge too many signatures', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeMultipleSignature(userAccountId), 200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeValidationErrorInvalidSignature);
      return;
    }
    fail("should not reach");
  });

  test('test basic get challenge too many signatures', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeMultipleSignature(userAccountId), 200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeValidationErrorInvalidSignature);
      return;
    }
    fail("should not reach");
  });

  test('test basic get challenge invalid client domain source account',
      () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(webAuthEndpoint) &&
          request.method == "GET" &&
          request.url.toString().contains(userAccountId)) {
        return http.Response(
            requestChallengeInvalidClientDomainOpSourceAccount(userAccountId),
            200);
      }
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    wallet_sdk.Wallet wallet = wallet_sdk.Wallet.testNet;
    wallet_sdk.Anchor anchor =
        wallet.anchor(anchorDomain, httpClient: anchorMock);
    wallet_sdk.SigningKeyPair authKey =
        wallet_sdk.SigningKeyPair.fromSecret(userSecretSeed);
    try {
      wallet_sdk.Sep10 sep10 = await anchor.sep10();
      wallet_sdk.AuthToken authToken = await sep10.authenticate(authKey);
      assert(authToken.jwt == successJWTToken);
    } on wallet_sdk.AnchorAuthException catch (e) {
      assert(e.cause != null);
      assert(e.cause is ChallengeValidationErrorInvalidSourceAccount);
      return;
    }
    fail("should not reach");
  });
}
