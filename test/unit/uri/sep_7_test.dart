// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';
import 'package:stellar_wallet_flutter_sdk/src/horizon/account.dart';
import 'package:stellar_wallet_flutter_sdk/src/uri/sep_7.dart';

void main() {
  // A valid, base64-encoded TransactionEnvelope XDR (classic transaction).
  // Used to populate the 'xdr' param for Sep7Tx instances. The base SDK
  // validates this envelope, so it must remain a real, parseable envelope.
  const String classicTxXdr =
      "AAAAAgAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAGQABqQMAAAAAQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAAAAmJaAAAAAAAAAAAFw7E5LAAAAQBu4V+/lttEONNM6KFwdSf5TEEogyEBy0jTOHJKuUzKScpLHyvDJGY+xH9Ri4cIuA7AaB8aL+VdlucCfsNYpKAY=";

  // A fixed Stellar account id used as a payment destination / public key.
  const String destinationAccountId =
      "GCALNQQBXAPZ2WIRSDDBMSTAKCUH5SG6U76YBFLQLIXJTF7FE5AX7AOO";

  // A fixed signing secret. ed25519 signing is deterministic, so signing a
  // fixed URI with this secret always yields the same base64 signature.
  const String fixedSecret =
      "SBA2XQ5SRUW5H3FUQARMC6QYEPUYNSVCMM4PGESGVB2UIFHLM73TPXXF";
  const String fixedSecretAccountId =
      "GDGUF4SCNINRDCRUIVOMDYGIMXOWVP3ZLMTL2OGQIWMFDDSECZSFQMQV";

  group('Sep7 Parse Tests', () {
    test('parseSep7Uri returns Sep7Tx for tx operation and round-trips', () {
      final uri =
          'web+stellar:tx?xdr=${Uri.encodeComponent(classicTxXdr)}';
      final parsed = Sep7.parseSep7Uri(uri);

      expect(parsed, isA<Sep7Tx>());
      expect(parsed.operationType, Sep7OperationType.tx);
      expect(parsed.getOperationType(), Sep7OperationType.tx);
      expect((parsed as Sep7Tx).getXdr(), classicTxXdr);
      // toString() reproduces the canonical URI exactly.
      expect(parsed.toString(), uri);
    });

    test('parseSep7Uri returns Sep7Pay for pay operation and round-trips', () {
      final uri =
          'web+stellar:pay?destination=$destinationAccountId&amount=120.1234567';
      final parsed = Sep7.parseSep7Uri(uri);

      expect(parsed, isA<Sep7Pay>());
      expect(parsed.operationType, Sep7OperationType.pay);
      expect((parsed as Sep7Pay).getDestination(), destinationAccountId);
      expect(parsed.getAmount(), '120.1234567');
      expect(parsed.toString(), uri);
    });

    test('parseSep7Uri decodes percent-encoded params (msg with spaces)', () {
      final uri =
          'web+stellar:pay?destination=$destinationAccountId&msg=pay%20me%20with%20lumens';
      final parsed = Sep7.parseSep7Uri(uri) as Sep7Pay;

      expect(parsed.getMsg(), 'pay me with lumens');
      // Re-serialization keeps spaces percent-encoded as %20.
      expect(parsed.toString(), uri);
    });

    test('parse then toString reproduces a fully populated pay URI', () {
      const assetIssuer =
          "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM";
      final uri = 'web+stellar:pay?destination=$destinationAccountId'
          '&amount=22.30'
          '&asset_code=USDC'
          '&asset_issuer=$assetIssuer'
          '&memo=1092839284'
          '&memo_type=MEMO_ID'
          '&origin_domain=soneso.com';
      final parsed = Sep7.parseSep7Uri(uri) as Sep7Pay;

      expect(parsed.getDestination(), destinationAccountId);
      expect(parsed.getAmount(), '22.30');
      expect(parsed.getAssetCode(), 'USDC');
      expect(parsed.getAssetIssuer(), assetIssuer);
      expect(parsed.getMemo(), '1092839284');
      expect(parsed.getMemoType(), Sep7.memoTypeId);
      expect(parsed.getOriginDomain(), 'soneso.com');
      expect(parsed.toString(), uri);
    });
  });

  group('Sep7 Parse Error Tests', () {
    test('parseSep7Uri throws Sep7InvalidUri for non web+stellar scheme', () {
      expect(
        () => Sep7.parseSep7Uri('https://example.com/tx?xdr=abc'),
        throwsA(isA<Sep7InvalidUri>().having(
            (e) => e.message, 'message', 'It must start with web+stellar:')),
      );
    });

    test(
        'parseSep7Uri throws Sep7UriTypeNotSupported for a web+stellar URI '
        'with an unsupported operation type', () {
      // 'foo' is a structurally valid web+stellar URI operation segment but is
      // neither 'tx' nor 'pay', so the specific Sep7UriTypeNotSupported is
      // surfaced (not the generic Sep7InvalidUri).
      expect(
        () => Sep7.parseSep7Uri('web+stellar:foo?xdr=abc'),
        throwsA(isA<Sep7UriTypeNotSupported>()),
      );
    });

    test('parseSep7Uri throws Sep7InvalidUri for tx without xdr param', () {
      expect(
        () => Sep7.parseSep7Uri('web+stellar:tx?msg=hello'),
        throwsA(isA<Sep7InvalidUri>()),
      );
    });

    test('parseSep7Uri throws Sep7InvalidUri for pay without destination', () {
      expect(
        () => Sep7.parseSep7Uri('web+stellar:pay?amount=10'),
        throwsA(isA<Sep7InvalidUri>()),
      );
    });

    test('parseSep7Uri throws Sep7InvalidUri for invalid xdr envelope', () {
      expect(
        () => Sep7.parseSep7Uri('web+stellar:tx?xdr=not-a-valid-envelope'),
        throwsA(isA<Sep7InvalidUri>()),
      );
    });

    test('parseSep7Uri throws Sep7InvalidUri when msg exceeds 300 chars', () {
      final longMsg = 'a' * 301;
      final uri =
          'web+stellar:tx?xdr=${Uri.encodeComponent(classicTxXdr)}&msg=${Uri.encodeComponent(longMsg)}';
      expect(
        () => Sep7.parseSep7Uri(uri),
        throwsA(isA<Sep7InvalidUri>()),
      );
    });
  });

  group('Sep7 isValidSep7Uri Tests', () {
    test('returns false with reason for unsupported operation type', () {
      final result = Sep7.isValidSep7Uri('web+stellar:foo?xdr=abc');
      expect(result.result, isFalse);
      expect(result.reason, 'Operation type foo is not supported');
    });

    test('returns true for a valid tx uri', () {
      final uri = 'web+stellar:tx?xdr=${Uri.encodeComponent(classicTxXdr)}';
      final result = Sep7.isValidSep7Uri(uri);
      expect(result.result, isTrue);
    });
  });

  group('Sep7 toString Encoding Tests', () {
    test('empty Sep7Tx serializes to bare tx prefix with no trailing &', () {
      final tx = Sep7Tx();
      expect(tx.toString(), 'web+stellar:tx?');
    });

    test('empty Sep7Pay serializes to bare pay prefix with no trailing &', () {
      final pay = Sep7Pay();
      expect(pay.toString(), 'web+stellar:pay?');
    });

    test('encodes spaces as %20 (not +)', () {
      final pay = Sep7Pay();
      pay.setDestination(destinationAccountId);
      pay.setMsg('pay me with lumens');
      final result = pay.toString();
      expect(result.contains('msg=pay%20me%20with%20lumens'), isTrue);
      // The encoded msg value must use %20, never '+', for spaces.
      // (The 'web+stellar:' scheme itself legitimately contains a '+'.)
      final msgValue = result.substring(result.indexOf('msg=') + 'msg='.length);
      expect(msgValue.contains('+'), isFalse);
      expect(msgValue.contains('%20'), isTrue);
    });

    test('does not leave a trailing & between params', () {
      final pay = Sep7Pay();
      pay.setDestination(destinationAccountId);
      pay.setAmount('10');
      final result = pay.toString();
      expect(result.endsWith('&'), isFalse);
      expect(
          result, 'web+stellar:pay?destination=$destinationAccountId&amount=10');
    });

    test('percent-encodes reserved characters in param values', () {
      final pay = Sep7Pay();
      pay.setDestination(destinationAccountId);
      // '&' and '=' must be encoded so they don't break param boundaries.
      pay.setMemo('a&b=c');
      final result = pay.toString();
      expect(result.contains('memo=a%26b%3Dc'), isTrue);

      // Round-trips back to the original value.
      final parsed = Sep7.parseSep7Uri(result) as Sep7Pay;
      expect(parsed.getMemo(), 'a&b=c');
    });
  });

  group('Sep7 setMsg Tests', () {
    test('accepts a message of exactly 300 characters', () {
      final tx = Sep7Tx();
      final msg = 'a' * 300;
      tx.setMsg(msg);
      expect(tx.getMsg(), msg);
      expect(tx.getMsg()!.length, 300);
    });

    test('throws Sep7MsgTooLong for 301 characters', () {
      final tx = Sep7Tx();
      final msg = 'a' * 301;
      expect(
        () => tx.setMsg(msg),
        throwsA(isA<Sep7MsgTooLong>().having((e) => e.message, 'message',
            "'msg' should be no longer than 300 characters")),
      );
      // The over-long value must not have been stored.
      expect(tx.getMsg(), isNull);
    });

    test('null msg deletes the param', () {
      final tx = Sep7Tx();
      tx.setMsg('hello');
      expect(tx.getMsg(), 'hello');
      tx.setMsg(null);
      expect(tx.getMsg(), isNull);
    });
  });

  group('Sep7 setCallback Tests', () {
    test('adds url: prefix when storing a bare url', () {
      final tx = Sep7Tx();
      const callback = 'https://soneso.com/sep7';
      tx.setCallback(callback);
      // Stored value carries the url: prefix...
      expect(tx.queryParameters['callback'], 'url:$callback');
      // ...but the getter strips it.
      expect(tx.getCallback(), callback);
    });

    test('keeps a single url: prefix when one is already present', () {
      final tx = Sep7Tx();
      const callback = 'https://soneso.com/sep7';
      tx.setCallback('url:$callback');
      expect(tx.queryParameters['callback'], 'url:$callback');
      expect(tx.getCallback(), callback);
    });

    test('null callback deletes the param', () {
      final tx = Sep7Tx();
      tx.setCallback('https://soneso.com/sep7');
      expect(tx.getCallback(), 'https://soneso.com/sep7');
      tx.setCallback(null);
      expect(tx.getCallback(), isNull);
      expect(tx.queryParameters.containsKey('callback'), isFalse);
    });

    test('getCallback returns null when no callback is set', () {
      final tx = Sep7Tx();
      expect(tx.getCallback(), isNull);
    });
  });

  group('Sep7 Network Tests', () {
    test('getNetworkPassphrase defaults to PUBLIC when unset', () {
      final tx = Sep7Tx();
      expect(tx.getNetworkPassphrase(),
          flutter_sdk.Network.PUBLIC.networkPassphrase);
    });

    test('getNetwork defaults to PUBLIC when unset', () {
      final tx = Sep7Tx();
      expect(tx.getNetwork().networkPassphrase,
          flutter_sdk.Network.PUBLIC.networkPassphrase);
    });

    test('setNetworkPassphrase round-trips via getNetworkPassphrase', () {
      final tx = Sep7Tx();
      final passphrase = flutter_sdk.Network.TESTNET.networkPassphrase;
      tx.setNetworkPassphrase(passphrase);
      expect(tx.getNetworkPassphrase(), passphrase);
      expect(tx.getNetwork().networkPassphrase, passphrase);
    });

    test('setNetwork round-trips via getNetwork and getNetworkPassphrase', () {
      final tx = Sep7Tx();
      tx.setNetwork(flutter_sdk.Network.TESTNET);
      expect(tx.getNetwork().networkPassphrase,
          flutter_sdk.Network.TESTNET.networkPassphrase);
      expect(tx.getNetworkPassphrase(),
          flutter_sdk.Network.TESTNET.networkPassphrase);
    });

    test('setNetwork(null) deletes the param, reverting to PUBLIC default', () {
      final tx = Sep7Tx();
      tx.setNetwork(flutter_sdk.Network.TESTNET);
      expect(tx.getNetworkPassphrase(),
          flutter_sdk.Network.TESTNET.networkPassphrase);
      tx.setNetwork(null);
      expect(tx.getNetworkPassphrase(),
          flutter_sdk.Network.PUBLIC.networkPassphrase);
    });

    test('setNetworkPassphrase(null) deletes the param', () {
      final tx = Sep7Tx();
      tx.setNetworkPassphrase(flutter_sdk.Network.TESTNET.networkPassphrase);
      tx.setNetworkPassphrase(null);
      expect(tx.queryParameters.containsKey('network_passphrase'), isFalse);
      expect(tx.getNetworkPassphrase(),
          flutter_sdk.Network.PUBLIC.networkPassphrase);
    });
  });

  group('Sep7Replacement Conversion Tests', () {
    test('sep7ReplacementsToString produces the SEP-0011 txrep format', () {
      final first = Sep7Replacement(
          id: 'X',
          path: 'sourceAccount',
          hint: 'account from where you want to pay fees');
      final second = Sep7Replacement(
          id: 'Y',
          path: 'operations[0].sourceAccount',
          hint: 'account that needs the trustline');

      final result = Sep7.sep7ReplacementsToString([first, second]);
      expect(
          result,
          'sourceAccount:X,operations[0].sourceAccount:Y;'
          'X:account from where you want to pay fees,'
          'Y:account that needs the trustline');
    });

    test('sep7ReplacementsFromString parses back into Sep7Replacement list', () {
      const input =
          'sourceAccount:X,operations[0].sourceAccount:Y;'
          'X:pay fees,Y:receive tokens';
      final parsed = Sep7.sep7ReplacementsFromString(input);

      expect(parsed.length, 2);
      expect(parsed[0].id, 'X');
      expect(parsed[0].path, 'sourceAccount');
      expect(parsed[0].hint, 'pay fees');
      expect(parsed[1].id, 'Y');
      expect(parsed[1].path, 'operations[0].sourceAccount');
      expect(parsed[1].hint, 'receive tokens');
    });

    test('toString/fromString round-trip preserves replacements', () {
      final replacements = [
        Sep7Replacement(
            id: 'X', path: 'sourceAccount', hint: 'fee source account'),
        Sep7Replacement(
            id: 'Y',
            path: 'operations[1].destination',
            hint: 'token destination'),
      ];
      final str = Sep7.sep7ReplacementsToString(replacements);
      final parsed = Sep7.sep7ReplacementsFromString(str);

      expect(parsed.length, replacements.length);
      for (var i = 0; i < replacements.length; i++) {
        expect(parsed[i].id, replacements[i].id);
        expect(parsed[i].path, replacements[i].path);
        expect(parsed[i].hint, replacements[i].hint);
      }
    });
  });

  group('Sep7Tx Tests', () {
    test('forTransaction sets the xdr param from the envelope', () {
      final transaction =
          flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(classicTxXdr);
      final sep7tx = Sep7Tx.forTransaction(transaction);

      expect(sep7tx.operationType, Sep7OperationType.tx);
      expect(sep7tx.getXdr(), classicTxXdr);
      expect(sep7tx.queryParameters['xdr'], classicTxXdr);
    });

    test('setXdr/getXdr round-trip', () {
      final tx = Sep7Tx();
      tx.setXdr(classicTxXdr);
      expect(tx.getXdr(), classicTxXdr);
    });

    test('setXdr(null) deletes the xdr param', () {
      final tx = Sep7Tx();
      tx.setXdr(classicTxXdr);
      tx.setXdr(null);
      expect(tx.getXdr(), isNull);
    });

    test('setPubKey/getPubKey round-trip', () {
      final tx = Sep7Tx();
      tx.setPubKey(destinationAccountId);
      expect(tx.getPubKey(), destinationAccountId);
    });

    test('setChain/getChain round-trip', () {
      final tx = Sep7Tx();
      final chained =
          'web+stellar:tx?xdr=${Uri.encodeComponent(classicTxXdr)}';
      tx.setChain(chained);
      expect(tx.getChain(), chained);
    });

    test('setReplacements then getReplacements round-trips', () {
      final tx = Sep7Tx();
      tx.setXdr(classicTxXdr);
      final replacements = [
        Sep7Replacement(
            id: 'X', path: 'sourceAccount', hint: 'fee source account'),
        Sep7Replacement(
            id: 'Y',
            path: 'operations[0].destination',
            hint: 'payment destination'),
      ];
      tx.setReplacements(replacements);

      final read = tx.getReplacements();
      expect(read, isNotNull);
      expect(read!.length, 2);
      expect(read[0].id, 'X');
      expect(read[0].path, 'sourceAccount');
      expect(read[1].id, 'Y');
      expect(read[1].path, 'operations[0].destination');
    });

    test('setReplacements with empty list deletes the replace param', () {
      final tx = Sep7Tx();
      tx.setXdr(classicTxXdr);
      tx.setReplacements([
        Sep7Replacement(id: 'X', path: 'sourceAccount', hint: 'h'),
      ]);
      expect(tx.getReplacements(), isNotNull);
      tx.setReplacements([]);
      expect(tx.getReplacements(), isNull);
      expect(tx.queryParameters.containsKey('replace'), isFalse);
    });

    test('addReplacement appends to existing replacements', () {
      final tx = Sep7Tx();
      tx.setXdr(classicTxXdr);
      tx.addReplacement(
          Sep7Replacement(id: 'X', path: 'sourceAccount', hint: 'first'));
      tx.addReplacement(Sep7Replacement(
          id: 'Y', path: 'operations[0].destination', hint: 'second'));

      final read = tx.getReplacements();
      expect(read, isNotNull);
      expect(read!.length, 2);
      expect(read[0].id, 'X');
      expect(read[1].id, 'Y');
    });
  });

  group('Sep7Pay Tests', () {
    test('forDestination sets the destination param', () {
      final pay = Sep7Pay.forDestination(destinationAccountId);
      expect(pay.operationType, Sep7OperationType.pay);
      expect(pay.getDestination(), destinationAccountId);
      expect(pay.queryParameters['destination'], destinationAccountId);
    });

    test('amount round-trips', () {
      final pay = Sep7Pay.forDestination(destinationAccountId);
      pay.setAmount('120.1234567');
      expect(pay.getAmount(), '120.1234567');
    });

    test('asset code and issuer round-trip', () {
      const issuer =
          "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM";
      final pay = Sep7Pay.forDestination(destinationAccountId);
      pay.setAssetCode('USDC');
      pay.setAssetIssuer(issuer);
      expect(pay.getAssetCode(), 'USDC');
      expect(pay.getAssetIssuer(), issuer);
    });

    test('memo and memo type round-trip', () {
      final pay = Sep7Pay.forDestination(destinationAccountId);
      pay.setMemo('1092839284');
      pay.setMemoType(Sep7.memoTypeId);
      expect(pay.getMemo(), '1092839284');
      expect(pay.getMemoType(), Sep7.memoTypeId);
    });

    test('setDestination(null) deletes the destination param', () {
      final pay = Sep7Pay.forDestination(destinationAccountId);
      pay.setDestination(null);
      expect(pay.getDestination(), isNull);
    });
  });

  group('Sep7 Signature Tests', () {
    setUp(() {
      // Validate the fixed key material once so the deterministic-signature
      // assertions below have a stable, verified basis.
      final signer = SigningKeyPair.fromSecret(fixedSecret);
      expect(signer.address, fixedSecretAccountId);
    });

    test('addSignature adds a signature param and returns it', () {
      final pay = Sep7Pay.forDestination(destinationAccountId);
      pay.setAmount('120.1234567');
      pay.setOriginDomain('soneso.com');
      expect(pay.getSignature(), isNull);

      final signer = SigningKeyPair.fromSecret(fixedSecret);
      final signature = pay.addSignature(signer);

      expect(signature, isNotEmpty);
      expect(pay.getSignature(), signature);
      expect(pay.queryParameters.containsKey('signature'), isTrue);
    });

    test('addSignature is deterministic for a fixed key and URI', () {
      Sep7Pay buildUri() {
        final pay = Sep7Pay.forDestination(destinationAccountId);
        pay.setAmount('120.1234567');
        pay.setOriginDomain('soneso.com');
        return pay;
      }

      final signer = SigningKeyPair.fromSecret(fixedSecret);
      final sigA = buildUri().addSignature(signer);
      final sigB = buildUri().addSignature(signer);

      expect(sigA, sigB);
      // ed25519 over this exact unsigned URI yields this fixed signature.
      expect(
          sigA,
          'Bm/vaJU3Bhufc4nL+d7DeqGaQXSV/J1VzUZuqpmBiSV2uyJisE1XsSYa/G8DuXg1FKLwZZa7MSYHGy/bV/gWDw==');
    });

    test('signature is appended last and percent-encoded in toString', () {
      final pay = Sep7Pay.forDestination(destinationAccountId);
      pay.setAmount('120.1234567');
      pay.setOriginDomain('soneso.com');
      final signature = pay.addSignature(SigningKeyPair.fromSecret(fixedSecret));

      expect(pay.toString(),
          endsWith('&signature=${Uri.encodeComponent(signature)}'));
    });

    test('signed URI round-trips through parseSep7Uri preserving signature', () {
      final pay = Sep7Pay.forDestination(destinationAccountId);
      pay.setAmount('120.1234567');
      pay.setOriginDomain('soneso.com');
      final signature = pay.addSignature(SigningKeyPair.fromSecret(fixedSecret));

      final parsed = Sep7.parseSep7Uri(pay.toString());
      expect(parsed.getSignature(), signature);
      expect(parsed.toString(), pay.toString());
    });
  });
}
