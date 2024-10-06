@Timeout(Duration(seconds: 400))

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/uri/sep_7.dart';
import 'package:http/http.dart' as http;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  var wallet = Wallet.testNet;
  var stellar = wallet.stellar();
  var account = stellar.account();

  const classicTxXdr =
      "AAAAAgAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAGQABqQMAAAAAQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAAAAmJaAAAAAAAAAAAFw7E5LAAAAQBu4V+/lttEONNM6KFwdSf5TEEogyEBy0jTOHJKuUzKScpLHyvDJGY+xH9Ri4cIuA7AaB8aL+VdlucCfsNYpKAY=";
  const sorobanTransferTxXdr =
      "AAAAAgAAAACM6IR9GHiRoVVAO78JJNksy2fKDQNs2jBn8bacsRLcrDucaFsAAAWIAAAAMQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAGAAAAAAAAAABHkEVdJ+UfDnWpBr/qF582IEoDQ0iW0WPzO9CEUdvvh8AAAAIdHJhbnNmZXIAAAADAAAAEgAAAAAAAAAAjOiEfRh4kaFVQDu/CSTZLMtnyg0DbNowZ/G2nLES3KwAAAASAAAAAAAAAADoFl2ACT9HZkbCeuaT9MAIdStpdf58wM3P24nl738AnQAAAAoAAAAAAAAAAAAAAAAAAAAFAAAAAQAAAAAAAAAAAAAAAR5BFXSflHw51qQa/6hefNiBKA0NIltFj8zvQhFHb74fAAAACHRyYW5zZmVyAAAAAwAAABIAAAAAAAAAAIzohH0YeJGhVUA7vwkk2SzLZ8oNA2zaMGfxtpyxEtysAAAAEgAAAAAAAAAA6BZdgAk/R2ZGwnrmk/TACHUraXX+fMDNz9uJ5e9/AJ0AAAAKAAAAAAAAAAAAAAAAAAAABQAAAAAAAAABAAAAAAAAAAIAAAAGAAAAAR5BFXSflHw51qQa/6hefNiBKA0NIltFj8zvQhFHb74fAAAAFAAAAAEAAAAHa35L+/RxV6EuJOVk78H5rCN+eubXBWtsKrRxeLnnpRAAAAACAAAABgAAAAEeQRV0n5R8OdakGv+oXnzYgSgNDSJbRY/M70IRR2++HwAAABAAAAABAAAAAgAAAA8AAAAHQmFsYW5jZQAAAAASAAAAAAAAAACM6IR9GHiRoVVAO78JJNksy2fKDQNs2jBn8bacsRLcrAAAAAEAAAAGAAAAAR5BFXSflHw51qQa/6hefNiBKA0NIltFj8zvQhFHb74fAAAAEAAAAAEAAAACAAAADwAAAAdCYWxhbmNlAAAAABIAAAAAAAAAAOgWXYAJP0dmRsJ65pP0wAh1K2l1/nzAzc/bieXvfwCdAAAAAQBkcwsAACBwAAABKAAAAAAAAB1kAAAAAA==";
  const sorobanMintTxXdr =
      "AAAAAgAAAACM6IR9GHiRoVVAO78JJNksy2fKDQNs2jBn8bacsRLcrDucQIQAAAWIAAAAMQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAGAAAAAAAAAABHkEVdJ+UfDnWpBr/qF582IEoDQ0iW0WPzO9CEUdvvh8AAAAEbWludAAAAAIAAAASAAAAAAAAAADoFl2ACT9HZkbCeuaT9MAIdStpdf58wM3P24nl738AnQAAAAoAAAAAAAAAAAAAAAAAAAAFAAAAAQAAAAAAAAAAAAAAAR5BFXSflHw51qQa/6hefNiBKA0NIltFj8zvQhFHb74fAAAABG1pbnQAAAACAAAAEgAAAAAAAAAA6BZdgAk/R2ZGwnrmk/TACHUraXX+fMDNz9uJ5e9/AJ0AAAAKAAAAAAAAAAAAAAAAAAAABQAAAAAAAAABAAAAAAAAAAIAAAAGAAAAAR5BFXSflHw51qQa/6hefNiBKA0NIltFj8zvQhFHb74fAAAAFAAAAAEAAAAHa35L+/RxV6EuJOVk78H5rCN+eubXBWtsKrRxeLnnpRAAAAABAAAABgAAAAEeQRV0n5R8OdakGv+oXnzYgSgNDSJbRY/M70IRR2++HwAAABAAAAABAAAAAgAAAA8AAAAHQmFsYW5jZQAAAAASAAAAAAAAAADoFl2ACT9HZkbCeuaT9MAIdStpdf58wM3P24nl738AnQAAAAEAYpBIAAAfrAAAAJQAAAAAAAAdYwAAAAA=";

  test('sep7tx', () async {
    var sep7 = Sep7Tx();
    var validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(!validationResult.result);

    sep7.setXdr(classicTxXdr);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getXdr() == classicTxXdr);

    sep7 = Sep7Tx.forTransaction(
        flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(classicTxXdr));
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getXdr() == classicTxXdr);

    var callback = "https://soneso.com/sep7";
    sep7.setCallback(callback);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getCallback() == callback);
    // should default to public network if not set
    assert(sep7.getNetworkPassphrase() ==
        flutter_sdk.Network.PUBLIC.networkPassphrase);

    var urlCallback = "url:https://soneso.com/sep7";
    sep7.setCallback(urlCallback);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    // should remove "url:" prefix when getting
    assert(sep7.getCallback() == callback);

    var msg = "Hello world!";
    sep7.setMsg(msg);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getMsg() == msg);

    // Should throw when message is too long
    msg =
        "another long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long message";
    bool thrown = false;
    try {
      sep7.setMsg(msg);
    } on Sep7MsgTooLong catch (_) {
      thrown = true;
    }
    assert(thrown);

    // Should throw when message is too long and creating from uri string
    var uriString =
        "web+stellar:tx?xdr=${Uri.encodeComponent(classicTxXdr)}&msg=test%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20message%20test%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20message";
    thrown = false;
    try {
      Sep7.parseSep7Uri(uriString);
    } on Sep7InvalidUri catch (e) {
      thrown = true;
      assert(e.message ==
          "The 'msg' parameter should be no longer than 300 characters");
    }
    assert(thrown);

    final networkPassphrase = flutter_sdk.Network.TESTNET.networkPassphrase;
    sep7.setNetworkPassphrase(networkPassphrase);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getNetworkPassphrase() == networkPassphrase);

    sep7.setNetwork(flutter_sdk.Network.TESTNET);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getNetworkPassphrase() == networkPassphrase);
    assert(sep7.getNetwork().networkPassphrase == networkPassphrase);

    const originDomain = "soneso.com";
    sep7.setOriginDomain(originDomain);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getOriginDomain() == originDomain);

    var accountKeyPair = account.createKeyPair();
    sep7.setPubKey(accountKeyPair.address);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getPubKey() == accountKeyPair.address);

    sep7.addSignature(accountKeyPair);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getSignature() != null);

    var parsedSep7 = Sep7.parseSep7Uri(sep7.toString());
    assert(parsedSep7 is Sep7Tx);
    assert(parsedSep7.operationType == Sep7OperationType.tx);
    assert(sep7.toString() == parsedSep7.toString());

    // verifySignature() returns false when there is no origin_domain and signature
    uriString = "web+stellar:tx?xdr=${Uri.encodeComponent(classicTxXdr)}";
    parsedSep7 = Sep7.parseSep7Uri(sep7.toString());
    assert(parsedSep7 is Sep7Tx);
    var passedVerification = await parsedSep7.verifySignature();
    assert(!passedVerification);

    var sep7tx = Sep7Tx.forTransaction(
        flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(
            sorobanTransferTxXdr));
    validationResult = Sep7.isValidSep7Uri(sep7tx.toString());
    assert(validationResult.result);

    sep7tx = Sep7Tx.forTransaction(
        flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(
            sorobanMintTxXdr));
    validationResult = Sep7.isValidSep7Uri(sep7tx.toString());
    assert(validationResult.result);
  });

  test('sep7pay', () {
    var accountKeyPair = account.createKeyPair();
    var sep7 = Sep7Pay();
    var validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(!validationResult.result);

    sep7.setDestination(accountKeyPair.address);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getDestination() == accountKeyPair.address);

    const callback = "https://soneso.com/sep7";
    sep7.setCallback(callback);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getCallback() == callback);

    const msg = "Hello world!";
    sep7.setMsg(msg);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getMsg() == msg);

    final networkPassphrase = flutter_sdk.Network.TESTNET.networkPassphrase;
    sep7.setNetworkPassphrase(networkPassphrase);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getNetworkPassphrase() == networkPassphrase);

    sep7.setNetwork(flutter_sdk.Network.TESTNET);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getNetworkPassphrase() == networkPassphrase);
    assert(sep7.getNetwork().networkPassphrase == networkPassphrase);

    const originDomain = "soneso.com";
    sep7.setOriginDomain(originDomain);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getOriginDomain() == originDomain);

    const amount = "22.30";
    sep7.setAmount(amount);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getAmount() == amount);

    const assetCode = "USDC";
    sep7.setAssetCode(assetCode);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getAssetCode() == assetCode);

    const assetIssuer =
        "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM";
    sep7.setAssetIssuer(assetIssuer);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getAssetIssuer() == assetIssuer);

    const memo = "1092839284";
    sep7.setMemo(memo);
    sep7.setMemoType(Sep7.memoTypeId);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getMemo() == memo);
    assert(sep7.getMemoType() == Sep7.memoTypeId);

    sep7.addSignature(accountKeyPair);
    validationResult = Sep7.isValidSep7Uri(sep7.toString());
    assert(validationResult.result);
    assert(sep7.getSignature() != null);

    var parsedSep7 = Sep7.parseSep7Uri(sep7.toString());
    assert(parsedSep7 is Sep7Pay);
    assert(parsedSep7.operationType == Sep7OperationType.pay);
    assert(sep7.toString() == parsedSep7.toString());

  });

  test('test verify signature', () async {
    var transaction =
        flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(sorobanMintTxXdr);
    const String originDomain = 'place.domain.com';
    final SigningKeyPair signerKeyPair = SigningKeyPair.fromSecret(
        'SBA2XQ5SRUW5H3FUQARMC6QYEPUYNSVCMM4PGESGVB2UIFHLM73TPXXF');
    var toml = '''# Sample stellar.toml

    FEDERATION_SERVER="https://api.domain.com/federation"
    AUTH_SERVER="https://api.domain.com/auth"
    TRANSFER_SERVER="https://api.domain.com"
    URI_REQUEST_SIGNING_KEY="GDGUF4SCNINRDCRUIVOMDYGIMXOWVP3ZLMTL2OGQIWMFDDSECZSFQMQV"''';

    var sep7tx = Sep7Tx.forTransaction(transaction);
    bool verificationResult = await sep7tx.verifySignature();
    // no signature, no origin_domain
    assert(!verificationResult);

    sep7tx = Sep7Tx.forTransaction(transaction);
    sep7tx.setOriginDomain(originDomain);
    // no signature
    verificationResult = await sep7tx.verifySignature();
    assert(!verificationResult);

    var httpClient = MockClient((request) async {
      if (request.url
              .toString()
              .startsWith("https://$originDomain/.well-known/stellar.toml") &&
          request.method == "GET") {
        return http.Response(toml, 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    sep7tx = Sep7Tx.forTransaction(transaction, httpClient: httpClient);
    sep7tx.addSignature(signerKeyPair);
    verificationResult = await sep7tx.verifySignature();
    // no origin_domain
    assert(!verificationResult);

    sep7tx = Sep7Tx.forTransaction(transaction, httpClient: httpClient);
    sep7tx.setOriginDomain(originDomain);
    sep7tx.addSignature(signerKeyPair);
    verificationResult = await sep7tx.verifySignature();
    // ok
    assert(verificationResult);

    final otherSigner = SigningKeyPair.fromSecret(
        'SBKQDF56C5VY2YQTNQFGY7HM6R3V6QKDUEDXZQUCPQOP2EBZWG2QJ2JL');

    sep7tx = Sep7Tx.forTransaction(transaction, httpClient: httpClient);
    sep7tx.setOriginDomain(originDomain);
    sep7tx.addSignature(otherSigner);
    verificationResult = await sep7tx.verifySignature();
    // signature is not from toml:URI_REQUEST_SIGNING_KEY
    assert(!verificationResult);

    httpClient = MockClient((request) async {
      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    sep7tx = Sep7Tx.forTransaction(transaction, httpClient: httpClient);
    sep7tx.setOriginDomain(originDomain);
    sep7tx.addSignature(signerKeyPair);
    verificationResult = await sep7tx.verifySignature();
    // toml not found
    assert(!verificationResult);

    toml = '''# Sample stellar.toml

    FEDERATION_SERVER="https://api.domain.com/federation"
    AUTH_SERVER="https://api.domain.com/auth"
    TRANSFER_SERVER="https://api.domain.com"''';

    httpClient = MockClient((request) async {
      if (request.url
          .toString()
          .startsWith("https://$originDomain/.well-known/stellar.toml") &&
          request.method == "GET") {
        return http.Response(toml, 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    sep7tx = Sep7Tx.forTransaction(transaction, httpClient: httpClient);
    sep7tx.setOriginDomain(originDomain);
    sep7tx.addSignature(signerKeyPair);
    verificationResult = await sep7tx.verifySignature();
    // toml has no URI_REQUEST_SIGNING_KEY
    assert(!verificationResult);

    var uriString =
        "web+stellar:pay?destination=GCALNQQBXAPZ2WIRSDDBMSTAKCUH5SG6U76YBFLQLIXJTF7FE5AX7AOO&amount=120.1234567&memo=skdjfasf&msg=pay%20me%20with%20lumens&origin_domain=someDomain.com";
    var parsedSep7 = Sep7.parseSep7Uri(uriString);
    parsedSep7.addSignature(otherSigner);
    const expectedSignature =
        "juY2Pi1/IubcbIDds2CbnL+Imr7dbpJYMW1nLAesOmyh5v/uTVvJwI06RgCGBtHh5+5DWOhJUlEfOSGXPtqgAA==";
    assert(expectedSignature == parsedSep7.getSignature());
    uriString = parsedSep7.toString();
    assert(uriString
        .endsWith('&signature=${Uri.encodeComponent(expectedSignature)}'));

  });

  test('test replace param composing and parsing', () {
    final first = Sep7Replacement(
        id: 'X',
        path: 'sourceAccount',
        hint: 'account from where you want to pay fees');
    final second = Sep7Replacement(
        id: 'Y',
        path: 'operations[0].sourceAccount',
        hint:
            'account that needs the trustline and which will receive the new tokens');
    final third = Sep7Replacement(
        id: 'Y',
        path: 'operations[1].destination',
        hint:
            'account that needs the trustline and which will receive the new tokens');

    var replace = Sep7.sep7ReplacementsToString([first, second, third]);
    var expected =
        "sourceAccount:X,operations[0].sourceAccount:Y,operations[1].destination:Y;X:account from where you want to pay fees,Y:account that needs the trustline and which will receive the new tokens";
    assert(expected == replace);

    var sep7Tx = Sep7Tx();
    sep7Tx.setXdr(classicTxXdr);
    sep7Tx.setReplacements([first, second]);
    sep7Tx.addReplacement(third);
    var validationResult = Sep7.isValidSep7Uri(sep7Tx.toString());
    assert(validationResult.result);

    var replacements = Sep7.sep7ReplacementsFromString(replace);
    assert(replacements.length == 3);
    var firstParsed = replacements.first;
    assert(first.id == firstParsed.id);
    assert(first.path == firstParsed.path);
    assert(first.hint == firstParsed.hint);

    var secondParsed = replacements[1];
    assert(second.id == secondParsed.id);
    assert(second.path == secondParsed.path);
    assert(second.hint == secondParsed.hint);

    var thirdParsed = replacements[2];
    assert(second.id == thirdParsed.id);
    assert(third.path == thirdParsed.path);
    assert(third.hint == thirdParsed.hint);

    replacements = sep7Tx.getReplacements() ?? [];
    assert(replacements.length == 3);
    firstParsed = replacements.first;
    assert(first.id == firstParsed.id);
    assert(first.path == firstParsed.path);
    assert(first.hint == firstParsed.hint);

    secondParsed = replacements[1];
    assert(second.id == secondParsed.id);
    assert(second.path == secondParsed.path);
    assert(second.hint == secondParsed.hint);

    thirdParsed = replacements[2];
    assert(third.id == thirdParsed.id);
    assert(third.path == thirdParsed.path);
    assert(third.hint == thirdParsed.hint);
  });

  test('test doc', () async {
    final sourceAccountKeyPair = PublicKeyPair.fromAccountId(
        "GBMJZO6QSF4UV3XOI5OJIYXEEOP3Q2LENNB44E4O2GGDFR5K6CY4VMLU");
    final destinationAccountKeyPair = PublicKeyPair.fromAccountId(
        "GCFO6TM5XMXDBUMQZ2SF5SIAKQG5SZR5LMA3KUJCXCL3KDKNLSORDYV5");
    var txBuilder = await stellar.transaction(sourceAccountKeyPair);
    final tx = txBuilder.createAccount(destinationAccountKeyPair).build();
    final xdr = Uri.encodeComponent(tx.toEnvelopeXdrBase64());
    final callback = Uri.encodeComponent('https://example.com/callback');
    final txUri = 'web+stellar:tx?xdr=$xdr&callback=$callback';
    var uri = wallet.parseSep7Uri(txUri);

    if (uri is Sep7Tx) {
      uri.addReplacement(Sep7Replacement(
          id: 'X',
          path: 'sourceAccount',
          hint: 'account from where you want to pay fees'));
    }

    uri = Sep7Tx.forTransaction(tx);
    uri.setCallback('https://example.com/callback');
    uri.setMsg('here goes a message');
    //print(uri.toString());

    // pay

    const destination =
        'GBMJZO6QSF4UV3XOI5OJIYXEEOP3Q2LENNB44E4O2GGDFR5K6CY4VMLU';
    const assetIssuer =
        'GCFO6TM5XMXDBUMQZ2SF5SIAKQG5SZR5LMA3KUJCXCL3KDKNLSORDYV5';
    const assetCode = 'USDC';
    const amount = '120.1234567';
    const memo = 'memo';
    final message = Uri.encodeComponent('pay me with lumens');
    const originDomain = "example.com";
    final payUri =
        'web+stellar:pay?destination=$destination&amount=$amount&memo=$memo&msg=$message&origin_domain=$originDomain&asset_issuer=$assetIssuer&asset_code=$assetCode';
    uri = Sep7.parseSep7Uri(payUri);
    var validationResult = Sep7.isValidSep7Uri(uri.toString());
    assert(validationResult.result);

    uri = Sep7Pay.forDestination(
        'GBMJZO6QSF4UV3XOI5OJIYXEEOP3Q2LENNB44E4O2GGDFR5K6CY4VMLU');
    uri.setOriginDomain('example.com');
    final keypair = wallet.stellar().account().createKeyPair();
    uri.addSignature(SigningKeyPair.fromSecret(keypair.secretKey));
    //print(uri.getSignature());

    final passesVerification = await uri.verifySignature();
    assert(!passesVerification);
  });
}
