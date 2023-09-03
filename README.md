# [Stellar Wallet SDK for Flutter](https://github.com/Soneso/stellar_wallet_flutter_sdk)

![Dart](https://img.shields.io/badge/Dart-green.svg)
![Flutter](https://img.shields.io/badge/Flutter-blue.svg)


The Stellar Wallet SDK for Flutter is a library that allows developers to build wallet applications on the Stellar network faster. It
utilizes [Flutter Stellar SDK](https://github.com/Soneso/stellar_flutter_sdk) to communicate with Stellar Horizon and Anchors.

## Installation

### From pub.dev
1. Add the dependency to your pubspec.yaml file:
```
dependencies:
  stellar_wallet_flutter_sdk: ^0.0.1
```
2. Install it (command line or IDE):
```
flutter pub get
```
3. In your source file import the SDK, initialize and use it:
```dart
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

Wallet wallet = Wallet(StellarConfiguration.testNet);
Anchor anchor = wallet.anchor(anchorDomain);
AnchorServiceInfo serviceInfo = await anchor.sep24().getServiceInfo();
```

### Manual

Here is a step by step that we recommend:

1. Clone this repo.
2. Open the project in your IDE (e.g. Android Studio).
3. Open the file `pubspec.yaml` and press `Pub get` in your IDE.
4. Go to the project's `test` directory, run a test from there and you are good to go!

Add it to your app:

5. In your Flutter app add the local dependency in `pubspec.yaml` and then run `pub get`:
```code
dependencies:
   flutter:
     sdk: flutter
   stellar_wallet_flutter_sdk:
     path: ../stellar_wallet_flutter_sdk
```
6. In your source file import the SDK, initialize and use it:
```dart
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

Wallet wallet = Wallet(StellarConfiguration.testNet);
Anchor anchor = wallet.anchor(anchorDomain);
AnchorServiceInfo serviceInfo = await anchor.sep24().getServiceInfo();
```

## Core Flutter SDK

The Core [Flutter Stellar SDK](https://github.com/Soneso/stellar_flutter_sdk) is included as a dependency in
this Wallet SDK. You can import and use it for example like this:

```dart
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;

final sdk = flutter_sdk.StellarSDK.TESTNET;

var accountId = "GASYKQXV47TPTB6HKXWZNB6IRVPMTQ6M6B27IM5L2LYMNYBX2O53YJAL";
var account = await sdk.accounts.account(accountId);
print("sequence number: ${account.sequenceNumber}");
```

## Functionality

The Wallet SDK provides an easy way to communicate with Anchors. It supports:

- [SEP-001](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md)
- [SEP-009](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0009.md)
- [SEP-010](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md)
- [SEP-012](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md)
- [SEP-024](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md)

Simplified APIs to build and sign transactions, connect and query [Horizon](https://github.com/stellar/go/tree/master/services/horizon) will be added soon.
In the meantime please use the functionallity from the core [Stellar Flutter SDK](https://github.com/Soneso/stellar_flutter_sdk) to do so.

## Getting started

First, root `Wallet` object should be created. This is a core class, that provides all functionality available in the current SDK. Later, it will be shown, how to use `Wallet` object to access methods.

Creating `Wallet` with default configuration connected to testnet is simple:

```dart
Wallet wallet = Wallet(StellarConfiguration.testNet);
```

## Anchor

Build on and off ramps with anchors for deposits and withdrawals:

```dart
Anchor anchor = wallet.anchor("testanchor.stellar.org");
```

Get anchor information from a TOML file  using [SEP-001](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md):

```dart
TomlInfo tomlInfo = await anchor.sep1();
```

Upload KYC information to anchors using [SEP-012](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md):

```dart
Sep12 sep12 = await anchor.sep12();
AddCustomerResponse addResponse = await sep12.add({"account_id" : accountId});
```

Authenticate an account with the anchor using [SEP-010](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md):

```dart
Sep10 sep10 = await anchor.sep10();
AuthToken authToken = await sep10.authenticate(accountKeyPair);
```

Available anchor services and information about them. For example, interactive deposit/withdrawal limits, currency, fees, payment methods
using [SEP-024](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md):

```dart
AnchorServiceInfo serviceInfo = await anchor.sep24().getServiceInfo();
```

Interactive deposit and withdrawal using [SEP-024](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md):

```dart
String interactiveUrl = (await anchor.sep24().deposit(asset, authToken)).url;
```

```dart
String interactiveUrl = (await anchor.sep24().withdraw(asset, authToken)).url;
```

Deposit with extra [SEP-009](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0009.md) fields and/or files:

```dart
Map<String, String> sep9Fields = {"email_address": "mail@example.com"};

Uint8List photoIdFront = await Util.readFile(path);
Map<String, Uint8List> sep9Files = {"photo_id_front": photoIdFront};

InteractiveFlowResponse response = await anchor.sep24().deposit(
    asset, authToken, extraFields: sep9Fields, extraFiles: sep9Files);

String interactiveUrl = response.url;
```

Deposit with alternative account:
```dart
String recepientAccountId = "G...";
InteractiveFlowResponse response = await anchor.sep24().deposit(asset, 
    authToken, destinationAccount: recepientAccountId);
```

Get single transaction's current status and details:
```dart
AnchorTransaction transaction = await anchor.sep24().getTransaction("12345", authToken);
```

Get account transactions for specified asset:
```dart
List<AnchorTransaction> transactions = await anchor.sep24().getHistory(asset, authToken);
```

Watch transaction:

```dart
Watcher watcher = anchor.sep24.watcher();
WatcherResult result = watcher.watchOneTransaction(token, "transaction id");

result.controller.stream.listen(
  (event) {
    if (event is StatusChange) {
      print("Status changed to ${event.status}. Transaction: ${event.transaction.id}");
    } else if (event is ExceptionHandlerExit) {
      print("Exception handler exited the job");
    } else if (event is StreamControllerClosed) {
      print("Stream controller closed. Job is done");
    }
  }
);
```

Watch asset:

```dart
Watcher watcher = anchor.sep24.watcher();
WatcherResult result = watcher.watchAsset(token, asset);

result.controller.stream.listen(
  (event) {
    if (event is StatusChange) {
      print("Status changed to ${event.status}. Transaction: ${event.transaction.id}");
    } else if (event is ExceptionHandlerExit) {
      print("Exception handler exited the job");
    } else if (event is StreamControllerClosed) {
      print("Stream controller closed. Job is done");
    }
  }
);
```

### Add client domain signing

Supporting `client_domain` comes in two parts, the wallet's client and the wallet's server implementations. 
In this setup, we will have an extra authentication key. This key will be stored remotely on the server. 
Using the [SEP-010](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md) info file, 
the anchor will be able to query this key and verify the signature. As such, the anchor would be able to confirm
that the request is coming from your wallet, belonging to wallet's `client_domain`.

#### Client Side

First, let's implement the client side. In this example we will connect to a remote signer that 
signs transactions on the endpoint `https://demo-wallet-server.stellar.org/sign` for the client `domain demo-wallet-server.stellar.org`.

```dart
DomainSigner signer = DomainSigner("https://demo-wallet-server.stellar.org/sign");
Sep10 sep10 = await anchor.sep10();

AuthToken authToken = await sep10.authenticate(userKeyPair,
    clientDomainSigner: signer, clientDomain: "demo-wallet-server.stellar.org");
```

Danger: The demo-wallet signing endpoint is not protected for anybody to use. Your production URL must be protected, otherwise anybody could impersonate your wallet's user.

Let's add authentication with a bearer token. Simply pass the needed request headers with your token:

```dart
Map<String, String> requestHeaders = {
  "Authorization": "Bearer $token",
  "Content-Type": "application/json"
};

DomainSigner signer = DomainSigner("https://demo-wallet-server.stellar.org/sign",
    requestHeaders: requestHeaders);
```
#### Server Side

Next, let's implement the server side.

First, generate a new authentication key that will be used as a `client_domain` authentication key.

Next, create a [SEP-001](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md)
`toml` file placed under `<your domain>/.well-known/stellar.toml` with the following content:

````toml
ACCOUNTS = [ "Authentication public key (address)" ]
VERSION = "0.1.0"
SIGNING_KEY = "Authentication public key (address)"
NETWORK_PASSPHRASE = "Test SDF Network ; September 2015"
````

Don't forget to change the network passphrase for Mainnet deployment.

Finally, let's add a server implementation. This sample implementation uses express framework:

```javascript
app.post("/sign", (req, res) => {
  const envelope_xdr = req.body.transaction;
  const network_passphrase = req.body.network_passphrase;
  const transaction = new Transaction(envelope_xdr, network_passphrase);

  if (Number.parseInt(transaction.sequence, 10) !== 0) {
    res.status(400);
    res.send("transaction sequence value must be '0'");
    return;
  }

  transaction.sign(Keypair.fromSecret(SERVER_SIGNING_KEY));

  res.set("Access-Control-Allow-Origin", "*");
  res.status(200);
  res.send({
    transaction: transaction.toEnvelope().toXDR("base64"),
    network_passphrase: network_passphrase,
  });
});
```

The `DomainSigner` will request remote signing at the given endpoint by posting a request that contains a json with 
the `transaction` and `network_passphrase`. On the server side you can now sign the transaction with the client
keypair and send it back as a result. As mentioned before, this sample implementation doesn't have any protection
against unauthorized requests, so you must add authorization checks as part of the request.
