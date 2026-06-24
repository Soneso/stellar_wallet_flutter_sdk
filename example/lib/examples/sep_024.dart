import 'dart:convert';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

import '../activity_log.dart';

// New (user) accounts are created and funded on the testnet via Friendbot,
// so the example does not depend on a pre-funded account that could be wiped
// by a testnet reset.

var usdc = IssuedAssetId(
    code: "USDC",
    issuer: "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5");
const domain = "testanchor.stellar.org";

final sdk = flutter_sdk.StellarSDK.TESTNET;
final network = flutter_sdk.Network.TESTNET;

Future<void> runExample() async {
  final wallet = Wallet.testNet;
  final anchor = wallet.anchor(domain);
  final sep24 = anchor.sep24();

  // Get info from the anchor server
  final info = await anchor.getInfo();
  logLine("SEP 24 server: ${info.transferServerSep24}");

  // Get SEP-24 info
  final servicesInfo = await sep24.getServiceInfo();
  for( String key in servicesInfo.deposit.keys) {
    logLine("Deposit asset: $key , "
        "enabled: ${servicesInfo.deposit[key]!.enabled.toString()}, "
        "max amount ${servicesInfo.deposit[key]!.maxAmount.toString()}");
  }

  logLine("Preparing new user account");
  // Prepare a new user account for this example.
  final userKeyPair = await prepareNewAccount();

  // Authorizing
  logLine("Authorize user");
  final sep10 = await anchor.sep10();
  final authToken = await sep10.authenticate(userKeyPair);

  logLine("Start deposit");
  await deposit(sep24, authToken, userKeyPair);
}

Future<void> deposit(
    Sep24 sep24, AuthToken authToken, SigningKeyPair userKeyPair) async {
  // Start interactive deposit
  var deposit = await sep24.deposit(usdc, authToken,
      extraFields: {"email_address": "mail@example.com"});

  // Request user input
  logLine("Additional user info is required for the deposit, please visit:"
      " ${deposit.url}");

  logLine("Waiting for tokens...");

  var depositWatcher = sep24.watcher().watchAsset(authToken, usdc);
  depositWatcher.controller.stream.listen(
    (event) async {
      if (event is StatusChange) {
        logLine("Transaction status changed from ${event.oldStatus ?? "none"} "
                "to ${event.status}. Message: ${event.transaction.message}");

        if (TransactionStatus.completed == event.status) {
          logLine("Successful deposit");
          await withdraw(sep24, authToken, userKeyPair);
        }
      } else if (event is WatchCompleted) {
        logLine("Transaction reached a terminal status, watch completed");
      } else if (event is ExceptionHandlerExit) {
        logLine("Retries exhausted trying obtain transaction data, giving up.");
      } else if (event is StreamControllerClosed) {
        logLine("Transaction tracking finished");
      }
    },
    onError: (error) {
      logLine('Error: $error');
    },
  );
}

Future<void> withdraw(
    Sep24 sep24, AuthToken authToken, SigningKeyPair userKeyPair) async {
  logLine("Start withdrawal");
  var withdrawal = await sep24.withdraw(usdc, authToken);

  // Request user input
  logLine(
      "Additional user info is required for the withdrawal, please visit: ${withdrawal.url}");

  Watcher watcher = sep24.watcher();
  WatcherResult result = watcher.watchOneTransaction(authToken, withdrawal.id);

  // Wait for user input
  result.controller.stream.listen(
    (event) async {
      if (event is StatusChange) {
        if (TransactionStatus.pendingUserTransferStart == event.status) {
          var tx = event.transaction;
          if (tx is WithdrawalTransaction) {
            await transferWithdrawalTransaction(
                sep24, authToken, tx, userKeyPair);
          }
        }
      }
    },
    onError: (error) {
      logLine('Error: $error');
    },
  );
}

Future<void> transferWithdrawalTransaction(Sep24 sep24, AuthToken authToken,
    WithdrawalTransaction tx, SigningKeyPair userKeyPair) async {
  var sourceAccount = await sdk.accounts.account(userKeyPair.address);

  logLine(
      " make the payment of ${tx.amountIn} to ${tx.withdrawAnchorAccount!} with memo type ${tx.withdrawalMemoType} and memo: ${tx.withdrawalMemo}");
  // make the payment
  final paymentBuilder = flutter_sdk.PaymentOperationBuilder(
    tx.withdrawAnchorAccount!,
    flutter_sdk.Asset.createNonNativeAsset(usdc.code, usdc.issuer),
    tx.amountIn!,
  );

  final transactionBuilder = flutter_sdk.TransactionBuilder(sourceAccount)
    ..addOperation(paymentBuilder.build());

  flutter_sdk.Memo? memo;
  if ("text" == tx.withdrawalMemoType) {
    memo = flutter_sdk.MemoText(tx.withdrawalMemo!);
  } else if ("hash" == tx.withdrawalMemoType) {
    memo = flutter_sdk.MemoHash(base64Decode(tx.withdrawalMemo!));
  } // ... etc.

  if (memo != null) {
    transactionBuilder.addMemo(memo);
  }

  flutter_sdk.KeyPair kp =
      flutter_sdk.KeyPair.fromSecretSeed(userKeyPair.secretKey);
  final transaction = transactionBuilder.build()..sign(kp, network);
  final paymentResult = await sdk.submitTransaction(transaction);
  logLine("payment success: ${paymentResult.success}");

  logLine("Start watching");

  Watcher watcher = sep24.watcher();
  WatcherResult result = watcher.watchOneTransaction(authToken, tx.id);

  result.controller.stream.listen(
    (event) async {
      if (event is StatusChange) {
        logLine(
            "Transaction status changed from ${event.oldStatus ?? "none"} to ${event.status}. Message: ${event.transaction.message}");
        if (event.status.isTerminal()) {
          if (TransactionStatus.completed != event.status) {
            logLine("Transaction was not completed!");
          } else {
            logLine("Successful withdrawal");
          }
        }
      } else if (event is WatchCompleted) {
        logLine("Transaction reached a terminal status, watch completed");
      } else if (event is StreamControllerClosed) {
        logLine("Transaction tracking finished");
      }
    },
    onError: (error) {
      logLine('Error: $error');
    },
  );
}

Future<SigningKeyPair> prepareNewAccount() async {
  final wallet = Wallet.testNet;
  final stellar = wallet.stellar();

  // Generate a new (user) account and fund it on the testnet via Friendbot.
  final userKeyPair = stellar.account().createKeyPair();
  logLine("New user account id: ${userKeyPair.address}");
  logLine("New user seed: ${userKeyPair.secretKey}");

  final funded = await stellar.fundTestNetAccount(userKeyPair.address);
  if (!funded) {
    throw Exception("Could not fund new account ${userKeyPair.address}");
  }
  logLine("New account funded via Friendbot");

  // Create a trustline so the user account can receive the asset.
  final txBuilder = await stellar.transaction(userKeyPair);
  final tx = txBuilder.addAssetSupport(usdc, limit: "200").build();
  stellar.sign(tx, userKeyPair);
  await stellar.submitTransaction(tx);
  logLine("Trustline for ${usdc.code} established");

  return userKeyPair;
}
