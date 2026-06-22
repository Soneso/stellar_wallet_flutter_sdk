// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

/// Unit tests for the pure model/mapper and status logic in
/// lib/src/anchor/sep_24.dart and lib/src/anchor/anchor.dart.
///
/// These tests construct base-SDK response objects inline (no network) and
/// verify the mapping/dispatch/status logic of the wallet SDK.
void main() {
  // A valid (decodable) SEP-10 JWT, reused from the existing interactive tests.
  // Required because AuthToken decodes the JWT in its constructor.
  const jwtToken =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0";

  /// Builds a base-SDK [flutter_sdk.SEP24Transaction] with the given values.
  /// All optional fields default to null unless overridden so that each test
  /// can focus on the fields it asserts on.
  flutter_sdk.SEP24Transaction buildTx({
    required String id,
    required String kind,
    required String status,
    required String startedAt,
    int? statusEta,
    bool? kycVerified,
    String? moreInfoUrl,
    String? amountIn,
    String? amountInAsset,
    String? amountOut,
    String? amountOutAsset,
    String? amountFee,
    String? amountFeeAsset,
    String? quoteId,
    String? completedAt,
    String? updatedAt,
    String? userActionRequiredBy,
    String? stellarTransactionId,
    String? externalTransactionId,
    String? message,
    bool? refunded,
    flutter_sdk.Refund? refunds,
    String? from,
    String? to,
    String? depositMemo,
    String? depositMemoType,
    String? claimableBalanceId,
    String? withdrawAnchorAccount,
    String? withdrawMemo,
    String? withdrawMemoType,
  }) {
    return flutter_sdk.SEP24Transaction(
      id,
      kind,
      status,
      statusEta,
      kycVerified,
      moreInfoUrl,
      amountIn,
      amountInAsset,
      amountOut,
      amountOutAsset,
      amountFee,
      amountFeeAsset,
      quoteId,
      startedAt,
      completedAt,
      updatedAt,
      userActionRequiredBy,
      stellarTransactionId,
      externalTransactionId,
      message,
      refunded,
      refunds,
      from,
      to,
      depositMemo,
      depositMemoType,
      claimableBalanceId,
      withdrawAnchorAccount,
      withdrawMemo,
      withdrawMemoType,
    );
  }

  group('TransactionStatus Tests', () {
    test('value getter returns the underlying status string', () {
      expect(TransactionStatus.completed.value, "completed");
      expect(TransactionStatus.incomplete.value, "incomplete");
      expect(TransactionStatus.noMarket.value, "no_market");
      expect(TransactionStatus.pendingUserTransferStart.value,
          "pending_user_transfer_start");
    });

    test('toString prefixes the value', () {
      expect(TransactionStatus.error.toString(), "TransactionStatus.error");
      expect(TransactionStatus.noMarket.toString(),
          "TransactionStatus.no_market");
    });

    test('equality compares by value, not identity', () {
      // A freshly constructed instance must equal the matching constant.
      expect(TransactionStatus("completed"), equals(TransactionStatus.completed));
      expect(TransactionStatus("error"), equals(TransactionStatus.error));
      expect(TransactionStatus("no_market"), equals(TransactionStatus.noMarket));
      // Distinct values are not equal.
      expect(TransactionStatus.completed == TransactionStatus.refunded, isFalse);
      // Equal values share the same hashCode.
      expect(TransactionStatus("completed").hashCode,
          TransactionStatus.completed.hashCode);
    });

    test('isError is true only for error, no_market, too_large, too_small', () {
      expect(TransactionStatus.error.isError(), isTrue);
      expect(TransactionStatus.noMarket.isError(), isTrue);
      expect(TransactionStatus.tooLarge.isError(), isTrue);
      expect(TransactionStatus.tooSmall.isError(), isTrue);

      expect(TransactionStatus.completed.isError(), isFalse);
      expect(TransactionStatus.refunded.isError(), isFalse);
      expect(TransactionStatus.expired.isError(), isFalse);
      expect(TransactionStatus.incomplete.isError(), isFalse);
      expect(TransactionStatus.pendingAnchor.isError(), isFalse);
    });

    test('isTerminal is true for completed, refunded, expired and all errors',
        () {
      expect(TransactionStatus.completed.isTerminal(), isTrue);
      expect(TransactionStatus.refunded.isTerminal(), isTrue);
      expect(TransactionStatus.expired.isTerminal(), isTrue);
      // Errors are terminal too.
      expect(TransactionStatus.error.isTerminal(), isTrue);
      expect(TransactionStatus.noMarket.isTerminal(), isTrue);
      expect(TransactionStatus.tooLarge.isTerminal(), isTrue);
      expect(TransactionStatus.tooSmall.isTerminal(), isTrue);

      // Non-terminal (pending) states.
      expect(TransactionStatus.incomplete.isTerminal(), isFalse);
      expect(TransactionStatus.pendingAnchor.isTerminal(), isFalse);
      expect(TransactionStatus.pendingExternal.isTerminal(), isFalse);
      expect(TransactionStatus.pendingStellar.isTerminal(), isFalse);
      expect(TransactionStatus.pendingTrust.isTerminal(), isFalse);
      expect(TransactionStatus.pendingUser.isTerminal(), isFalse);
      expect(
          TransactionStatus.pendingUserTransferStart.isTerminal(), isFalse);
      expect(TransactionStatus.pendingUserTransferComplete.isTerminal(),
          isFalse);
    });

    test('fromString maps every known status string to its constant', () {
      expect(TransactionStatus.fromString("incomplete"),
          equals(TransactionStatus.incomplete));
      expect(TransactionStatus.fromString("pending_user_transfer_start"),
          equals(TransactionStatus.pendingUserTransferStart));
      expect(TransactionStatus.fromString("pending_user_transfer_complete"),
          equals(TransactionStatus.pendingUserTransferComplete));
      expect(TransactionStatus.fromString("pending_external"),
          equals(TransactionStatus.pendingExternal));
      expect(TransactionStatus.fromString("pending_anchor"),
          equals(TransactionStatus.pendingAnchor));
      expect(TransactionStatus.fromString("pending_stellar"),
          equals(TransactionStatus.pendingStellar));
      expect(TransactionStatus.fromString("pending_trust"),
          equals(TransactionStatus.pendingTrust));
      expect(TransactionStatus.fromString("pending_user"),
          equals(TransactionStatus.pendingUser));
      expect(TransactionStatus.fromString("pending_customer_info_update"),
          equals(TransactionStatus.pendingCustomerInfoUpdate));
      expect(TransactionStatus.fromString("pending_transaction_info_update"),
          equals(TransactionStatus.pendingTransactionInfoUpdate));
      expect(TransactionStatus.fromString("completed"),
          equals(TransactionStatus.completed));
      expect(TransactionStatus.fromString("refunded"),
          equals(TransactionStatus.refunded));
      expect(TransactionStatus.fromString("expired"),
          equals(TransactionStatus.expired));
      expect(TransactionStatus.fromString("too_small"),
          equals(TransactionStatus.tooSmall));
      expect(TransactionStatus.fromString("too_large"),
          equals(TransactionStatus.tooLarge));
      expect(TransactionStatus.fromString("error"),
          equals(TransactionStatus.error));
    });

    test('fromString returns null for unknown or null input', () {
      expect(TransactionStatus.fromString("not_a_status"), isNull);
      expect(TransactionStatus.fromString(null), isNull);
      expect(TransactionStatus.fromString(""), isNull);
    });

    // SUSPECTED BUG (asserts correct behavior; expected to FAIL):
    // anchor.dart TransactionStatus.fromString lacks a branch for "no_market",
    // although the noMarket constant exists and isError() treats it as an error.
    // The mapping must be symmetric: every status constant must round-trip
    // through fromString. fromString("no_market") must return the noMarket
    // constant, not null.
    test('fromString maps "no_market" to the noMarket constant', () {
      expect(TransactionStatus.fromString("no_market"),
          equals(TransactionStatus.noMarket));
    });
  });

  group('MemoType Tests', () {
    test('value getter returns the underlying memo type string', () {
      expect(MemoType.text.value, "text");
      expect(MemoType.hash.value, "hash");
      expect(MemoType.id.value, "id");
    });

    test('toString prefixes the value', () {
      expect(MemoType.text.toString(), "MemoType.text");
      expect(MemoType.id.toString(), "MemoType.id");
    });

    test('equality compares by value, not identity', () {
      expect(MemoType("text"), equals(MemoType.text));
      expect(MemoType("hash"), equals(MemoType.hash));
      expect(MemoType("id"), equals(MemoType.id));
      expect(MemoType.text == MemoType.hash, isFalse);
      expect(MemoType("id").hashCode, MemoType.id.hashCode);
    });
  });

  group('Sep24Transaction.fromTx Dispatch Tests', () {
    test('withdrawal + incomplete dispatches to IncompleteWithdrawalTransaction',
        () {
      final tx = buildTx(
          id: "w-inc",
          kind: "withdrawal",
          status: "incomplete",
          startedAt: "2021-01-01T10:00:00Z",
          from: "GFROM");
      final result = Sep24Transaction.fromTx(tx);
      expect(result, isA<IncompleteWithdrawalTransaction>());
    });

    test('withdrawal + error dispatches to ErrorTransaction (withdrawal kind)',
        () {
      final tx = buildTx(
          id: "w-err",
          kind: "withdrawal",
          status: "error",
          startedAt: "2021-01-01T10:00:00Z");
      final result = Sep24Transaction.fromTx(tx);
      expect(result, isA<ErrorTransaction>());
      expect((result as ErrorTransaction).kind, TransactionKind.withdrawal);
    });

    test('withdrawal + non-error/non-incomplete dispatches to WithdrawalTransaction',
        () {
      final tx = buildTx(
          id: "w-ok",
          kind: "withdrawal",
          status: "completed",
          startedAt: "2021-01-01T10:00:00Z");
      final result = Sep24Transaction.fromTx(tx);
      expect(result, isA<WithdrawalTransaction>());
    });

    test('deposit + incomplete dispatches to IncompleteDepositTransaction', () {
      final tx = buildTx(
          id: "d-inc",
          kind: "deposit",
          status: "incomplete",
          startedAt: "2021-01-01T10:00:00Z",
          to: "GTO");
      final result = Sep24Transaction.fromTx(tx);
      expect(result, isA<IncompleteDepositTransaction>());
    });

    test('deposit + error dispatches to ErrorTransaction (deposit kind)', () {
      final tx = buildTx(
          id: "d-err",
          kind: "deposit",
          status: "error",
          startedAt: "2021-01-01T10:00:00Z");
      final result = Sep24Transaction.fromTx(tx);
      expect(result, isA<ErrorTransaction>());
      expect((result as ErrorTransaction).kind, TransactionKind.deposit);
    });

    test('deposit + non-error/non-incomplete dispatches to DepositTransaction',
        () {
      final tx = buildTx(
          id: "d-ok",
          kind: "deposit",
          status: "pending_anchor",
          startedAt: "2021-01-01T10:00:00Z");
      final result = Sep24Transaction.fromTx(tx);
      expect(result, isA<DepositTransaction>());
    });

    test('unknown kind throws InvalidDataException', () {
      final tx = buildTx(
          id: "x",
          kind: "exchange",
          status: "completed",
          startedAt: "2021-01-01T10:00:00Z");
      expect(() => Sep24Transaction.fromTx(tx),
          throwsA(isA<InvalidDataException>()));
    });
  });

  group('DepositTransaction Mapping Tests', () {
    test('fromTx maps base fields and parses startedAt to a real date', () {
      final tx = buildTx(
          id: "dep-1",
          kind: "deposit",
          status: "pending_anchor",
          startedAt: "2021-06-15T12:30:45Z",
          moreInfoUrl: "https://anchor.example/tx/dep-1",
          amountIn: "100.50",
          amountOut: "99.00",
          amountFee: "1.50",
          message: "processing deposit");

      final result = DepositTransaction.fromTx(tx);

      expect(result.id, "dep-1");
      expect(result.status, equals(TransactionStatus.pendingAnchor));
      // Constructor-ordering guard: startedAt must be the parsed date and
      // moreInfoUrl must be the URL (not swapped).
      expect(result.startedAt,
          DateTime.parse("2021-06-15T12:30:45Z"));
      expect(result.startedAt.isUtc, isTrue);
      expect(result.moreInfoUrl, "https://anchor.example/tx/dep-1");
      expect(result.amountIn, "100.50");
      expect(result.amountOut, "99.00");
      expect(result.amountFee, "1.50");
      expect(result.message, "processing deposit");
    });

    test('fromTx fills deposit-specific and processing optional fields', () {
      final refund = flutter_sdk.Refund("10", "1", [
        flutter_sdk.RefundPayment("pay-1", "stellar", "10", "1"),
      ]);
      final tx = buildTx(
          id: "dep-2",
          kind: "deposit",
          status: "completed",
          startedAt: "2021-06-15T12:30:45Z",
          completedAt: "2021-06-15T13:00:00Z",
          updatedAt: "2021-06-15T12:45:00Z",
          userActionRequiredBy: "2021-06-16T00:00:00Z",
          statusEta: 3600,
          kycVerified: true,
          amountInAsset: "iso4217:USD",
          amountOutAsset: "stellar:USDC:GISSUER",
          amountFeeAsset: "iso4217:USD",
          stellarTransactionId: "stellar-tx-id",
          externalTransactionId: "ext-tx-id",
          from: "bank-account",
          to: "GDEST",
          depositMemo: "memo-value",
          depositMemoType: "text",
          claimableBalanceId: "cb-id",
          refunds: refund);

      final result = DepositTransaction.fromTx(tx);

      expect(result.statusEta, 3600);
      expect(result.kycVerified, isTrue);
      expect(result.amountInAsset, "iso4217:USD");
      expect(result.amountOutAsset, "stellar:USDC:GISSUER");
      expect(result.amountFeeAsset, "iso4217:USD");
      expect(result.completedAt, DateTime.parse("2021-06-15T13:00:00Z"));
      expect(result.updatedAt, DateTime.parse("2021-06-15T12:45:00Z"));
      expect(
          result.userActionRequiredBy, DateTime.parse("2021-06-16T00:00:00Z"));
      expect(result.stellarTransactionId, "stellar-tx-id");
      expect(result.externalTransactionId, "ext-tx-id");
      expect(result.from, "bank-account");
      expect(result.to, "GDEST");
      expect(result.depositMemo, "memo-value");
      expect(result.depositMemoType, "text");
      expect(result.claimableBalanceId, "cb-id");
      expect(result.refunds, isNotNull);
      expect(result.refunds!.amountRefunded, "10");
      expect(result.refunds!.amountFee, "1");
      expect(result.refunds!.payments.length, 1);
      expect(result.refunds!.payments.first.id, "pay-1");
      expect(result.refunds!.payments.first.idType, "stellar");
      expect(result.refunds!.payments.first.amount, "10");
      expect(result.refunds!.payments.first.fee, "1");
    });
  });

  group('WithdrawalTransaction Mapping Tests', () {
    test('fromTx maps base fields and parses startedAt to a real date', () {
      final tx = buildTx(
          id: "wd-1",
          kind: "withdrawal",
          status: "pending_user_transfer_start",
          startedAt: "2022-02-02T08:15:30Z",
          moreInfoUrl: "https://anchor.example/tx/wd-1",
          amountIn: "510",
          amountOut: "490",
          amountFee: "20",
          message: "awaiting transfer");

      final result = WithdrawalTransaction.fromTx(tx);

      expect(result.id, "wd-1");
      expect(result.status,
          equals(TransactionStatus.pendingUserTransferStart));
      // Constructor-ordering guard: the WithdrawalTransaction constructor
      // declares its super parameters in a different positional order, but
      // Dart binds super parameters by name. startedAt must hold the parsed
      // date and moreInfoUrl must hold the URL.
      expect(result.startedAt, DateTime.parse("2022-02-02T08:15:30Z"));
      expect(result.startedAt.isUtc, isTrue);
      expect(result.moreInfoUrl, "https://anchor.example/tx/wd-1");
      expect(result.amountIn, "510");
      expect(result.amountOut, "490");
      expect(result.amountFee, "20");
      expect(result.message, "awaiting transfer");
    });

    test('fromTx fills withdrawal-specific optional fields', () {
      final tx = buildTx(
          id: "wd-2",
          kind: "withdrawal",
          status: "completed",
          startedAt: "2022-02-02T08:15:30Z",
          from: "GSOURCE",
          to: "bank-account",
          withdrawAnchorAccount: "GANCHOR",
          withdrawMemo: "186384",
          withdrawMemoType: "id");

      final result = WithdrawalTransaction.fromTx(tx);

      expect(result.from, "GSOURCE");
      expect(result.to, "bank-account");
      expect(result.withdrawAnchorAccount, "GANCHOR");
      expect(result.withdrawalMemo, "186384");
      expect(result.withdrawalMemoType, "id");
    });
  });

  group('Incomplete Transaction Mapping Tests', () {
    test(
        'IncompleteWithdrawalTransaction.fromTx maps id, status, startedAt, moreInfoUrl, from',
        () {
      final tx = buildTx(
          id: "iw-1",
          kind: "withdrawal",
          status: "incomplete",
          startedAt: "2023-03-03T03:03:03Z",
          moreInfoUrl: "https://anchor.example/tx/iw-1",
          message: "needs info",
          from: "GFROM");

      final result = IncompleteWithdrawalTransaction.fromTx(tx);

      expect(result.id, "iw-1");
      expect(result.status, equals(TransactionStatus.incomplete));
      // Constructor-ordering guard.
      expect(result.startedAt, DateTime.parse("2023-03-03T03:03:03Z"));
      expect(result.startedAt.isUtc, isTrue);
      expect(result.moreInfoUrl, "https://anchor.example/tx/iw-1");
      expect(result.message, "needs info");
      expect(result.from, "GFROM");
    });

    test(
        'IncompleteDepositTransaction.fromTx maps id, status, startedAt, moreInfoUrl, to',
        () {
      final tx = buildTx(
          id: "id-1",
          kind: "deposit",
          status: "incomplete",
          startedAt: "2023-04-04T04:04:04Z",
          moreInfoUrl: "https://anchor.example/tx/id-1",
          message: "needs info",
          to: "GTO");

      final result = IncompleteDepositTransaction.fromTx(tx);

      expect(result.id, "id-1");
      expect(result.status, equals(TransactionStatus.incomplete));
      // Constructor-ordering guard.
      expect(result.startedAt, DateTime.parse("2023-04-04T04:04:04Z"));
      expect(result.startedAt.isUtc, isTrue);
      expect(result.moreInfoUrl, "https://anchor.example/tx/id-1");
      expect(result.message, "needs info");
      expect(result.to, "GTO");
    });
  });

  group('ErrorTransaction Mapping Tests', () {
    test('fromTx maps base fields, kind, and parses startedAt', () {
      final tx = buildTx(
          id: "err-1",
          kind: "withdrawal",
          status: "error",
          startedAt: "2024-05-05T05:05:05Z",
          moreInfoUrl: "https://anchor.example/tx/err-1",
          message: "something failed");

      final result = ErrorTransaction.fromTx(tx, TransactionKind.withdrawal);

      expect(result.id, "err-1");
      expect(result.kind, TransactionKind.withdrawal);
      expect(result.status, equals(TransactionStatus.error));
      // Constructor-ordering guard.
      expect(result.startedAt, DateTime.parse("2024-05-05T05:05:05Z"));
      expect(result.startedAt.isUtc, isTrue);
      expect(result.moreInfoUrl, "https://anchor.example/tx/err-1");
      expect(result.message, "something failed");
    });

    test('fromTx fills all optional error fields', () {
      final refund = flutter_sdk.Refund("5", "1", [
        flutter_sdk.RefundPayment("rp-1", "external", "5", "1"),
      ]);
      final tx = buildTx(
          id: "err-2",
          kind: "deposit",
          status: "error",
          startedAt: "2024-05-05T05:05:05Z",
          completedAt: "2024-05-05T06:00:00Z",
          updatedAt: "2024-05-05T05:30:00Z",
          userActionRequiredBy: "2024-05-06T00:00:00Z",
          statusEta: 60,
          kycVerified: false,
          amountIn: "200",
          amountInAsset: "iso4217:USD",
          amountOut: "190",
          amountOutAsset: "stellar:USDC:GISSUER",
          amountFee: "10",
          amountFeeAsset: "iso4217:USD",
          quoteId: "quote-9",
          stellarTransactionId: "s-tx",
          externalTransactionId: "e-tx",
          refunded: true,
          refunds: refund,
          from: "GFROM",
          to: "GTO",
          depositMemo: "dm",
          depositMemoType: "text",
          claimableBalanceId: "cb",
          withdrawMemo: "wm",
          withdrawMemoType: "id");

      final result = ErrorTransaction.fromTx(tx, TransactionKind.deposit);

      expect(result.kind, TransactionKind.deposit);
      expect(result.statusEta, 60);
      expect(result.kycVerified, isFalse);
      expect(result.amountIn, "200");
      expect(result.amountInAsset, "iso4217:USD");
      expect(result.amountOut, "190");
      expect(result.amountOutAsset, "stellar:USDC:GISSUER");
      expect(result.amountFee, "10");
      expect(result.amountFeeAsset, "iso4217:USD");
      expect(result.quoteId, "quote-9");
      expect(result.completedAt, DateTime.parse("2024-05-05T06:00:00Z"));
      expect(result.updatedAt, DateTime.parse("2024-05-05T05:30:00Z"));
      expect(
          result.userActionRequiredBy, DateTime.parse("2024-05-06T00:00:00Z"));
      expect(result.stellarTransactionId, "s-tx");
      expect(result.externalTransactionId, "e-tx");
      expect(result.refunded, isTrue);
      expect(result.refunds, isNotNull);
      expect(result.refunds!.amountRefunded, "5");
      expect(result.refunds!.payments.first.idType, "external");
      expect(result.from, "GFROM");
      expect(result.to, "GTO");
      expect(result.depositMemo, "dm");
      expect(result.depositMemoType, "text");
      expect(result.claimableBalanceId, "cb");
      expect(result.withdrawalMemo, "wm");
      expect(result.withdrawalMemoType, "id");
    });
  });

  group('ProcessingAnchorTransaction Date Parsing Tests', () {
    test('null optional dates pass through as null', () {
      final tx = buildTx(
          id: "p-1",
          kind: "deposit",
          status: "pending_anchor",
          startedAt: "2021-01-01T00:00:00Z");

      final result = DepositTransaction.fromTx(tx);

      expect(result.completedAt, isNull);
      expect(result.updatedAt, isNull);
      expect(result.userActionRequiredBy, isNull);
      expect(result.refunds, isNull);
      // startedAt is mandatory and must always be parsed.
      expect(result.startedAt, DateTime.parse("2021-01-01T00:00:00Z"));
    });

    test('present optional dates are parsed independently', () {
      final tx = buildTx(
          id: "p-2",
          kind: "deposit",
          status: "completed",
          startedAt: "2021-01-01T00:00:00Z",
          completedAt: "2021-01-02T00:00:00Z",
          updatedAt: "2021-01-01T12:00:00Z");

      final result = DepositTransaction.fromTx(tx);

      expect(result.completedAt, DateTime.parse("2021-01-02T00:00:00Z"));
      expect(result.updatedAt, DateTime.parse("2021-01-01T12:00:00Z"));
      expect(result.userActionRequiredBy, isNull);
    });
  });

  group('AnchorServiceInfo.from Tests', () {
    test('null deposit/withdraw maps produce empty maps', () {
      final info = flutter_sdk.SEP24InfoResponse(null, null, null, null);
      final result = AnchorServiceInfo.from(info);

      expect(result.deposit, isEmpty);
      expect(result.withdraw, isEmpty);
    });

    test('fee defaults to disabled when feeEndpointInfo is null', () {
      final info = flutter_sdk.SEP24InfoResponse(null, null, null, null);
      final result = AnchorServiceInfo.from(info);

      expect(result.fee.enabled, isFalse);
      expect(result.fee.authenticationRequired, isFalse);
    });

    test('features is null when featureFlags is null', () {
      final info = flutter_sdk.SEP24InfoResponse(null, null, null, null);
      final result = AnchorServiceInfo.from(info);

      expect(result.features, isNull);
    });

    test('maps deposit and withdraw assets, fee and features when present', () {
      final depositAssets = <String, flutter_sdk.SEP24DepositAsset>{
        "USDC": flutter_sdk.SEP24DepositAsset(true, 0.1, 1000.0, 5.0, 1.0, null),
      };
      final withdrawAssets = <String, flutter_sdk.SEP24WithdrawAsset>{
        "USDC":
            flutter_sdk.SEP24WithdrawAsset(true, 0.2, 2000.0, null, 0.5, 5.0),
      };
      final feeInfo = flutter_sdk.FeeEndpointInfo(true, true);
      final flags = flutter_sdk.FeatureFlags(true, false);
      final info = flutter_sdk.SEP24InfoResponse(
          depositAssets, withdrawAssets, feeInfo, flags);

      final result = AnchorServiceInfo.from(info);

      expect(result.deposit.length, 1);
      final dep = result.deposit["USDC"]!;
      expect(dep.enabled, isTrue);
      expect(dep.minAmount, 0.1);
      expect(dep.maxAmount, 1000.0);
      expect(dep.feeFixed, 5.0);
      expect(dep.feePercent, 1.0);
      expect(dep.feeMinimum, isNull);

      expect(result.withdraw.length, 1);
      final wd = result.withdraw["USDC"]!;
      expect(wd.enabled, isTrue);
      expect(wd.minAmount, 0.2);
      expect(wd.maxAmount, 2000.0);
      expect(wd.feeFixed, isNull);
      expect(wd.feePercent, 0.5);
      expect(wd.feeMinimum, 5.0);

      expect(result.fee.enabled, isTrue);
      expect(result.fee.authenticationRequired, isTrue);

      expect(result.features, isNotNull);
      expect(result.features!.accountCreation, isTrue);
      expect(result.features!.claimableBalances, isFalse);
    });
  });

  group('AnchorServiceInfo Asset Getter Tests', () {
    // Build an AnchorServiceInfo whose deposit and withdraw maps are DISTINCT,
    // so that each getter can only be correct if it reads its OWN map.
    AnchorServiceInfo buildDistinctInfo() {
      final depositAsset = AnchorServiceAsset(true);
      depositAsset.minAmount = 1.0;
      depositAsset.maxAmount = 100.0;

      final withdrawAsset = AnchorServiceAsset(false);
      withdrawAsset.minAmount = 2.0;
      withdrawAsset.maxAmount = 200.0;

      // "USDC" exists ONLY in the deposit map.
      // "EURT" exists ONLY in the withdraw map.
      final deposit = <String, AnchorServiceAsset>{"USDC": depositAsset};
      final withdraw = <String, AnchorServiceAsset>{"EURT": withdrawAsset};
      final fee = AnchorServiceFee(false, false);
      return AnchorServiceInfo(deposit, withdraw, fee);
    }

    test('getWithdrawServiceAssetFor reads the withdraw map by issued code', () {
      final info = buildDistinctInfo();
      final eurt =
          IssuedAssetId(code: "EURT", issuer: "GISSUEREURT0000000000000000");

      final asset = info.getWithdrawServiceAssetFor(eurt);

      expect(asset, isNotNull);
      // Must be the withdraw-map asset (enabled=false, min=2, max=200).
      expect(asset!.enabled, isFalse);
      expect(asset.minAmount, 2.0);
      expect(asset.maxAmount, 200.0);
    });

    test('getWithdrawServiceAssetFor returns null for an asset only in deposit',
        () {
      final info = buildDistinctInfo();
      final usdc =
          IssuedAssetId(code: "USDC", issuer: "GISSUERUSDC0000000000000000");

      // USDC is not in the withdraw map -> must be null.
      expect(info.getWithdrawServiceAssetFor(usdc), isNull);
    });

    // REGRESSION GUARD: getDepositServiceAssetFor must read the DEPOSIT map.
    // With distinct deposit/withdraw maps, reading the wrong map yields the
    // wrong (or null) asset.
    test('getDepositServiceAssetFor reads the deposit map by issued code', () {
      final info = buildDistinctInfo();
      final usdc =
          IssuedAssetId(code: "USDC", issuer: "GISSUERUSDC0000000000000000");

      final asset = info.getDepositServiceAssetFor(usdc);

      expect(asset, isNotNull);
      // Must be the deposit-map asset (enabled=true, min=1, max=100).
      expect(asset!.enabled, isTrue);
      expect(asset.minAmount, 1.0);
      expect(asset.maxAmount, 100.0);
    });

    test('getDepositServiceAssetFor returns null for an asset only in withdraw',
        () {
      final info = buildDistinctInfo();
      final eurt =
          IssuedAssetId(code: "EURT", issuer: "GISSUEREURT0000000000000000");

      // EURT is not in the deposit map -> must be null.
      expect(info.getDepositServiceAssetFor(eurt), isNull);
    });

    test('getWithdrawServiceAssetFor uses "native" key for a NativeAssetId',
        () {
      final depositAsset = AnchorServiceAsset(true);
      final withdrawAsset = AnchorServiceAsset(true);
      final info = AnchorServiceInfo(
          <String, AnchorServiceAsset>{"native": depositAsset},
          <String, AnchorServiceAsset>{"native": withdrawAsset},
          AnchorServiceFee(false, false));

      expect(info.getWithdrawServiceAssetFor(NativeAssetId()),
          same(withdrawAsset));
    });

    // REGRESSION GUARD: the deposit getter must look up the NativeAssetId key
    // ("native") in the DEPOSIT map and return the deposit-map asset.
    test('getDepositServiceAssetFor uses "native" key for a NativeAssetId', () {
      final depositAsset = AnchorServiceAsset(true);
      final withdrawAsset = AnchorServiceAsset(true);
      final info = AnchorServiceInfo(
          <String, AnchorServiceAsset>{"native": depositAsset},
          <String, AnchorServiceAsset>{"native": withdrawAsset},
          AnchorServiceFee(false, false));

      expect(
          info.getDepositServiceAssetFor(NativeAssetId()), same(depositAsset));
    });
  });

  group('Sep24.getTransactionBy Validation Tests', () {
    test('throws ValidationException when all id parameters are null', () async {
      // The validation runs before any network call, so no mock is needed.
      final wallet = Wallet.testNet;
      final anchor = wallet.anchor("place.anchor.com");
      final sep24 = anchor.sep24();
      final authToken = AuthToken(jwtToken);

      expect(
        () => sep24.getTransactionBy(authToken),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
