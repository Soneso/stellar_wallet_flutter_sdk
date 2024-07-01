@Timeout(Duration(seconds: 400))

import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;

import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  flutter_sdk.KeyPair server1KeyPair = flutter_sdk.KeyPair.random();
  String server1WebAuthDomain = "auth.example1.com";
  String server1WebAuthEndpoint = "https://$server1WebAuthDomain";
  String server1HomeDomain = "recovery.example1.com";
  String server1RecoveryEndpoint = "https:://$server1HomeDomain";

  String server1Toml = '''
      # Sample stellar.toml
      VERSION="2.0.0"
      
      NETWORK_PASSPHRASE="Test SDF Network ; September 2015"
      WEB_AUTH_ENDPOINT="$server1WebAuthEndpoint"
      SIGNING_KEY="${server1KeyPair.accountId}"
     ''';

  flutter_sdk.KeyPair server2KeyPair = flutter_sdk.KeyPair.random();
  String server2WebAuthDomain = "auth.example2.com";
  String server2WebAuthEndpoint = "https://$server2WebAuthDomain";
  String server2HomeDomain = "recovery.example2.com";
  String server2RecoveryEndpoint = "https:://$server2HomeDomain";

  String server2Toml = '''
      # Sample stellar.toml
      VERSION="2.0.0"
      
      NETWORK_PASSPHRASE="Test SDF Network ; September 2015"
      WEB_AUTH_ENDPOINT="$server2WebAuthEndpoint"
      SIGNING_KEY="${server2KeyPair.accountId}"
     ''';

  const String successJWTToken =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0";

  const String emailAuthToken = "super secure email login token";

  final Random random = Random.secure();
  Wallet wallet = Wallet.testNet;
  var accountKp = wallet.stellar().account().createKeyPair();
  var deviceKp = wallet.stellar().account().createKeyPair();
  var recoveryKp = wallet.stellar().account().createKeyPair();
  var sponsoredAccountKp = wallet.stellar().account().createKeyPair();
  var sponsorKp = wallet.stellar().account().createKeyPair();
  var sponsoredExistingAccountKp = wallet.stellar().account().createKeyPair();
  var account2Kp = wallet.stellar().account().createKeyPair();
  var newKey1 = wallet.stellar().account().createKeyPair();
  var newKey2 = wallet.stellar().account().createKeyPair();
  var newKey3 = wallet.stellar().account().createKeyPair();
  var sponsor2Kp = wallet.stellar().account().createKeyPair();
  var sponsoredAccount2Kp = wallet.stellar().account().createKeyPair();

  var identity1 = [
    RecoveryAccountIdentity(RecoveryRole.owner, [
      RecoveryAccountAuthMethod(RecoveryType.stellarAddress, recoveryKp.address)
    ])
  ];
  var identity2 = [
    RecoveryAccountIdentity(RecoveryRole.owner,
        [RecoveryAccountAuthMethod(RecoveryType.email, "my-email@example.com")])
  ];

  var first = RecoveryServerKey("first");
  var second = RecoveryServerKey("second");
  var firstServer = RecoveryServer(
      server1RecoveryEndpoint, server1WebAuthEndpoint, server1HomeDomain);
  var secondServer = RecoveryServer(
      server2RecoveryEndpoint, server2WebAuthEndpoint, server2HomeDomain);

  Map<RecoveryServerKey, RecoveryServer> servers = {
    first: firstServer,
    second: secondServer
  };

  // SEP 10 Mock logic
  Uint8List generateNonce([int length = 64]) {
    var values = List<int>.generate(length, (i) => random.nextInt(256));
    return Uint8List.fromList(base64Url.encode(values).codeUnits);
  }

  flutter_sdk.ManageDataOperation validFirstManageDataOp(
      String accountId, String anchorDomain) {
    flutter_sdk.MuxedAccount muxedAccount =
        flutter_sdk.MuxedAccount.fromAccountId(accountId)!;
    final flutter_sdk.ManageDataOperationBuilder builder =
        flutter_sdk.ManageDataOperationBuilder(
                "$anchorDomain auth", generateNonce())
            .setMuxedSourceAccount(muxedAccount);
    return builder.build();
  }

  flutter_sdk.ManageDataOperation validSecondManageDataOp(
      String serverAccountId, String webAuthDomain) {
    final flutter_sdk.ManageDataOperationBuilder builder =
        flutter_sdk.ManageDataOperationBuilder(
                "web_auth_domain", Uint8List.fromList(webAuthDomain.codeUnits))
            .setSourceAccount(serverAccountId);
    return builder.build();
  }

  flutter_sdk.TransactionPreconditions validTimeBounds() {
    flutter_sdk.TransactionPreconditions result =
        flutter_sdk.TransactionPreconditions();
    result.timeBounds = flutter_sdk.TimeBounds(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300);
    return result;
  }

  String requestChallengeSuccess(
      String accountId,
      flutter_sdk.KeyPair serverKeyPair,
      String anchorDomain,
      String webAuthDomain) {
    final transactionAccount = flutter_sdk.Account(serverKeyPair.accountId, -1);
    final flutter_sdk.Transaction transaction =
        flutter_sdk.TransactionBuilder(transactionAccount)
            .addOperation(validFirstManageDataOp(accountId, anchorDomain))
            .addOperation(
                validSecondManageDataOp(serverKeyPair.accountId, webAuthDomain))
            .addMemo(flutter_sdk.Memo.none())
            .addPreconditions(validTimeBounds())
            .build();
    transaction.sign(serverKeyPair, flutter_sdk.Network.TESTNET);
    final mapJson = {'transaction': transaction.toEnvelopeXdrBase64()};
    return json.encode(mapJson);
  }

  String requestJWTSuccess() {
    final mapJson = {'token': successJWTToken};
    return json.encode(mapJson);
  }

  String requestRegisterSuccess(String accountId, String signerKey) {
    return "{  \"address\": \"$accountId\",  \"identities\": [    { \"role\": \"owner\" } ],  \"signers\": [    { \"key\": \"$signerKey\" }  ]}";
  }

  String requestDetailsSuccess(String accountId, String signerKey) {
    return "{  \"address\": \"$accountId\",  \"identities\": [    { \"role\": \"owner\", \"authenticated\": true } ],  \"signers\": [    { \"key\": \"$signerKey\" }  ]}";
  }

  String requestSignSuccess(String signature) {
    return "{  \"signature\": \"$signature\",  \"network_passphrase\": \"Test SDF Network ; September 2015\"}";
  }

  http.Response? handleSep10Request(
      AccountKeyPair accountKp, http.Request request) {
    if (request.url.toString().contains("stellar.toml")) {
      if (request.url.toString().contains(server1HomeDomain)) {
        return http.Response(server1Toml, 200);
      }
      if (request.url.toString().contains(server2HomeDomain)) {
        return http.Response(server2Toml, 200);
      }
    }

    if (request.url.toString().startsWith(server1WebAuthEndpoint) &&
        request.method == "GET" &&
        request.url.toString().contains(accountKp.address)) {
      return http.Response(
          requestChallengeSuccess(accountKp.address, server1KeyPair,
              server1HomeDomain, server1WebAuthDomain),
          200);
    }

    if (request.url.toString().startsWith(server2WebAuthEndpoint) &&
        request.method == "GET" &&
        request.url.toString().contains(accountKp.address)) {
      return http.Response(
          requestChallengeSuccess(accountKp.address, server2KeyPair,
              server2HomeDomain, server2WebAuthDomain),
          200);
    }

    if ((request.url.toString().startsWith(server1WebAuthEndpoint) ||
            request.url.toString().startsWith(server2WebAuthEndpoint)) &&
        request.method == "POST") {
      // validate if the challenge transaction has been signed by the user
      flutter_sdk.XdrTransactionEnvelope envelopeXdr =
          flutter_sdk.XdrTransactionEnvelope.fromEnvelopeXdrString(
              json.decode(request.body)['transaction']);
      final signatures = envelopeXdr.v1!.signatures;
      if (signatures.length == 2) {
        final userSignature = envelopeXdr.v1!.signatures[1];
        final userKeyPair =
            flutter_sdk.KeyPair.fromAccountId(accountKp.address);
        final transactionHash =
            flutter_sdk.AbstractTransaction.fromEnvelopeXdr(envelopeXdr)
                .hash(flutter_sdk.Network.TESTNET);
        final valid = userKeyPair.verify(
            transactionHash, userSignature.signature.signature);
        if (valid) {
          return http.Response(requestJWTSuccess(), 200); // OK
        }
      }
    }
    return null;
  }

  http.Response? handleRegisterRequest(AccountKeyPair accountKp,
      AccountKeyPair recoveryKp, http.Request request) {
    String authHeader = request.headers["Authorization"]!;
    if ((request.url.toString().startsWith(server1RecoveryEndpoint) ||
            request.url.toString().startsWith(server2RecoveryEndpoint)) &&
        request.method == "POST" &&
        request.url.toString().contains("accounts") &&
        request.url.toString().contains(accountKp.address) &&
        authHeader.contains(successJWTToken)) {
      var identities = json.decode(request.body)["identities"];
      assert(1 == identities.length);
      var authMethods =
          json.decode(request.body)["identities"][0]["auth_methods"];
      assert(1 == authMethods.length);

      String signingKey = server1KeyPair.accountId;
      if (request.url.toString().startsWith(server1RecoveryEndpoint)) {
        var type = authMethods[0]["type"];
        assert("stellar_address" == type);
        var value = authMethods[0]["value"];
        assert(recoveryKp.address == value);
      }
      if (request.url.toString().startsWith(server2RecoveryEndpoint)) {
        signingKey = server2KeyPair.accountId;
        var type = authMethods[0]["type"];
        assert("email" == type);
        var value = authMethods[0]["value"];
        assert(value.contains("@"));
      }
      return http.Response(
          requestRegisterSuccess(accountKp.address, signingKey), 200); // OK
    }
    return null;
  }

  http.Response? handleInfoRequest(
      AccountKeyPair accountKp, http.Request request) {
    String authHeader = request.headers["Authorization"]!;
    if ((request.url.toString().startsWith(server1RecoveryEndpoint) ||
            request.url.toString().startsWith(server2RecoveryEndpoint)) &&
        request.method == "GET" &&
        request.url.toString().contains("accounts") &&
        request.url.toString().contains(accountKp.address) &&
        (authHeader.contains(successJWTToken) ||
            authHeader.contains(emailAuthToken))) {
      String signingKey = server1KeyPair.accountId;
      if (request.url.toString().startsWith(server2RecoveryEndpoint)) {
        signingKey = server2KeyPair.accountId;
        assert(authHeader.contains(emailAuthToken));
      }
      return http.Response(
          requestDetailsSuccess(accountKp.address, signingKey), 200); // OK
    }
    return null;
  }

  http.Response? handleSigningRequest(
      AccountKeyPair accKp, http.Request request,
      {String? sponsor}) {
    String authHeader = request.headers["Authorization"]!;
    if ((request.url.toString().startsWith(server1RecoveryEndpoint) ||
            request.url.toString().startsWith(server2RecoveryEndpoint)) &&
        request.method == "POST" &&
        request.url.toString().contains("accounts") &&
        request.url.toString().contains("sign") &&
        request.url.toString().contains(accKp.address) &&
        (authHeader.contains(successJWTToken) ||
            authHeader.contains(emailAuthToken))) {
      var tx = json.decode(request.body)["transaction"];
      flutter_sdk.AbstractTransaction transaction =
          flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(tx);
      assert(transaction is flutter_sdk.Transaction);
      if (transaction is flutter_sdk.Transaction) {
        if (sponsor != null) {
          assert(transaction.sourceAccount.accountId == sponsor);
        } else {
          assert(transaction.sourceAccount.accountId == accKp.address);
        }

        if (request.url.toString().startsWith(server1RecoveryEndpoint)) {
          transaction.sign(server1KeyPair, flutter_sdk.Network.TESTNET);
        } else {
          transaction.sign(server2KeyPair, flutter_sdk.Network.TESTNET);
        }
        var signature = base64Encode(
            transaction.signatures.last.signature.signature.toList());
        return http.Response(requestSignSuccess(signature), 200); // OK
      }
    }
    return null;
  }

  Future<void> validateSigners(
      String accountAddress, String deviceSigner, List<String> recoverySigners,
      {String? notSigner}) async {
    var account = await wallet.stellar().account().getInfo(accountAddress);
    var signers = account.signers;
    bool deviceSignerFound = false;
    bool notSignerFound = false;
    int foundRecoverySigners = 0;
    for (var signer in signers) {
      if (signer.accountId == accountAddress) {
        assert(signer.weight == 0);
      }
      if (signer.accountId == deviceSigner) {
        assert(signer.weight == 10);
        deviceSignerFound = true;
      }
      if (notSigner != null) {
        if (signer.accountId == notSigner && signer.weight != 0) {
          notSignerFound = true;
        }
      }
      for (var recoverySigner in recoverySigners) {
        if (signer.accountId == recoverySigner) {
          assert(signer.weight == 5);
          foundRecoverySigners++;
        }
      }
    }
    assert(deviceSignerFound);
    assert(foundRecoverySigners == 2);
    assert(!notSignerFound);
  }

  http.Client registrationMock(AccountKeyPair accKeyPair) {
    return MockClient((request) async {
      var sep10Response = handleSep10Request(accKeyPair, request);
      if (sep10Response != null) {
        return sep10Response;
      }

      var registerResponse =
          handleRegisterRequest(accKeyPair, recoveryKp, request);
      if (registerResponse != null) {
        return registerResponse;
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });
  }

  http.Client accountInfoMock(AccountKeyPair recKp, AccountKeyPair accKp) {
    return MockClient((request) async {
      var sep10Response = handleSep10Request(recKp, request);
      if (sep10Response != null) {
        return sep10Response;
      }

      var infoResponse = handleInfoRequest(accKp, request);
      if (infoResponse != null) {
        return infoResponse;
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });
  }

  http.Client recoverWalletMock(AccountKeyPair recKp, AccountKeyPair accKp,
      {String? sponsor}) {
    return MockClient((request) async {
      var sep10Response = handleSep10Request(recKp, request);
      if (sep10Response != null) {
        return sep10Response;
      }

      var signingResponse =
          handleSigningRequest(accKp, request, sponsor: sponsor);
      if (signingResponse != null) {
        return signingResponse;
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });
  }

  Future<RecoverableWallet> createRecoverableWallet(AccountKeyPair accKp,
      {AccountKeyPair? sponsor}) async {
    Recovery recovery =
        wallet.recovery(servers, httpClient: registrationMock(accKp));

    return await recovery.createRecoverableWallet(RecoverableWalletConfig(
        accKp,
        deviceKp,
        AccountThreshold(10, 10, 10),
        {first: identity1, second: identity2},
        SignerWeight(10, 5),
        sponsorAddress: sponsor));
  }

  test('test register', () async {
    await flutter_sdk.FriendBot.fundTestAccount(accountKp.address);
    var recoverableWallet = await createRecoverableWallet(accountKp);
    assert(recoverableWallet.signers.isNotEmpty);
    var transaction = recoverableWallet.transaction;
    transaction.sign(accountKp.keyPair, flutter_sdk.Network.TESTNET);
    assert(await wallet.stellar().submitTransaction(transaction));
    await validateSigners(
        accountKp.address, deviceKp.address, recoverableWallet.signers);
  });

  test('test register with sponsor and not existing account', () async {
    await flutter_sdk.FriendBot.fundTestAccount(sponsorKp.address);
    var recoverableWallet =
        await createRecoverableWallet(sponsoredAccountKp, sponsor: sponsorKp);
    assert(recoverableWallet.signers.isNotEmpty);
    var transaction = recoverableWallet.transaction;
    transaction.sign(sponsoredAccountKp.keyPair, flutter_sdk.Network.TESTNET);
    transaction.sign(sponsorKp.keyPair, flutter_sdk.Network.TESTNET);
    assert(await wallet.stellar().submitTransaction(transaction));
    await validateSigners(sponsoredAccountKp.address, deviceKp.address,
        recoverableWallet.signers);
  });

  test('test register with sponsor and existing account', () async {
    await flutter_sdk.FriendBot.fundTestAccount(sponsorKp.address);
    await flutter_sdk.FriendBot.fundTestAccount(
        sponsoredExistingAccountKp.address);

    var recoverableWallet = await createRecoverableWallet(
        sponsoredExistingAccountKp,
        sponsor: sponsorKp);
    assert(recoverableWallet.signers.isNotEmpty);
    var transaction = recoverableWallet.transaction;
    transaction.sign(
        sponsoredExistingAccountKp.keyPair, flutter_sdk.Network.TESTNET);
    transaction.sign(sponsorKp.keyPair, flutter_sdk.Network.TESTNET);
    assert(await wallet.stellar().submitTransaction(transaction));
    await validateSigners(sponsoredExistingAccountKp.address, deviceKp.address,
        recoverableWallet.signers);
  });

  test('test get account info', () async {
    Recovery recovery = wallet.recovery(servers,
        httpClient: accountInfoMock(recoveryKp, accountKp));
    var sep10S1 = await recovery.sep10Auth(first);
    var authToken1 = await sep10S1.authenticate(recoveryKp);
    assert(authToken1.jwt == successJWTToken);
    var response = await recovery.getAccountInfo(
        accountKp, {first: authToken1.jwt, second: emailAuthToken});

    assert(response.isNotEmpty);
    var accountInfoS1 = response[first];
    var accountInfoS2 = response[second];
    assert(accountInfoS1?.address.address == accountKp.address);
    assert(
        accountInfoS1?.signers.first.key.address == server1KeyPair.accountId);
    assert(accountInfoS1?.identities.first.role == RecoveryRole.owner);
    assert(accountInfoS1?.identities.first.authenticated == true);
    assert(accountInfoS2?.address.address == accountKp.address);
    assert(
        accountInfoS2?.signers.first.key.address == server2KeyPair.accountId);
    assert(accountInfoS2?.identities.first.role == RecoveryRole.owner);
    assert(accountInfoS2?.identities.first.authenticated == true);
  });

  test('test recover wallet', () async {
    // first register
    await flutter_sdk.FriendBot.fundTestAccount(account2Kp.address);
    var recoverableWallet = await createRecoverableWallet(account2Kp);
    assert(recoverableWallet.signers.isNotEmpty);
    var transaction = recoverableWallet.transaction;
    transaction.sign(account2Kp.keyPair, flutter_sdk.Network.TESTNET);
    assert(await wallet.stellar().submitTransaction(transaction));
    await validateSigners(
        account2Kp.address, deviceKp.address, recoverableWallet.signers);

    // recover
    // prepare auth
    Recovery recovery = wallet.recovery(servers,
        httpClient: recoverWalletMock(recoveryKp, account2Kp));
    var sep10S1 = await recovery.sep10Auth(first);
    var authToken1 = await sep10S1.authenticate(recoveryKp);
    assert(authToken1.jwt == successJWTToken);
    var serverAuth = {
      first: RecoveryServerSigning(server1KeyPair.accountId, authToken1.jwt),
      second: RecoveryServerSigning(server2KeyPair.accountId, emailAuthToken)
    };

    // recover with known lost key
    var signedReplaceKeyTx = await recovery
        .replaceDeviceKey(account2Kp, newKey1, serverAuth, lostKey: deviceKp);
    assert(signedReplaceKeyTx.sourceAccount.accountId == account2Kp.address);
    assert(await wallet.stellar().submitTransaction(signedReplaceKeyTx));
    await validateSigners(
        account2Kp.address, newKey1.address, recoverableWallet.signers,
        notSigner: deviceKp.address);

    // recover with unknown lost key

    signedReplaceKeyTx =
        await recovery.replaceDeviceKey(account2Kp, newKey2, serverAuth);
    assert(signedReplaceKeyTx.sourceAccount.accountId == account2Kp.address);
    assert(await wallet.stellar().submitTransaction(signedReplaceKeyTx));
    await validateSigners(
        account2Kp.address, newKey2.address, recoverableWallet.signers,
        notSigner: newKey1.address);

    // recover with sponsor and existing account
    await flutter_sdk.FriendBot.fundTestAccount(sponsor2Kp.address);
    recovery = wallet.recovery(servers,
        httpClient: recoverWalletMock(recoveryKp, account2Kp,
            sponsor: sponsor2Kp.address));
    signedReplaceKeyTx = await recovery.replaceDeviceKey(
        account2Kp, newKey3, serverAuth,
        sponsorAddress: sponsor2Kp);
    assert(signedReplaceKeyTx.sourceAccount.accountId == sponsor2Kp.address);
    signedReplaceKeyTx.sign(sponsor2Kp.keyPair, flutter_sdk.Network.TESTNET);
    assert(await wallet.stellar().submitTransaction(signedReplaceKeyTx));
    await validateSigners(
        account2Kp.address, newKey3.address, recoverableWallet.signers,
        notSigner: newKey2.address);
  });

  test('test roundtrip with sponsor', () async {
// recover with sponsor and not existing account
    // first register
    await flutter_sdk.FriendBot.fundTestAccount(sponsor2Kp.address);
    var recoverableWallet =
        await createRecoverableWallet(sponsoredAccount2Kp, sponsor: sponsor2Kp);
    assert(recoverableWallet.signers.isNotEmpty);
    var transaction = recoverableWallet.transaction;
    transaction.sign(sponsoredAccount2Kp.keyPair, flutter_sdk.Network.TESTNET);
    transaction.sign(sponsor2Kp.keyPair, flutter_sdk.Network.TESTNET);
    assert(await wallet.stellar().submitTransaction(transaction));
    await validateSigners(sponsoredAccount2Kp.address, deviceKp.address,
        recoverableWallet.signers);

    // prepare auth
    Recovery recovery = wallet.recovery(servers,
        httpClient: recoverWalletMock(recoveryKp, sponsoredAccount2Kp,
            sponsor: sponsor2Kp.address));
    var sep10S1 = await recovery.sep10Auth(first);
    var authToken1 = await sep10S1.authenticate(recoveryKp);
    assert(authToken1.jwt == successJWTToken);
    var serverAuth = {
      first: RecoveryServerSigning(server1KeyPair.accountId, authToken1.jwt),
      second: RecoveryServerSigning(server2KeyPair.accountId, emailAuthToken)
    };

    // recover
    var signedReplaceKeyTx = await recovery.replaceDeviceKey(
        sponsoredAccount2Kp, newKey1, serverAuth,
        sponsorAddress: sponsor2Kp);
    assert(signedReplaceKeyTx.sourceAccount.accountId == sponsor2Kp.address);
    signedReplaceKeyTx.sign(sponsor2Kp.keyPair, flutter_sdk.Network.TESTNET);
    assert(await wallet.stellar().submitTransaction(signedReplaceKeyTx));
    await validateSigners(
        sponsoredAccount2Kp.address, newKey1.address, recoverableWallet.signers,
        notSigner: deviceKp.address);
  });
}
