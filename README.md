# [Stellar Wallet SDK for Flutter](https://github.com/Soneso/stellar_wallet_flutter_sdk)

![Dart](https://img.shields.io/badge/Dart-green.svg)
![Flutter](https://img.shields.io/badge/Flutter-blue.svg)


The Stellar Wallet SDK for Flutter is a library that allows developers to build wallet applications on the Stellar Network faster. It
utilizes [Flutter Stellar SDK](https://github.com/Soneso/stellar_flutter_sdk) to communicate with Stellar Horizon and Anchors.

## Installation

### From pub.dev
1. Add the dependency to your pubspec.yaml file:
```
dependencies:
  stellar_wallet_flutter_sdk: ^0.3.5
  stellar_flutter_sdk: ^1.8.7
```
2. Install it (command line or IDE):
```
flutter pub get
```
3. In your source file import the SDK, initialize and use it:
```dart
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

Wallet wallet = Wallet.testNet;
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

Wallet wallet = Wallet.testNet;
Anchor anchor = wallet.anchor(anchorDomain);
AnchorServiceInfo serviceInfo = await anchor.sep24().getServiceInfo();
```
## Functionality

The Wallet SDK provides an easy way to communicate with Anchors. It supports:

- [SEP-001](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md)
- [SEP-006](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0006.md)
- [SEP-009](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0009.md)
- [SEP-010](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md)
- [SEP-012](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md)
- [SEP-024](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md)
- [SEP-030](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md)
- [SEP-038](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md)


Furthermore the wallet SDK provides extra functionality on top of the Flutter Stellar SDK. For interaction with the Stellar Network, the Flutter Wallet SDK covers the basics used in a typical wallet flow.

## Getting started

### Working with the SDK

Let's start with the main class that provides all SDK functionality. It's advised to have a singleton wallet object shared across the application. Creating a wallet with a default configuration connected to Stellar's Testnet is simple:

```dart
var wallet = Wallet.testNet;
```

The wallet instance can be further configured. For example, to connect to the public network:

```dart
var wallet = Wallet(StellarConfiguration.publicNet);
```

### Configuring a custom HTTP client

The Flutter Wallet SDK uses the standard Client from the [http package](https://pub.dev/packages/http) for all network requests (excluding Horizon, where the Flutter Stellar SDK's HTTP client is used). 

Optionally, you can set your own client from [http package](https://pub.dev/packages/http) to be used across the app.

The client can be globally configured:

```dart
import 'package:http/http.dart';
// ...

// init and configure your HTTP client
// var myClient = ...

// set as default HTTP client
var appConfig = ApplicationConfiguration(defaultClient: myClient);
var walletCustomClient = Wallet(StellarConfiguration.testNet, applicationConfiguration: appConfig);
```

Some [test cases](https://github.com/Soneso/stellar_wallet_flutter_sdk/tree/main/test) of this SDK use for example `MockClient`.

### Stellar Basics

The Flutter Wallet SDK provides extra functionality on top of the existing [Flutter Stellar SDK](https://github.com/Soneso/stellar_flutter_sdk). For interaction with the Stellar Network, the Flutter Wallet SDK covers the basics used in a typical wallet flow. For more advanced use cases, the underlying [Flutter Stellar SDK](https://github.com/Soneso/stellar_flutter_sdk) should be used instead.

To interact with the Horizon instance configured in the previous steps, simply do:

```dart
var stellar = wallet.stellar();
```
This example will create a Stellar class that manages the connection to the Horizon service.

You can read more about working with the Stellar Network in the [respective doc section](https://github.com/Soneso/stellar_wallet_flutter_sdk/blob/main/doc/stellar.md).

### Stellar Flutter SDK

The [Flutter Stellar SDK](https://github.com/Soneso/stellar_flutter_sdk) is included as a dependency in
the Flutter Wallet SDK. 

It's very simple to use the Flutter Stellar SDK connecting to the same Horizon instance as a Wallet class. To do so, simply call:

```dart
var stellar = wallet.stellar();
var server = stellar.server;
var transactions = await server.transactions.forAccount(accountId).execute();
```

But you can also import and use it for example like this:

```dart
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;

final sdk = flutter_sdk.StellarSDK.TESTNET;

var accountId = "GASYKQXV47TPTB6HKXWZNB6IRVPMTQ6M6B27IM5L2LYMNYBX2O53YJAL";
var transactions = await sdk.transactions.forAccount(accountId).execute();
```

### Anchor Basics

Primary use of the Flutter Wallet SDK is to provide an easy way to connect to anchors via sets of protocols known as SEPs. 

Let's look into connecting to the Stellar test anchor:

```dart
var anchor = wallet.anchor("https://testanchor.stellar.org");
```

And the most basic interaction of fetching a [SEP-001](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md): Stellar Info File:

```dart
var info = await anchor.getInfo();
```

The anchor class also supports [SEP-010](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md): Stellar Authentication, [SEP-024](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md): Hosted Deposit and Withdrawal features, [SEP-012](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md): KYC API and [SEP-009](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0009.md): Standard KYC Fields.

You can read more about working with Anchors in the [respective doc section](https://github.com/Soneso/stellar_wallet_flutter_sdk/blob/main/doc/anchor.md).


## Recovery

[SEP-030](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md) defines the standard way for an individual (e.g., a user or wallet) to regain access to their Stellar account after losing its private key without providing any third party control of the account. During this flow the wallet communicates with one or more recovery signer servers to register the wallet for a later recovery if it's needed.

You can read more about working with Recovery Servers in the [respective doc section](https://github.com/Soneso/stellar_wallet_flutter_sdk/blob/main/doc/recovery.md).

## Quotes

[SEP-038](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md) defines a way for anchors to provide quotes for the exchange of an off-chain asset and a different on-chain asset, and vice versa.

You can read more about requesting quotes in the [respective doc section](https://github.com/Soneso/stellar_wallet_flutter_sdk/blob/main/doc/quotes.md).

## Programmatic Deposit and Withdrawal

The [SEP-06](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0006.md) standard defines a way for anchors and wallets to interact on behalf of users.
Wallets use this standard to facilitate exchanges between on-chain assets (such as stablecoins) and off-chain assets (such as fiat, or other network assets such as BTC).

You can read more about programmatic deposit and withdrawal in the [respective doc section](https://github.com/Soneso/stellar_wallet_flutter_sdk/blob/main/doc/transfer.md).


## Docs and Examples

Documentation can be found in the [doc](https://github.com/Soneso/stellar_wallet_flutter_sdk/tree/main/doc) folder and on the official Stellar [Build a Wallet with the Wallet SDK](https://developers.stellar.org/docs/category/build-a-wallet-with-the-wallet-sdk) page.

Examples can be found in the [test cases](https://github.com/Soneso/stellar_wallet_flutter_sdk/tree/main/test) and in the included [example app](https://github.com/Soneso/stellar_wallet_flutter_sdk/tree/main/example).

## Sample app

[Flutter Basic Pay](https://github.com/Soneso/flutter_basic_pay) is an open source demo app showing how this SDK can be used to implement a Stellar Payment App.

The app has a detailed tutorial and currently offers the following features:

- Signup
- Log in
- Encrypting of secret key and secure storage of data
- Create account
- Fund account on testnet
- Fetch account data from the Stellar Network
- Add and remove asset support
- Send payments
- Fetch recent payments
- Find strict send and strict receive payment paths
- Send path payments
- Add and use contacts
- Add and use your KYC data
- SEP-06 deposits and withdrawals
- SEP-24 deposits and withdrawals
- SEP-06 & SEP-24 transfer history


