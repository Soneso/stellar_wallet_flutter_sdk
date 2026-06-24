// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:stellar_wallet_flutter_sdk/src/anchor/anchor.dart';
import 'package:stellar_wallet_flutter_sdk/src/asset/asset_id.dart';
import 'package:stellar_wallet_flutter_sdk/src/auth/sep_10.dart';
import 'package:logger/logger.dart';

enum WatcherKind { sep6, sep24 }

class Watcher {
  Anchor anchor;
  Duration pollDelay;
  WalletExceptionHandler exceptionHandler;
  WatcherKind watcherKind;
  var logger = Logger();

  Watcher(this.anchor, this.pollDelay, this.exceptionHandler, this.watcherKind);

  WatcherResult watchOneTransaction(AuthToken authToken, String id,
      {String? lang}) {
    StreamController<StatusUpdateEvent> controller =
        StreamController<StatusUpdateEvent>.broadcast();

    TransactionStatus? oldStatus;
    RetryContext retryContext = RetryContext();
    bool shouldExit = false;

    final periodicTimer = Timer.periodic(
      pollDelay,
      (timer) async {
        bool exitDueToError = false;
        try {
          AnchorTransaction transaction = watcherKind == WatcherKind.sep6
              ? await anchor
                  .sep6()
                  .getTransactionBy(authToken: authToken, id: id, lang: lang)
              : await anchor
                  .sep24()
                  .getTransactionBy(authToken, id: id, lang: lang);
          if (controller.isClosed) {
            timer.cancel();
            return;
          }
          StatusChange statusChange = StatusChange(
              transaction, transaction.status,
              oldStatus: oldStatus);

          if (statusChange.status != statusChange.oldStatus) {
            controller.sink.add(statusChange);
          }
          oldStatus = statusChange.status;
          shouldExit = statusChange.isTerminal();
          retryContext.refresh();
        } on Exception catch (e) {
          try {
            retryContext.onError(e);
            shouldExit = await exceptionHandler.invoke(retryContext);
            exitDueToError = shouldExit;
          } catch (e1) {
            shouldExit = true;
            exitDueToError = true;
            logger.d("CRITICAL: Couldn't invoke exception handler");
          }
        } catch (e) {
          shouldExit = true;
          exitDueToError = true;
          logger.d("CRITICAL: Unknown error occurred: $e");
        }
        if (shouldExit) {
          timer.cancel();
          controller.sink.add(
              exitDueToError ? ExceptionHandlerExit() : WatchCompleted());
          controller.sink.add(StreamControllerClosed());
          controller.close();
        }
      },
    );

    return WatcherResult(controller, periodicTimer);
  }

  WatcherResult watchAsset(AuthToken authToken, StellarAssetId asset,
      {DateTime? since, String? lang, TransactionKind? kind}) {
    StreamController<StatusUpdateEvent> controller =
        StreamController<StatusUpdateEvent>.broadcast();
    Map<String, AnchorTransaction> transactionStatuses = {};
    RetryContext retryContext = RetryContext();
    bool shouldExit = false;

    final periodicTimer = Timer.periodic(
      pollDelay,
      (timer) async {
        bool exitDueToError = false;
        try {
          List<AnchorTransaction> txList = watcherKind == WatcherKind.sep6
              ? await anchor.sep6().getTransactionsForAsset(
                  authToken: authToken,
                  assetCode: asset is IssuedAssetId ? asset.code : asset.id,
                  noOlderThan: since,
                  kind: kind,
                  lang: lang)
              : await anchor.sep24().getTransactionsForAsset(asset, authToken,
                  noOlderThan: since, kind: kind, lang: lang);

          if (controller.isClosed) {
            timer.cancel();
            return;
          }

          Map<String, AnchorTransaction> transactions = {
            for (var e in txList) e.id: e
          };
          bool hasUnfinishedTransactions = false;
          transactions.forEach((key, value) {
            AnchorTransaction tx = value;
            TransactionStatus? previousStatus;

            if (transactionStatuses.containsKey(key)) {
              previousStatus = transactionStatuses[key]?.status;
            }
            if (tx.status != previousStatus) {
              StatusChange statusChange =
                  StatusChange(tx, tx.status, oldStatus: previousStatus);
              controller.sink.add(statusChange);
            }
            if (!tx.status.isTerminal()) {
              hasUnfinishedTransactions = true;
            }
          });
          transactionStatuses = transactions;

          // Complete only once at least one transaction has been seen and all
          // seen transactions are terminal. An empty poll (e.g. before the
          // transaction has been created) must not end the watch.
          if (transactions.isNotEmpty && !hasUnfinishedTransactions) {
            shouldExit = true;
          }

          retryContext.refresh();
        } on Exception catch (e) {
          try {
            retryContext.onError(e);
            shouldExit = await exceptionHandler.invoke(retryContext);
            exitDueToError = shouldExit;
          } catch (err) {
            shouldExit = true;
            exitDueToError = true;
            logger.d("CRITICAL: Couldn't invoke exception handler");
          }
        } catch (e, stackTrace) {
          shouldExit = true;
          exitDueToError = true;
          logger.d(
              "CRITICAL: Unknown error occurred: $e stack trace: $stackTrace");
        }
        if (shouldExit) {
          timer.cancel();
          controller.sink.add(
              exitDueToError ? ExceptionHandlerExit() : WatchCompleted());
          controller.sink.add(StreamControllerClosed());
          controller.close();
        }
      },
    );

    return WatcherResult(controller, periodicTimer);
  }
}

class RetryContext {
  int retries;
  Exception? exception;

  RetryContext({this.retries = 0});

  void refresh() {
    retries = 0;
    exception = null;
  }

  void onError(Exception e) {
    exception = e;
    retries++;
  }
}

abstract class WalletExceptionHandler {
  Future<bool> invoke(RetryContext ctx);
}

/// Simple exception handler that retries on the error.
class RetryExceptionHandler extends WalletExceptionHandler {
  int maxRetryCount = 3;
  Duration backoffPeriod = const Duration(seconds: 5);

  @override
  Future<bool> invoke(RetryContext ctx) async {
    Logger().d(
        "Exception on getting transaction data. Try ${ctx.retries}/$maxRetryCount");
    if (ctx.retries < maxRetryCount) {
      await Future.delayed(backoffPeriod);
      return false;
    }
    return true;
  }
}

abstract class StatusUpdateEvent {}

class StatusChange extends StatusUpdateEvent {
  AnchorTransaction transaction;
  TransactionStatus status;
  TransactionStatus? oldStatus;

  StatusChange(this.transaction, this.status, {this.oldStatus});

  bool isTerminal() {
    return status.isTerminal();
  }

  bool isError() {
    return status.isError();
  }
}

class StreamControllerClosed extends StatusUpdateEvent {}

/// Emitted when the watcher stops because the exception handler gave up after
/// repeated errors.
class ExceptionHandlerExit extends StatusUpdateEvent {}

/// Emitted when the watcher stops because the watched transaction(s) reached a
/// terminal status (normal, successful completion of the watch).
class WatchCompleted extends StatusUpdateEvent {}

class WatcherResult {
  StreamController<StatusUpdateEvent> controller;
  Timer periodicTimer;
  WatcherResult(this.controller, this.periodicTimer);

  void close() {
    if (!controller.isClosed) {
      controller.close();
    }
    if (periodicTimer.isActive) {
      periodicTimer.cancel();
    }
  }
}
