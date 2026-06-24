// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

/// Component-level unit tests for the pure pieces of
/// lib/src/anchor/watcher.dart:
///
///  * [RetryContext] error/refresh bookkeeping.
///  * [RetryExceptionHandler.invoke] retry/backoff decision logic.
///  * [StatusChange] terminal/error delegation to [TransactionStatus].
///  * [WatcherResult.close] idempotent teardown of its controller and timer.
///
/// The full polling state machine ([Watcher.watchOneTransaction] /
/// [Watcher.watchAsset]) is intentionally not exercised here.

/// Minimal concrete [AnchorTransaction] used to build [StatusChange] instances
/// without depending on the shape of any concrete SEP-6/SEP-24 transaction.
class _FakeAnchorTransaction extends AnchorTransaction {
  _FakeAnchorTransaction(super.id, super.status);
}

void main() {
  group('RetryContext', () {
    test('starts with zero retries and no exception by default', () {
      final ctx = RetryContext();

      expect(ctx.retries, 0);
      expect(ctx.exception, isNull);
    });

    test('honors an explicit initial retry count', () {
      final ctx = RetryContext(retries: 2);

      expect(ctx.retries, 2);
      expect(ctx.exception, isNull);
    });

    test('onError increments retries and stores the exception', () {
      final ctx = RetryContext();
      final first = Exception('first failure');

      ctx.onError(first);

      expect(ctx.retries, 1);
      expect(ctx.exception, same(first));
    });

    test('onError accumulates retries and keeps the latest exception', () {
      final ctx = RetryContext();
      final first = Exception('first failure');
      final second = Exception('second failure');

      ctx.onError(first);
      ctx.onError(second);

      expect(ctx.retries, 2);
      expect(ctx.exception, same(second));
    });

    test('refresh resets retries to 0 and clears the exception', () {
      final ctx = RetryContext();
      ctx.onError(Exception('boom'));
      ctx.onError(Exception('boom again'));
      expect(ctx.retries, 2);

      ctx.refresh();

      expect(ctx.retries, 0);
      expect(ctx.exception, isNull);
    });

    test('can record errors again after a refresh', () {
      final ctx = RetryContext();
      ctx.onError(Exception('boom'));
      ctx.refresh();

      final next = Exception('after refresh');
      ctx.onError(next);

      expect(ctx.retries, 1);
      expect(ctx.exception, same(next));
    });
  });

  group('RetryExceptionHandler.invoke', () {
    test('has the documented default thresholds', () {
      final handler = RetryExceptionHandler();

      expect(handler.maxRetryCount, 3);
      expect(handler.backoffPeriod, const Duration(seconds: 5));
    });

    test('returns false (retry) while retries are below maxRetryCount', () {
      final handler = RetryExceptionHandler()..backoffPeriod = Duration.zero;

      for (var retries = 1; retries < handler.maxRetryCount; retries++) {
        final ctx = RetryContext(retries: retries);
        expect(handler.invoke(ctx), completion(isFalse),
            reason: 'retries=$retries is below maxRetryCount and must retry');
      }
    });

    test('returns true (give up) once retries reach maxRetryCount', () {
      final handler = RetryExceptionHandler()..backoffPeriod = Duration.zero;
      final ctx = RetryContext(retries: handler.maxRetryCount);

      expect(handler.invoke(ctx), completion(isTrue));
    });

    test('returns true (give up) once retries exceed maxRetryCount', () {
      final handler = RetryExceptionHandler()..backoffPeriod = Duration.zero;
      final ctx = RetryContext(retries: handler.maxRetryCount + 5);

      expect(handler.invoke(ctx), completion(isTrue));
    });

    test('respects a lowered maxRetryCount', () {
      final handler = RetryExceptionHandler()
        ..maxRetryCount = 1
        ..backoffPeriod = Duration.zero;

      expect(handler.invoke(RetryContext(retries: 0)), completion(isFalse));
      expect(handler.invoke(RetryContext(retries: 1)), completion(isTrue));
    });

    test('waits for the backoffPeriod before deciding to retry', () {
      fakeAsync((async) {
        final handler = RetryExceptionHandler()
          ..backoffPeriod = const Duration(seconds: 5);
        final ctx = RetryContext(retries: 1);

        bool? result;
        handler.invoke(ctx).then((value) => result = value);

        // The handler is awaiting Future.delayed(backoffPeriod); it must not
        // have completed yet.
        async.flushMicrotasks();
        expect(result, isNull,
            reason: 'invoke must await the backoff before returning false');

        // Advancing past the backoff lets the delayed future complete.
        async.elapse(const Duration(seconds: 5));
        expect(result, isFalse);
      });
    });

    test('does not wait on the backoffPeriod when giving up', () {
      fakeAsync((async) {
        final handler = RetryExceptionHandler()
          ..backoffPeriod = const Duration(days: 1);
        final ctx = RetryContext(retries: handler.maxRetryCount);

        bool? result;
        handler.invoke(ctx).then((value) => result = value);

        // No delay is awaited on the give-up path: only microtasks are needed.
        async.flushMicrotasks();
        expect(result, isTrue);
      });
    });
  });

  group('StatusChange', () {
    StatusChange buildChange(TransactionStatus status,
        {TransactionStatus? oldStatus}) {
      final tx = _FakeAnchorTransaction('tx-id', status);
      return StatusChange(tx, status, oldStatus: oldStatus);
    }

    test('exposes the transaction, status and oldStatus it was built with', () {
      final tx = _FakeAnchorTransaction('tx-id', TransactionStatus.pendingAnchor);
      final change = StatusChange(tx, TransactionStatus.pendingAnchor,
          oldStatus: TransactionStatus.incomplete);

      expect(change.transaction, same(tx));
      expect(change.status, TransactionStatus.pendingAnchor);
      expect(change.oldStatus, TransactionStatus.incomplete);
    });

    test('oldStatus defaults to null when omitted', () {
      final change = buildChange(TransactionStatus.incomplete);

      expect(change.oldStatus, isNull);
    });

    test('is a StatusUpdateEvent', () {
      expect(buildChange(TransactionStatus.completed), isA<StatusUpdateEvent>());
    });

    group('isTerminal delegates to the status', () {
      const terminalStatuses = <TransactionStatus>[
        TransactionStatus.completed,
        TransactionStatus.refunded,
        TransactionStatus.expired,
        TransactionStatus.error,
        TransactionStatus.noMarket,
        TransactionStatus.tooSmall,
        TransactionStatus.tooLarge,
      ];

      const nonTerminalStatuses = <TransactionStatus>[
        TransactionStatus.incomplete,
        TransactionStatus.pendingUserTransferStart,
        TransactionStatus.pendingUserTransferComplete,
        TransactionStatus.pendingExternal,
        TransactionStatus.pendingAnchor,
        TransactionStatus.pendingStellar,
        TransactionStatus.pendingTrust,
        TransactionStatus.pendingUser,
        TransactionStatus.pendingCustomerInfoUpdate,
        TransactionStatus.pendingTransactionInfoUpdate,
      ];

      for (final status in terminalStatuses) {
        test('${status.value} is terminal', () {
          final change = buildChange(status);
          expect(change.isTerminal(), isTrue);
          expect(change.isTerminal(), status.isTerminal());
        });
      }

      for (final status in nonTerminalStatuses) {
        test('${status.value} is not terminal', () {
          final change = buildChange(status);
          expect(change.isTerminal(), isFalse);
          expect(change.isTerminal(), status.isTerminal());
        });
      }
    });

    group('isError delegates to the status', () {
      const errorStatuses = <TransactionStatus>[
        TransactionStatus.error,
        TransactionStatus.noMarket,
        TransactionStatus.tooSmall,
        TransactionStatus.tooLarge,
      ];

      // Statuses that are terminal but not error: isError must be false even
      // though isTerminal is true.
      const terminalNonErrorStatuses = <TransactionStatus>[
        TransactionStatus.completed,
        TransactionStatus.refunded,
        TransactionStatus.expired,
      ];

      const nonErrorStatuses = <TransactionStatus>[
        TransactionStatus.incomplete,
        TransactionStatus.pendingAnchor,
        TransactionStatus.pendingUser,
      ];

      for (final status in errorStatuses) {
        test('${status.value} is an error', () {
          final change = buildChange(status);
          expect(change.isError(), isTrue);
          expect(change.isError(), status.isError());
        });
      }

      for (final status in terminalNonErrorStatuses) {
        test('${status.value} is terminal but not an error', () {
          final change = buildChange(status);
          expect(change.isTerminal(), isTrue);
          expect(change.isError(), isFalse);
        });
      }

      for (final status in nonErrorStatuses) {
        test('${status.value} is not an error', () {
          final change = buildChange(status);
          expect(change.isError(), isFalse);
          expect(change.isError(), status.isError());
        });
      }
    });
  });

  group('WatcherResult.close', () {
    test('closes the controller and cancels the timer', () {
      final controller = StreamController<StatusUpdateEvent>.broadcast();
      final timer = Timer.periodic(const Duration(hours: 1), (_) {});
      final result = WatcherResult(controller, timer);

      expect(controller.isClosed, isFalse);
      expect(timer.isActive, isTrue);

      result.close();

      expect(controller.isClosed, isTrue);
      expect(timer.isActive, isFalse);
    });

    test('is idempotent: a second close does not throw', () {
      final controller = StreamController<StatusUpdateEvent>.broadcast();
      final timer = Timer.periodic(const Duration(hours: 1), (_) {});
      final result = WatcherResult(controller, timer);

      result.close();

      expect(result.close, returnsNormally);
      expect(controller.isClosed, isTrue);
      expect(timer.isActive, isFalse);
    });

    test('does not throw when the controller is already closed', () async {
      final controller = StreamController<StatusUpdateEvent>.broadcast();
      final timer = Timer.periodic(const Duration(hours: 1), (_) {});
      final result = WatcherResult(controller, timer);

      await controller.close();
      expect(controller.isClosed, isTrue);
      expect(timer.isActive, isTrue);

      expect(result.close, returnsNormally);
      expect(timer.isActive, isFalse);
    });

    test('does not throw when the timer is already cancelled', () {
      final controller = StreamController<StatusUpdateEvent>.broadcast();
      final timer = Timer.periodic(const Duration(hours: 1), (_) {});
      final result = WatcherResult(controller, timer);

      timer.cancel();
      expect(timer.isActive, isFalse);
      expect(controller.isClosed, isFalse);

      expect(result.close, returnsNormally);
      expect(controller.isClosed, isTrue);
    });
  });

  group('Watcher state machine', () {
    Config cfg() =>
        Config(StellarConfiguration.testNet, ApplicationConfiguration());

    test('watchAsset keeps waiting when a poll returns no transactions', () {
      fakeAsync((async) {
        final anchor = _FakeAnchor(cfg());
        anchor.fakeSep24 = _FakeSep24(anchor, () async => <Sep24Transaction>[]);
        final watcher = Watcher(
            anchor,
            const Duration(seconds: 1),
            RetryExceptionHandler()..backoffPeriod = Duration.zero,
            WatcherKind.sep24);

        final events = <StatusUpdateEvent>[];
        final result =
            watcher.watchAsset(AuthToken(_testJwt()), NativeAssetId());
        result.controller.stream.listen(events.add);

        async.elapse(const Duration(seconds: 5));

        // An empty poll must not end the watch (the transaction may not exist
        // yet); the watcher keeps polling.
        expect(events.whereType<WatchCompleted>(), isEmpty);
        expect(events.whereType<ExceptionHandlerExit>(), isEmpty);
        expect(result.controller.isClosed, isFalse);
        result.close();
      });
    });

    test('watchAsset emits ExceptionHandlerExit when polling keeps failing',
        () {
      fakeAsync((async) {
        final anchor = _FakeAnchor(cfg());
        anchor.fakeSep24 =
            _FakeSep24(anchor, () async => throw Exception('horizon down'));
        final handler = RetryExceptionHandler()
          ..maxRetryCount = 2
          ..backoffPeriod = Duration.zero;
        final watcher = Watcher(
            anchor, const Duration(seconds: 1), handler, WatcherKind.sep24);

        final events = <StatusUpdateEvent>[];
        final result =
            watcher.watchAsset(AuthToken(_testJwt()), NativeAssetId());
        result.controller.stream.listen(events.add);

        async.elapse(const Duration(seconds: 5));

        // Repeated failures exhaust the retry handler and end the watch as an
        // error exit, not a normal completion.
        expect(events.whereType<ExceptionHandlerExit>(), isNotEmpty);
        expect(events.whereType<WatchCompleted>(), isEmpty);
        result.close();
      });
    });
  });
}

/// Builds an unsigned JWT sufficient for AuthToken construction in tests.
String _testJwt() {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${seg({'alg': 'none', 'typ': 'JWT'})}.'
      '${seg({'sub': 'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN', 'exp': 9999999999})}.sig';
}

/// A [Sep24] whose getTransactionsForAsset is driven by a supplied callback,
/// so the watcher polling loop can be exercised without any network.
class _FakeSep24 extends Sep24 {
  final Future<List<Sep24Transaction>> Function() onGetForAsset;
  _FakeSep24(Anchor anchor, this.onGetForAsset) : super(anchor);

  @override
  Future<List<Sep24Transaction>> getTransactionsForAsset(
          AssetId asset, AuthToken authToken,
          {DateTime? noOlderThan,
          int? limit,
          TransactionKind? kind,
          String? pagingId,
          String? lang}) =>
      onGetForAsset();
}

/// An [Anchor] that returns a pre-built fake [Sep24], avoiding network access.
class _FakeAnchor extends Anchor {
  Sep24? fakeSep24;
  _FakeAnchor(Config cfg) : super(cfg, 'place.domain.com');

  @override
  Sep24 sep24() => fakeSep24!;
}
