import 'dart:convert';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

// Setup main account that will fund new (user) accounts. You can get new key pair and fill it with
// testnet tokens at
// https://laboratory.stellar.org/#account-creator?network=test

const myKey =
    "SCECAI5I6VHSKNI6K2SEO3CZVFI5Y7TFI7UIXB6XZATMCKZ4I2DLULIJ"; // GA7ILFMAZXGHRFBIE4RWXRY3NWOMZOV6RIYVEJUAY2QKHVMQ4RA32C2G
var myAccount = SigningKeyPair.fromSecret(myKey);
var USDC = IssuedAssetId(
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
  print("SEP 24 server: ${info.transferServerSep24}");

  // Get SEP-24 info
  final servicesInfo = await sep24.getServiceInfo();
  for( String key in servicesInfo.deposit.keys) {
    print("Deposit asset: $key , "
        "enabled: ${servicesInfo.deposit[key]!.enabled.toString()}, "
        "max amount ${servicesInfo.deposit[key]!.maxAmount.toString()}");
  }

  print("Preparing new user account");
  // Prepare a new user account for this example.
  final userKeyPair = await prepareNewAccount();

  // Authorizing
  print("Authorize user");
  final sep10 = await anchor.sep10();
  final authToken = await sep10.authenticate(userKeyPair);

  print("Start deposit");
  await deposit(sep24, authToken, userKeyPair);
}

Future<void> deposit(
    Sep24 sep24, AuthToken authToken, SigningKeyPair userKeyPair) async {
  // Start interactive deposit
  var deposit = await sep24.deposit(USDC, authToken,
      extraFields: {"email_address": "mail@example.com"});

  // Request user input
  print("Additional user info is required for the deposit, please visit:"
      " ${deposit.url}");

  print("Waiting for tokens...");

  var depositWatcher = sep24.watcher().watchAsset(authToken, USDC);
  depositWatcher.controller.stream.listen(
    (event) async {
      if (event is StatusChange) {
        print("Transaction status changed from ${event.oldStatus ?? "none"} "
                "to ${event.status}. Message: ${event.transaction.message}");

        if (TransactionStatus.completed == event.status) {
          print("Successful deposit");
          await withdraw(sep24, authToken, userKeyPair);
        }
      } else if (event is ExceptionHandlerExit) {
        print("Retries exhausted trying obtain transaction data, giving up.");
      } else if (event is StreamControllerClosed) {
        print("Transaction tracking finished");
      }
    },
    onError: (error) {
      print('Error: $error');
    },
  );
}

Future<void> withdraw(
    Sep24 sep24, AuthToken authToken, SigningKeyPair userKeyPair) async {
  print("Start withdrawal");
  var withdrawal = await sep24.withdraw(USDC, authToken);

  // Request user input
  print(
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
      print('Error: $error');
    },
  );
}

Future<void> transferWithdrawalTransaction(Sep24 sep24, AuthToken authToken,
    WithdrawalTransaction tx, SigningKeyPair userKeyPair) async {
  var sourceAccount = await sdk.accounts.account(userKeyPair.address);

  print(
      " make the payment of ${tx.amountIn} to ${tx.withdrawAnchorAccount!} with memo type ${tx.withdrawalMemoType} and memo: ${tx.withdrawalMemo}");
  // make the payment
  final paymentBuilder = flutter_sdk.PaymentOperationBuilder(
    tx.withdrawAnchorAccount!,
    flutter_sdk.Asset.createNonNativeAsset(USDC.code, USDC.issuer),
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
  print("payment success: " + paymentResult.success.toString());

  print("Start watching");

  Watcher watcher = sep24.watcher();
  WatcherResult result = watcher.watchOneTransaction(authToken, tx.id);

  result.controller.stream.listen(
    (event) async {
      if (event is StatusChange) {
        print(
            "Transaction status changed from ${event.oldStatus ?? "none"} to ${event.status}. Message: ${event.transaction.message}");
        if (event.status.isTerminal()) {
          if (TransactionStatus.completed != event.status) {
            print("Transaction was not completed!");
          } else {
            print("Successful withdrawal");
          }
        }
      } else if (event is StreamControllerClosed) {
        print("Transaction tracking finished");
      }
    },
    onError: (error) {
      print('Error: $error');
    },
  );
}

Future<SigningKeyPair> prepareNewAccount() async {
  // Generate new (user) account and fund it with 10 XLM from main account

  var newUserKeyPair = flutter_sdk.KeyPair.random();
  print("New user account id: " + newUserKeyPair.accountId);
  print("New user seed: " + newUserKeyPair.secretSeed);

  final createAccountBuilder =
      flutter_sdk.CreateAccountOperationBuilder(newUserKeyPair.accountId, "10");

  var sourceAccount = await sdk.accounts.account(myAccount.address);

  var transactionBuilder = flutter_sdk.TransactionBuilder(sourceAccount)
    ..addOperation(createAccountBuilder.build());

  var tx = transactionBuilder.build()
    ..sign(flutter_sdk.KeyPair.fromSecretSeed(myKey), network);

  await sdk.submitTransaction(tx);

  // Create a trustline for an asset. This allows user account to receive trusted
  // the asset.

  final trustlineBuilder = flutter_sdk.ChangeTrustOperationBuilder(
    flutter_sdk.Asset.createNonNativeAsset(USDC.code, USDC.issuer),
    "200",
  );

  sourceAccount = await sdk.accounts.account(newUserKeyPair.accountId);

  transactionBuilder = flutter_sdk.TransactionBuilder(sourceAccount)
    ..addOperation(trustlineBuilder.build());

  tx = transactionBuilder.build()..sign(newUserKeyPair, network);

  await sdk.submitTransaction(tx);

  return SigningKeyPair(newUserKeyPair);
}
