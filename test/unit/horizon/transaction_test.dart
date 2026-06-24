// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  // Fixed, well-known account ids so assertions on source accounts are exact.
  const sourceAccountId =
      "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP";
  const destinationAccountId =
      "GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ";
  const signerAccountId =
      "GA6UIXXPEWYFILNUIWAC37Y4QPEZMQVDJHDKVWFZJ2KCWUBIU5IXZNDA";
  const issuerAccountId =
      "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM";
  const sponsorAccountId =
      "GAOO3LWBC4XF6VWRP5ESJ6IBHAISVJMSBTALHOQM2EZG7Q477UWA6L7U";

  // Maximum representable Stellar amount: int64 max stroops (9223372036854775807)
  // expressed with 7 decimal places.
  const maxAmount = "922337203685.4775807";
  // Minimum positive Stellar amount: 1 stroop.
  const minAmount = "0.0000001";

  late flutter_sdk.Account sourceAccount;
  late PublicKeyPair signerKeyPair;
  late PublicKeyPair sourceKeyPair;
  late IssuedAssetId usdAsset;
  late NativeAssetId nativeAsset;

  setUp(() {
    sourceAccount = flutter_sdk.Account(sourceAccountId, BigInt.from(10));
    signerKeyPair = PublicKeyPair.fromAccountId(signerAccountId);
    sourceKeyPair = PublicKeyPair.fromAccountId(sourceAccountId);
    usdAsset = IssuedAssetId(code: "USD", issuer: issuerAccountId);
    nativeAsset = NativeAssetId();
  });

  TxBuilder newBuilder() => TxBuilder(sourceAccount);

  group('CommonTxBuilder Tests', () {
    test('addAccountSigner sets signer key and passes weight through', () {
      var tx = newBuilder().addAccountSigner(signerKeyPair, 10).build();

      expect(tx.operations.length, 1);
      var op = tx.operations.first as flutter_sdk.SetOptionsOperation;
      expect(op.signerWeight, 10);
      expect(op.signer, isNotNull);
      expect(op.signer!.ed25519, isNotNull);
      expect(op.signer!.ed25519!.uint256, signerKeyPair.publicKey);
      expect(op.sourceAccount!.ed25519AccountId, sourceAccountId);
    });

    test('addAccountSigner passes weight 0 through unchanged', () {
      var tx = newBuilder().addAccountSigner(signerKeyPair, 0).build();
      var op = tx.operations.first as flutter_sdk.SetOptionsOperation;
      expect(op.signerWeight, 0);
      expect(op.signer!.ed25519!.uint256, signerKeyPair.publicKey);
    });

    test('addAccountSigner passes weight 255 through unchanged', () {
      var tx = newBuilder().addAccountSigner(signerKeyPair, 255).build();
      var op = tx.operations.first as flutter_sdk.SetOptionsOperation;
      expect(op.signerWeight, 255);
    });

    test('removeAccountSigner sets the signer weight to 0', () {
      var tx = newBuilder().removeAccountSigner(signerKeyPair).build();

      expect(tx.operations.length, 1);
      var op = tx.operations.first as flutter_sdk.SetOptionsOperation;
      expect(op.signerWeight, 0);
      expect(op.signer!.ed25519!.uint256, signerKeyPair.publicKey);
      expect(op.sourceAccount!.ed25519AccountId, sourceAccountId);
    });

    test('removeAccountSigner throws when removing the master (self) key', () {
      // signerAddress.address == sourceAccount.accountId triggers the guard.
      expect(() => newBuilder().removeAccountSigner(sourceKeyPair),
          throwsA(isA<Exception>()));
    });

    test('lockAccountMasterKey sets master key weight to 0', () {
      var tx = newBuilder().lockAccountMasterKey().build();

      expect(tx.operations.length, 1);
      var op = tx.operations.first as flutter_sdk.SetOptionsOperation;
      expect(op.masterKeyWeight, 0);
      expect(op.signer, isNull);
      expect(op.sourceAccount!.ed25519AccountId, sourceAccountId);
    });

    test('addAssetSupport uses default limit of int64 max amount', () {
      var tx = newBuilder().addAssetSupport(usdAsset).build();

      expect(tx.operations.length, 1);
      var op = tx.operations.first as flutter_sdk.ChangeTrustOperation;
      expect(op.limit, maxAmount);
      var asset = op.asset as flutter_sdk.AssetTypeCreditAlphaNum;
      expect(asset.code, "USD");
      expect(asset.issuerId, issuerAccountId);
      expect(op.sourceAccount!.ed25519AccountId, sourceAccountId);
    });

    test('addAssetSupport accepts a custom limit', () {
      var tx = newBuilder().addAssetSupport(usdAsset, limit: "100.5").build();
      var op = tx.operations.first as flutter_sdk.ChangeTrustOperation;
      expect(op.limit, "100.5");
    });

    test('removeAssetSupport sets the trust limit to 0', () {
      var tx = newBuilder().removeAssetSupport(usdAsset).build();

      var op = tx.operations.first as flutter_sdk.ChangeTrustOperation;
      expect(op.limit, "0");
      var asset = op.asset as flutter_sdk.AssetTypeCreditAlphaNum;
      expect(asset.code, "USD");
      expect(asset.issuerId, issuerAccountId);
    });

    test('setThreshold sets low, medium and high thresholds', () {
      var tx =
          newBuilder().setThreshold(low: 1, medium: 5, high: 10).build();

      expect(tx.operations.length, 1);
      var op = tx.operations.first as flutter_sdk.SetOptionsOperation;
      expect(op.lowThreshold, 1);
      expect(op.mediumThreshold, 5);
      expect(op.highThreshold, 10);
      expect(op.sourceAccount!.ed25519AccountId, sourceAccountId);
    });

    test('build returns a transaction with the source muxed account', () {
      var tx = newBuilder().lockAccountMasterKey().build();
      expect(tx.sourceAccount.ed25519AccountId, sourceAccountId);
    });
  });

  group('TxBuilder Memo and Preconditions Tests', () {
    test('setMemo attaches a text memo', () {
      var builder = newBuilder()..setMemo(flutter_sdk.Memo.text("hello"));
      builder.lockAccountMasterKey();
      var tx = builder.build();

      expect(tx.memo, isA<flutter_sdk.MemoText>());
      expect((tx.memo as flutter_sdk.MemoText).text, "hello");
    });

    test('setMemo a second time throws', () {
      var builder = newBuilder()..setMemo(flutter_sdk.Memo.text("first"));
      builder.lockAccountMasterKey();
      expect(() => builder.setMemo(flutter_sdk.Memo.text("second")),
          throwsA(isA<Exception>()));
    });

    test('setTimeBounds attaches time bounds to the transaction', () {
      var bounds = flutter_sdk.TimeBounds(100, 2000);
      var builder = newBuilder()..setTimeBounds(bounds);
      builder.lockAccountMasterKey();
      var tx = builder.build();

      expect(tx.preconditions, isNotNull);
      expect(tx.preconditions!.timeBounds, isNotNull);
      expect(tx.preconditions!.timeBounds!.minTime, 100);
      expect(tx.preconditions!.timeBounds!.maxTime, 2000);
    });
  });

  group('TxBuilder Fee Tests', () {
    test('default fee equals MIN_BASE_FEE times operation count', () {
      var tx = newBuilder()
          .lockAccountMasterKey()
          .setThreshold(low: 1, medium: 1, high: 1)
          .build();
      // 2 operations * 100 (MIN_BASE_FEE)
      expect(tx.operations.length, 2);
      expect(tx.fee, 200);
    });

    test('setBaseFee makes fee equal baseFee times operation count', () {
      var tx = newBuilder()
          .setBaseFee(200)
          .lockAccountMasterKey()
          .setThreshold(low: 1, medium: 1, high: 1)
          .build();
      // 2 operations * 200
      expect(tx.fee, 400);
    });

    test('setBaseFee below MIN_BASE_FEE (100) throws', () {
      expect(() => newBuilder().setBaseFee(99), throwsA(isA<Exception>()));
    });

    test('setBaseFee exactly MIN_BASE_FEE (100) is accepted', () {
      var tx = newBuilder().setBaseFee(100).lockAccountMasterKey().build();
      expect(tx.fee, 100);
    });
  });

  group('TxBuilder createAccount Tests', () {
    test('createAccount with default starting balance "1"', () {
      var newAccount = PublicKeyPair.fromAccountId(destinationAccountId);
      var tx = newBuilder().createAccount(newAccount).build();

      expect(tx.operations.length, 1);
      var op = tx.operations.first as flutter_sdk.CreateAccountOperation;
      expect(op.destination, destinationAccountId);
      expect(op.startingBalance, "1");
      expect(op.sourceAccount!.ed25519AccountId, sourceAccountId);
    });

    test('createAccount throws InvalidStartingBalanceException below 1', () {
      var newAccount = PublicKeyPair.fromAccountId(destinationAccountId);
      expect(
          () => newBuilder()
              .createAccount(newAccount, startingBalance: "0.9999999"),
          throwsA(isA<InvalidStartingBalanceException>()));
    });

    test('createAccount accepts a high-precision valid starting balance', () {
      var newAccount = PublicKeyPair.fromAccountId(destinationAccountId);
      var tx = newBuilder()
          .createAccount(newAccount, startingBalance: maxAmount)
          .build();
      var op = tx.operations.first as flutter_sdk.CreateAccountOperation;
      expect(op.startingBalance, maxAmount);
    });
  });

  group('TxBuilder accountMerge Tests', () {
    test('accountMerge defaults source to the builder source account', () {
      var tx = newBuilder()
          .accountMerge(destinationAddress: destinationAccountId)
          .build();

      expect(tx.operations.length, 1);
      var op = tx.operations.first as flutter_sdk.AccountMergeOperation;
      expect(op.destination.ed25519AccountId, destinationAccountId);
      expect(op.sourceAccount!.ed25519AccountId, sourceAccountId);
    });

    test('accountMerge uses an explicit source account when given', () {
      var tx = newBuilder()
          .accountMerge(
              destinationAddress: destinationAccountId,
              sourceAddress: signerAccountId)
          .build();
      var op = tx.operations.first as flutter_sdk.AccountMergeOperation;
      expect(op.sourceAccount!.ed25519AccountId, signerAccountId);
    });
  });

  group('TxBuilder transfer Tests', () {
    test('transfer builds a payment with native asset', () {
      var tx = newBuilder()
          .transfer(destinationAccountId, nativeAsset, "12.5")
          .build();

      expect(tx.operations.length, 1);
      var op = tx.operations.first as flutter_sdk.PaymentOperation;
      expect(op.destination.ed25519AccountId, destinationAccountId);
      expect(op.amount, "12.5");
      expect(op.asset, isA<flutter_sdk.AssetTypeNative>());
      expect(op.sourceAccount!.ed25519AccountId, sourceAccountId);
    });

    test('transfer preserves the maximum amount string', () {
      var tx = newBuilder()
          .transfer(destinationAccountId, usdAsset, maxAmount)
          .build();
      var op = tx.operations.first as flutter_sdk.PaymentOperation;
      expect(op.amount, maxAmount);
    });

    test('transfer preserves the minimum amount string ".0000001"', () {
      var tx = newBuilder()
          .transfer(destinationAccountId, usdAsset, ".0000001")
          .build();
      var op = tx.operations.first as flutter_sdk.PaymentOperation;
      expect(op.amount, ".0000001");
    });

    test('transfer sets the credit asset code and issuer', () {
      var tx = newBuilder()
          .transfer(destinationAccountId, usdAsset, "1")
          .build();
      var op = tx.operations.first as flutter_sdk.PaymentOperation;
      var asset = op.asset as flutter_sdk.AssetTypeCreditAlphaNum;
      expect(asset.code, "USD");
      expect(asset.issuerId, issuerAccountId);
    });
  });

  group('TxBuilder strictSend Tests', () {
    test('strictSend uses default destinationMinAmount 0.0000001', () {
      var tx = newBuilder()
          .strictSend(
              sendAssetId: nativeAsset,
              sendAmount: "100",
              destinationAddress: destinationAccountId,
              destinationAssetId: usdAsset)
          .build();

      expect(tx.operations.length, 1);
      var op =
          tx.operations.first as flutter_sdk.PathPaymentStrictSendOperation;
      expect(op.sendAmount, "100");
      expect(op.destMin, "0.0000001");
      expect(op.destination.ed25519AccountId, destinationAccountId);
      expect(op.sendAsset, isA<flutter_sdk.AssetTypeNative>());
      var destAsset = op.destAsset as flutter_sdk.AssetTypeCreditAlphaNum;
      expect(destAsset.code, "USD");
      expect(op.path, isEmpty);
      expect(op.sourceAccount!.ed25519AccountId, sourceAccountId);
    });

    test('strictSend honors a custom destinationMinAmount', () {
      var tx = newBuilder()
          .strictSend(
              sendAssetId: nativeAsset,
              sendAmount: "100",
              destinationAddress: destinationAccountId,
              destinationAssetId: usdAsset,
              destinationMinAmount: "5.5")
          .build();
      var op =
          tx.operations.first as flutter_sdk.PathPaymentStrictSendOperation;
      expect(op.destMin, "5.5");
    });

    test('strictSend includes the provided asset path', () {
      var intermediate =
          IssuedAssetId(code: "EUR", issuer: issuerAccountId);
      var tx = newBuilder()
          .strictSend(
              sendAssetId: nativeAsset,
              sendAmount: "100",
              destinationAddress: destinationAccountId,
              destinationAssetId: usdAsset,
              path: [intermediate])
          .build();
      var op =
          tx.operations.first as flutter_sdk.PathPaymentStrictSendOperation;
      expect(op.path.length, 1);
      var pathAsset = op.path.first as flutter_sdk.AssetTypeCreditAlphaNum;
      expect(pathAsset.code, "EUR");
    });
  });

  group('TxBuilder strictReceive Tests', () {
    test('strictReceive uses default sendMaxAmount int64 max', () {
      var tx = newBuilder()
          .strictReceive(
              sendAssetId: nativeAsset,
              destinationAddress: destinationAccountId,
              destinationAssetId: usdAsset,
              destinationAmount: "42",
              sendMaxAmount: null)
          .build();

      expect(tx.operations.length, 1);
      var op =
          tx.operations.first as flutter_sdk.PathPaymentStrictReceiveOperation;
      expect(op.destAmount, "42");
      expect(op.sendMax, maxAmount);
      expect(op.destination.ed25519AccountId, destinationAccountId);
      expect(op.sourceAccount!.ed25519AccountId, sourceAccountId);
    });

    test('strictReceive honors a custom sendMaxAmount', () {
      var tx = newBuilder()
          .strictReceive(
              sendAssetId: nativeAsset,
              destinationAddress: destinationAccountId,
              destinationAssetId: usdAsset,
              destinationAmount: "42",
              sendMaxAmount: "500.25")
          .build();
      var op =
          tx.operations.first as flutter_sdk.PathPaymentStrictReceiveOperation;
      expect(op.sendMax, "500.25");
    });
  });

  group('TxBuilder pathPay Tests', () {
    test('pathPay routes to strictSend when sendAmount is given', () {
      var tx = newBuilder()
          .pathPay(
              destinationAddress: destinationAccountId,
              sendAsset: nativeAsset,
              destinationAsset: usdAsset,
              sendAmount: "100")
          .build();

      var op = tx.operations.first;
      expect(op, isA<flutter_sdk.PathPaymentStrictSendOperation>());
      var sendOp = op as flutter_sdk.PathPaymentStrictSendOperation;
      expect(sendOp.sendAmount, "100");
      expect(sendOp.destMin, "0.0000001");
    });

    test('pathPay routes to strictReceive when destAmount is given', () {
      var tx = newBuilder()
          .pathPay(
              destinationAddress: destinationAccountId,
              sendAsset: nativeAsset,
              destinationAsset: usdAsset,
              destAmount: "100")
          .build();

      var op = tx.operations.first;
      expect(op, isA<flutter_sdk.PathPaymentStrictReceiveOperation>());
      var recvOp = op as flutter_sdk.PathPaymentStrictReceiveOperation;
      expect(recvOp.destAmount, "100");
      expect(recvOp.sendMax, maxAmount);
    });

    test('pathPay forwards destMin to strictSend', () {
      var tx = newBuilder()
          .pathPay(
              destinationAddress: destinationAccountId,
              sendAsset: nativeAsset,
              destinationAsset: usdAsset,
              sendAmount: "100",
              destMin: "7.7")
          .build();
      var op = tx.operations.first as flutter_sdk.PathPaymentStrictSendOperation;
      expect(op.destMin, "7.7");
    });

    test('pathPay forwards sendMax to strictReceive', () {
      var tx = newBuilder()
          .pathPay(
              destinationAddress: destinationAccountId,
              sendAsset: nativeAsset,
              destinationAsset: usdAsset,
              destAmount: "100",
              sendMax: "9.9")
          .build();
      var op =
          tx.operations.first as flutter_sdk.PathPaymentStrictReceiveOperation;
      expect(op.sendMax, "9.9");
    });

    test('pathPay throws when both sendAmount and destAmount are given', () {
      expect(
          () => newBuilder().pathPay(
              destinationAddress: destinationAccountId,
              sendAsset: nativeAsset,
              destinationAsset: usdAsset,
              sendAmount: "100",
              destAmount: "100"),
          throwsA(isA<PathPayOnlyOneAmountException>()));
    });

    test('pathPay throws when neither sendAmount nor destAmount is given', () {
      expect(
          () => newBuilder().pathPay(
              destinationAddress: destinationAccountId,
              sendAsset: nativeAsset,
              destinationAsset: usdAsset),
          throwsA(isA<PathPayOnlyOneAmountException>()));
    });
  });

  group('TxBuilder swap Tests', () {
    test('swap builds a strictSend to the source account', () {
      var tx = newBuilder()
          .swap(fromAsset: nativeAsset, toAsset: usdAsset, amount: "50")
          .build();

      expect(tx.operations.length, 1);
      var op =
          tx.operations.first as flutter_sdk.PathPaymentStrictSendOperation;
      expect(op.sendAmount, "50");
      // swap destination is the source account itself.
      expect(op.destination.ed25519AccountId, sourceAccountId);
      expect(op.sendAsset, isA<flutter_sdk.AssetTypeNative>());
      var destAsset = op.destAsset as flutter_sdk.AssetTypeCreditAlphaNum;
      expect(destAsset.code, "USD");
      expect(op.destMin, "0.0000001");
    });

    test('swap forwards destMin', () {
      var tx = newBuilder()
          .swap(
              fromAsset: nativeAsset,
              toAsset: usdAsset,
              amount: "50",
              destMin: "49.5")
          .build();
      var op =
          tx.operations.first as flutter_sdk.PathPaymentStrictSendOperation;
      expect(op.destMin, "49.5");
    });
  });

  group('TxBuilder addOperation Tests', () {
    test('addOperation appends a pre-built operation', () {
      var manualOp = flutter_sdk.PaymentOperationBuilder(
              destinationAccountId, flutter_sdk.Asset.NATIVE, "3.3")
          .setSourceAccount(sourceAccountId)
          .build();
      var tx = newBuilder().addOperation(manualOp).build();

      expect(tx.operations.length, 1);
      expect(identical(tx.operations.first, manualOp), isTrue);
    });

    test('operations are kept in insertion order', () {
      var builder = newBuilder();
      builder.lockAccountMasterKey();
      builder.transfer(destinationAccountId, nativeAsset, "1");
      var tx = builder.build();

      expect(tx.operations.length, 2);
      expect(tx.operations[0], isA<flutter_sdk.SetOptionsOperation>());
      expect(tx.operations[1], isA<flutter_sdk.PaymentOperation>());
    });
  });

  group('TxBuilder sponsoring Tests', () {
    test('sponsoring wraps inner ops with begin/end in order', () {
      var newAccount = PublicKeyPair.fromAccountId(destinationAccountId);
      var sponsor = PublicKeyPair.fromAccountId(sponsorAccountId);

      var tx = newBuilder().sponsoring(sponsor, (builder) {
        builder.createAccount(newAccount);
      }).build();

      // begin + 1 inner + end
      expect(tx.operations.length, 3);
      expect(tx.operations[0],
          isA<flutter_sdk.BeginSponsoringFutureReservesOperation>());
      expect(tx.operations[1], isA<flutter_sdk.CreateAccountOperation>());
      expect(tx.operations[2],
          isA<flutter_sdk.EndSponsoringFutureReservesOperation>());

      var beginOp = tx.operations[0]
          as flutter_sdk.BeginSponsoringFutureReservesOperation;
      // default sponsored account is the builder source account.
      expect(beginOp.sponsoredId, sourceAccountId);
      expect(beginOp.sourceAccount!.ed25519AccountId, sponsorAccountId);

      var endOp = tx.operations[2]
          as flutter_sdk.EndSponsoringFutureReservesOperation;
      expect(endOp.sourceAccount!.ed25519AccountId, sourceAccountId);
    });

    test('sponsoring uses an explicit sponsored account', () {
      var newAccount = PublicKeyPair.fromAccountId(destinationAccountId);
      var sponsor = PublicKeyPair.fromAccountId(sponsorAccountId);
      var sponsored = PublicKeyPair.fromAccountId(signerAccountId);

      var tx = newBuilder().sponsoring(sponsor, (builder) {
        builder.createAccount(newAccount);
      }, sponsoredAccount: sponsored).build();

      var beginOp = tx.operations[0]
          as flutter_sdk.BeginSponsoringFutureReservesOperation;
      expect(beginOp.sponsoredId, signerAccountId);
      var endOp = tx.operations[2]
          as flutter_sdk.EndSponsoringFutureReservesOperation;
      expect(endOp.sourceAccount!.ed25519AccountId, signerAccountId);
    });

    test('sponsoring supports multiple inner operations in order', () {
      var newAccount = PublicKeyPair.fromAccountId(destinationAccountId);
      var sponsor = PublicKeyPair.fromAccountId(sponsorAccountId);

      var tx = newBuilder().sponsoring(sponsor, (builder) {
        builder.createAccount(newAccount);
        builder.addAssetSupport(usdAsset);
      }).build();

      // begin + 2 inner + end
      expect(tx.operations.length, 4);
      expect(tx.operations[1], isA<flutter_sdk.CreateAccountOperation>());
      expect(tx.operations[2], isA<flutter_sdk.ChangeTrustOperation>());
    });

    test('sponsoring inner createAccount sets source to sponsor account', () {
      var newAccount = PublicKeyPair.fromAccountId(destinationAccountId);
      var sponsor = PublicKeyPair.fromAccountId(sponsorAccountId);

      var tx = newBuilder().sponsoring(sponsor, (builder) {
        builder.createAccount(newAccount);
      }).build();

      var createOp = tx.operations[1] as flutter_sdk.CreateAccountOperation;
      expect(createOp.sourceAccount!.ed25519AccountId, sponsorAccountId);
      expect(createOp.destination, destinationAccountId);
    });
  });

  group('SponsoringBuilder Tests', () {
    test('createAccount defaults the starting balance to 0', () {
      var newAccount = PublicKeyPair.fromAccountId(destinationAccountId);
      var sponsor = PublicKeyPair.fromAccountId(sponsorAccountId);
      var builderAccount =
          flutter_sdk.Account(destinationAccountId, BigInt.zero);
      var sb = SponsoringBuilder(builderAccount, sponsor);

      sb.createAccount(newAccount);
      var tx = sb.build();

      expect(tx.operations.length, 1);
      var op = tx.operations.first as flutter_sdk.CreateAccountOperation;
      expect(op.startingBalance, "0");
      expect(op.sourceAccount!.ed25519AccountId, sponsorAccountId);
    });

    test('createAccount throws for a negative starting balance', () {
      var newAccount = PublicKeyPair.fromAccountId(destinationAccountId);
      var sponsor = PublicKeyPair.fromAccountId(sponsorAccountId);
      var builderAccount =
          flutter_sdk.Account(destinationAccountId, BigInt.zero);
      var sb = SponsoringBuilder(builderAccount, sponsor);

      expect(() => sb.createAccount(newAccount, startingBalance: "-1"),
          throwsA(isA<InvalidStartingBalanceException>()));
    });

    test('createAccount accepts an explicit positive starting balance', () {
      var newAccount = PublicKeyPair.fromAccountId(destinationAccountId);
      var sponsor = PublicKeyPair.fromAccountId(sponsorAccountId);
      var builderAccount =
          flutter_sdk.Account(destinationAccountId, BigInt.zero);
      var sb = SponsoringBuilder(builderAccount, sponsor);

      sb.createAccount(newAccount, startingBalance: "10");
      var tx = sb.build();
      var op = tx.operations.first as flutter_sdk.CreateAccountOperation;
      expect(op.startingBalance, "10");
    });
  });

  group('TxBuilder Sequence Number Tests', () {
    test('build uses the incremented sequence number', () {
      var account = flutter_sdk.Account(sourceAccountId, BigInt.from(41));
      var tx = TxBuilder(account).lockAccountMasterKey().build();
      expect(tx.sequenceNumber, BigInt.from(42));
    });

    test('building twice increments the sequence number each time', () {
      var account = flutter_sdk.Account(sourceAccountId, BigInt.from(100));
      var builder = TxBuilder(account);

      var tx1 = builder.lockAccountMasterKey().build();
      var tx2 = builder.build();

      expect(tx1.sequenceNumber, BigInt.from(101));
      expect(tx2.sequenceNumber, BigInt.from(102));
      // the underlying account sequence has advanced by two.
      expect(account.sequenceNumber, BigInt.from(102));
    });

    test('sequence numbers above 2^53 are preserved exactly', () {
      // 2^53 + 1 is the first integer not exactly representable as a double.
      var startSeq = BigInt.parse("9007199254740993");
      var account = flutter_sdk.Account(sourceAccountId, startSeq);
      var tx = TxBuilder(account).lockAccountMasterKey().build();

      expect(tx.sequenceNumber, startSeq + BigInt.one);
      expect(tx.sequenceNumber, BigInt.parse("9007199254740994"));
    });

    test('a very large sequence number round-trips through XDR', () {
      var startSeq = BigInt.parse("9223372036854775806"); // int64 max - 1
      var account = flutter_sdk.Account(sourceAccountId, startSeq);
      var tx = TxBuilder(account).lockAccountMasterKey().build();

      expect(tx.sequenceNumber, BigInt.parse("9223372036854775807"));

      var base64 = tx.toEnvelopeXdrBase64();
      expect(base64, isNotEmpty);
      var decoded = flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(base64)
          as flutter_sdk.Transaction;
      expect(decoded.sequenceNumber, BigInt.parse("9223372036854775807"));
    });
  });

  group('TxBuilder XDR Round-Trip Tests', () {
    test('payment with max amount round-trips through XDR', () {
      var tx = newBuilder()
          .transfer(destinationAccountId, usdAsset, maxAmount)
          .build();

      var base64 = tx.toEnvelopeXdrBase64();
      expect(base64, isNotEmpty);

      var decoded = flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(base64)
          as flutter_sdk.Transaction;
      expect(decoded.operations.length, 1);
      var op = decoded.operations.first as flutter_sdk.PaymentOperation;
      expect(op.amount, maxAmount);
    });

    test('payment with min amount round-trips through XDR', () {
      var tx = newBuilder()
          .transfer(destinationAccountId, usdAsset, minAmount)
          .build();

      var base64 = tx.toEnvelopeXdrBase64();
      var decoded = flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(base64)
          as flutter_sdk.Transaction;
      var op = decoded.operations.first as flutter_sdk.PaymentOperation;
      // The canonical form of ".0000001" is "0.0000001".
      expect(op.amount, "0.0000001");
    });
  });
}
